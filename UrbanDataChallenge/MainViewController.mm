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
#import "RouteParser.h"
#import "TransitDataSet.h"
#import "RouteSelector.h"
#import "DataFieldSelector.h"

@interface MainViewController () <WhirlyGlobeViewControllerDelegate>

@end

@implementation MainViewController
{
    // The globe, if we have one
    WhirlyGlobeViewController *globeViewC;
    // Base class for map or globe
    MaplyBaseViewController *baseViewC;
    // Data range selector
    IBOutlet ACVRangeSelector *rangeSelect;
    IBOutlet UILabel *startLabel,*endLabel;
    IBOutlet UISegmentedControl *segControl;
    // Currently active data set
    TransitDataSet *dataSet;
    
    // Used to select routes in the current data set
    RouteSelector *routeSelector;
    DataFieldSelector *dataFieldSelector;
    UIPopoverController *popControl;
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
    globeViewC.height = 0.001;
    [globeViewC setTiltMinHeight:0.000227609242 maxHeight:0.00334425364 minTilt:1.21771169 maxTilt:0.0];
    [globeViewC setPosition:MaplyCoordinateMakeWithDegrees(-122.4192, 37.7793)];
    
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

    // Load the transit database
    dataSet = [[TransitDataSet alloc] initWithDB:@"sf_transit_tables_1_4" routes:@"sf_routes" stops:@"sf_stops" viewC:baseViewC];
    
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

    // Turn on route display
    dataSet.displayRoutes = true;
}

- (void)updateDisplay
{
    int dayOfWeek = segControl.selectedSegmentIndex;
    NSTimeInterval timeOffset = dayOfWeek * 24 * 60* 60;
    NSTimeInterval startTime = rangeSelect.leftValue + timeOffset;
    NSTimeInterval endTime = rangeSelect.rightValue + timeOffset;

    [dataSet runQueryFrom:startTime to:endTime];
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

- (void)rangeSelectChangeDone:(id)sender
{
    [self performSelector:@selector(updateDisplay) withObject:nil afterDelay:0.0];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Actions

- (IBAction)routeAction:(id)sender
{
    UIButton *button = (UIButton *)sender;
    
    UITableViewController *tableViewC = [[UITableViewController alloc] initWithStyle:UITableViewStylePlain];
    routeSelector = [[RouteSelector alloc] initWithRoutes:dataSet->routes];
    if (dataSet.routeEnables)
        routeSelector->enables = [NSMutableArray arrayWithArray:dataSet.routeEnables];
    tableViewC.tableView.dataSource = routeSelector;
    tableViewC.tableView.delegate = routeSelector;

    popControl = [[UIPopoverController alloc] initWithContentViewController:tableViewC];
    popControl.delegate = self;
    [popControl presentPopoverFromRect:button.frame inView:self.view permittedArrowDirections:UIPopoverArrowDirectionRight animated:YES];
}

- (IBAction)fieldAction:(id)sender
{
    UIButton *button = (UIButton *)sender;
    
    UITableViewController *tableViewC = [[UITableViewController alloc] initWithStyle:UITableViewStylePlain];
    dataFieldSelector = [[DataFieldSelector alloc] initWithDataFields:dataSet->dataFields];
    dataFieldSelector->selected = dataSet.selectedField;
    tableViewC.tableView.dataSource = dataFieldSelector;
    tableViewC.tableView.delegate = dataFieldSelector;
    
    popControl = [[UIPopoverController alloc] initWithContentViewController:tableViewC];
    popControl.delegate = self;
    [popControl presentPopoverFromRect:button.frame inView:self.view permittedArrowDirections:UIPopoverArrowDirectionRight animated:YES];    
}

#pragma mark - Popover delegate

- (void)popoverControllerDidDismissPopover:(UIPopoverController *)popoverController
{
    if (routeSelector)
    {
        dataSet.routeEnables = routeSelector->enables;
    } else if (dataFieldSelector)
    {
        if (dataSet)
        {
            dataSet.selectedField = dataFieldSelector->selected;
        }
    }
    
    routeSelector = nil;
    dataFieldSelector = nil;
    popControl = nil;
    
    [self performSelector:@selector(updateDisplay) withObject:nil afterDelay:0.0];
}

@end
