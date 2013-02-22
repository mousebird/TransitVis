//
//  MainViewController.m
//  UrbanDataChallenge
//
//  Created by Steve Gifford on 2/18/13.
//  Copyright (c) 2013 mousebird consulting. All rights reserved.
//

#import <algorithm>
#import <set>
#import <vector>
#import "MainViewController.h"
#import "FMDatabase.h"
#import "StopAccumulator.h"
#import "ACVRangeSelector.h"

@interface MainViewController () <WhirlyGlobeViewControllerDelegate>

@end

@implementation MainViewController
{
    // The globe, if we have one
    WhirlyGlobeViewController *globeViewC;
    // Base class for map or globe
    MaplyBaseViewController *baseViewC;
    // San Francisco database with an FMDB wrapper
    FMDatabase *sfDb;
    // Data range selector
    IBOutlet ACVRangeSelector *rangeSelect;
    IBOutlet UILabel *startLabel,*endLabel;
    IBOutlet UISlider *tiltSlider;
    IBOutlet UISegmentedControl *segControl;
    // Currently displayed cylinders
    MaplyComponentObject *shapesObj;
    // We'll run the queries on this dispatch queue
    dispatch_queue_t queryQueue;
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

// Range selector size
static const float RangeHeight = 80.0;

- (void)viewDidLoad
{
    [super viewDidLoad];
        
    // Create a globe
    globeViewC = [[WhirlyGlobeViewController alloc] init];
    globeViewC.delegate = self;
    baseViewC = globeViewC;
    // Wire it into the view/controller hierarchy
    [self.view insertSubview:baseViewC.view atIndex:0];
    baseViewC.view.frame = self.view.bounds;
    [self addChildViewController:baseViewC];
    
    // Start up over San Francisco, center of the universe
//    globeViewC.height = 0.001;
//    [globeViewC animateToPosition:MaplyCoordinateMakeWithDegrees(-122.4192, 37.7793) time:1.0];
    
    // For network paging layers, where we'll store temp files
    NSString *cacheDir = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES)  objectAtIndex:0];

    // This points to the OpenStreetMap tile set hosted by MapQuest (I think)
    NSString *thisCacheDir = [NSString stringWithFormat:@"%@/osmtiles/",cacheDir];
    [baseViewC addQuadEarthLayerWithRemoteSource:@"http://otile1.mqcdn.com/tiles/1.0.0/osm/" imageExt:@"png" cache:thisCacheDir minZoom:0 maxZoom:18];
    
    // Fill out the cache dir
    if (thisCacheDir)
    {
        NSError *error = nil;
        [[NSFileManager defaultManager] createDirectoryAtPath:thisCacheDir withIntermediateDirectories:YES attributes:nil error:&error];
    }

    // Let's load our transit database
    NSString *sfDbPath = [[NSBundle mainBundle] pathForResource:@"sf_transit_tables_1_1" ofType:@"db"];
    if (sfDbPath)
    {
        sfDb = [[FMDatabase alloc] initWithPath:sfDbPath];
        if (![sfDb open])
        {
            sfDb = nil;
        }
    }
    
    // Configure the slider along the bottom
    [rangeSelect setLeftThumbImage:[UIImage imageNamed:@"pointer-handle"] forState:UIControlStateNormal];
    [rangeSelect setRightThumbImage:[UIImage imageNamed:@"pointer-handle"] forState:UIControlStateNormal];
    [rangeSelect setMiddleThumbImage:[UIImage imageNamed:@"handle"] forState:UIControlStateNormal];
    [rangeSelect setConnectionImage:[UIImage imageNamed:@"connector"] forState:UIControlStateNormal];
    [rangeSelect setTrackImage:[UIImage imageNamed:@"track"]];
    rangeSelect.scaleMiddleThumb = NO;
    rangeSelect.leftPointerOffset = 17;
    rangeSelect.rightPointerOffset = 17;
    rangeSelect.connectionOffset = 0;
    rangeSelect.minimumValue = 0;
    rangeSelect.maximumValue = 24*60*60;
    rangeSelect.rightValue = 9*60*60;
    rangeSelect.leftValue = 8*60*60;
    [rangeSelect addTarget:self action:@selector(rangeSelectChanged:) forControlEvents:UIControlEventAllEvents];
    [rangeSelect addTarget:self action:@selector(rangeSelectChangeDone:) forControlEvents:UIControlEventTouchUpInside];
    [self rangeSelectChanged:self];

    // Configure the tilt slider
    CGAffineTransform trans = CGAffineTransformMakeRotation(M_PI * 0.5);
    tiltSlider.transform = trans;
    [tiltSlider addTarget:self action:@selector(tiltChanged:) forControlEvents:UIControlEventAllEvents];
    tiltSlider.value = 0.0;
    
    // Configure the segment control
    [segControl removeAllSegments];
    [segControl insertSegmentWithTitle:@"Mon (Oct 1)" atIndex:0 animated:NO];
    [segControl insertSegmentWithTitle:@"Tuesday" atIndex:1 animated:NO];
    [segControl insertSegmentWithTitle:@"Wednesday" atIndex:2 animated:NO];
    [segControl insertSegmentWithTitle:@"Thursday" atIndex:3 animated:NO];
    [segControl insertSegmentWithTitle:@"Friday" atIndex:4 animated:NO];
    [segControl insertSegmentWithTitle:@"Saturday" atIndex:5 animated:NO];
    [segControl insertSegmentWithTitle:@"Sunday" atIndex:6 animated:NO];
    segControl.selectedSegmentIndex = 0;
    [segControl addTarget:self action:@selector(rangeSelectChangeDone:) forControlEvents:UIControlEventValueChanged];

    queryQueue = dispatch_queue_create("com.mousebirdconsulting.queryQueue", NULL);
    
    // Toss in some data after a bit
    [self performSelector:@selector(runData) withObject:nil afterDelay:0.0];
}

- (void)rangeSelectChanged:(id)sender
{
    int startMin = rangeSelect.leftValue / 60;
    int endMin = rangeSelect.rightValue / 60;
    int startHour = startMin / 60;
    int endHour = endMin / 60;

    startLabel.text = [NSString stringWithFormat:@"%.2d:%.2d",startHour,startMin % 60];
    endLabel.text = [NSString stringWithFormat:@"%.2d:%.2d",endHour,endMin % 60];
}

- (void)tiltChanged:(id)sender
{
    float newTilt = tiltSlider.value * M_PI/2;
    [globeViewC setTilt:newTilt];
}

- (void)rangeSelectChangeDone:(id)sender
{
    [self performSelector:@selector(runData) withObject:nil afterDelay:0.0];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

static const float MaxCylinderRadius = 0.000002;
static const float MaxCylinderHeight = 0.002;
static const float CylinderOffset = 0.000001;

// Naive data extraction
- (void)runData
{
    if (shapesObj)
        [baseViewC removeObject:shapesObj];
    shapesObj = nil;

    int dayOfWeek = segControl.selectedSegmentIndex;
    NSTimeInterval timeOffset = dayOfWeek * 24 * 60* 60;
    NSTimeInterval startTime = rangeSelect.leftValue + timeOffset;
    NSTimeInterval endTime = rangeSelect.rightValue + timeOffset;

    [rangeSelect setAlpha:0.2];
    [rangeSelect setUserInteractionEnabled:NO];
    [segControl setAlpha:0.2];
    [segControl setUserInteractionEnabled:NO];

    dispatch_async(queryQueue,
    ^{
        NSString *query = [NSString stringWithFormat:@"SELECT * FROM stopinfo where time_stop > %f AND time_stop < %f;",startTime,endTime];
        FMResultSet *results = [sfDb executeQuery:query];

        // Merge the results together by stop
        StopAccumulatorGroup stopGroup;
        stopGroup.accumulateStops(results);
        
        // Look for the maximum pass_on,off
        int max_total=0;
//        for (StopAccumulatorSet::iterator it = stopGroup.stopSet.begin();
//             it != stopGroup.stopSet.end(); ++it)
//        {
//            max_pass_on = std::max(max_pass_on,(int)(*it)->pass_on);
//            max_pass_off = std::max(max_pass_off,(int)(*it)->pass_off);
//            max_total = std::max(max_pass_on+max_pass_off,max_total);
//        }
        // Note: Scaling it each time is goofy
        max_total = 5000;
        
        // Cylinder colors
        UIColor *onColor = [UIColor colorWithRed:79/255.0 green:16/255.0 blue:173/255.0 alpha:1.0];
        UIColor *offColor = [UIColor colorWithRed:225/255.0 green:0.0 blue:76/255.0 alpha:1.0];
        
        // Work through the stop results, one by one
    //    int numStops = stopGroup.stopSet.size();
        NSMutableArray *shapes = [NSMutableArray array];
        for (StopAccumulatorSet::iterator it = stopGroup.stopSet.begin();
             it != stopGroup.stopSet.end(); ++it)
        {
            StopAccumulator *stop = *it;
    //        int total = stop->pass_on+stop->pass_off;
            float disp_on = stop->pass_on / max_total * MaxCylinderHeight;
            float disp_off = stop->pass_off / max_total * MaxCylinderHeight;
            
            // Passengers getting on at the stop (displayed at the bottom)
            if (disp_on > 0)
            {
                MaplyShapeCylinder *cyl = [[MaplyShapeCylinder alloc] init];
                // Note: Lon is flipped
                cyl.baseCenter = MaplyCoordinateMakeWithDegrees(-stop->lon, stop->lat);
                cyl.baseHeight = CylinderOffset;
                cyl.radius = MaxCylinderRadius;
                cyl.height = disp_on;
                cyl.color = onColor;
                [shapes addObject:cyl];
            }
            // Passengers getting off at the stop (displayed at the top)
            if (disp_off > 0)
            {
                MaplyShapeCylinder *cyl = [[MaplyShapeCylinder alloc] init];
                // Note: lon is flipped
                cyl.baseCenter = MaplyCoordinateMakeWithDegrees(-stop->lon, stop->lat);
                cyl.baseHeight = disp_on+CylinderOffset;
                cyl.radius = MaxCylinderRadius;
                cyl.height = disp_off;
                cyl.color = offColor;
                [shapes addObject:cyl];
            }
        }
        
        dispatch_async(dispatch_get_main_queue(),
                       ^{
                           [baseViewC setShapeDesc:@{kMaplyColor: [UIColor redColor]}];
                           shapesObj = [baseViewC addShapes:shapes];
                           [baseViewC setShapeDesc:@{kMaplyColor: [NSNull null]}];

                           [rangeSelect setAlpha:1.0];
                           [rangeSelect setUserInteractionEnabled:YES];
                           [segControl setAlpha:1.0];
                           [segControl setUserInteractionEnabled:YES];
                       });
    });
}

@end
