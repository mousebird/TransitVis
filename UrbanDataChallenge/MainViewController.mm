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
#import <QuartzCore/QuartzCore.h>
#import "MainViewController.h"
#import "FMDatabase.h"
#import "StopAccumulator.h"
#import "ACVRangeSelector.h"
#import "RouteParser.h"
#import "LoadableTransitDataSet.h"
#import "TransitDataSet.h"
#import "RouteSelector.h"
#import "DataSetSelector.h"
#import "DataFieldSelector.h"

@interface MainViewController () <WhirlyGlobeViewControllerDelegate,UITableViewDataSource,UITableViewDelegate>

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
    IBOutlet UILabel *messageLabel;
    IBOutlet UIButton *autoScaleButton;
    IBOutlet UIButton *settingsButton;
    IBOutlet UIView *controlView;
    
    // Data sets we could load
    NSArray *loadableDataSets;
    
    // Currently active data set
    LoadableTransitDataSet *loadedDataSet;
    TransitDataSet *dataSet;
    
    // Used to select routes in the current data set
    RouteSelector *routeSelector;
    DataFieldSelector *dataFieldSelector;
    DataSetSelector *dataSetSelector;
    UINavigationController *popNavC;
    UIPopoverController *popControl;
    
    // Set if we're doing autoscale on the data results
    bool autoScale;
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
    
    [self clearMessage];
            
    // Create a globe
    globeViewC = [[WhirlyGlobeViewController alloc] init];
    globeViewC.delegate = self;
    baseViewC = globeViewC;
    // Wire it into the view/controller hierarchy
    [self.view insertSubview:baseViewC.view atIndex:0];
    baseViewC.view.frame = self.view.bounds;
    [self addChildViewController:baseViewC];

    // Start up close to the globe with the auto-tilt set
    [globeViewC setClearColor:[UIColor colorWithRed:0.75 green:0.75 blue:0.75 alpha:1.0]];
    [globeViewC setPosition:MaplyCoordinateMakeWithDegrees(-122.4192, 37.7793)];
    [globeViewC setTiltMinHeight:0.000227609242 maxHeight:0.00334425364 minTilt:1.21771169 maxTilt:0.0];
    
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

    // Set up scale and scale display
    autoScale = false;
    autoScaleButton.layer.cornerRadius = 9.0;
    autoScaleButton.layer.masksToBounds = YES;
    autoScaleButton.layer.borderColor = [UIColor grayColor].CGColor;
    [self autoScaleAction:autoScaleButton];

    // Look for data sets
    loadableDataSets = [LoadableTransitDataSet FindAllDataSets];
    
    // Load the first data set we found
    if ([loadableDataSets count] > 0)
    {
        [self loadDataSet:[loadableDataSets objectAtIndex:0]];
    }
    
    messageLabel.layer.cornerRadius = 9.0;
    messageLabel.layer.masksToBounds = YES;
    messageLabel.layer.borderColor = [UIColor grayColor].CGColor;

    
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
    rangeSelect.leftValue = 6.5*60*60;
    [rangeSelect addTarget:self action:@selector(rangeSelectChanged:) forControlEvents:UIControlEventAllEvents];
    [rangeSelect addTarget:self action:@selector(rangeSelectChangeDone:) forControlEvents:UIControlEventTouchUpInside];
    [self rangeSelectChanged:self];
    
    startLabel.layer.cornerRadius = 9.0;
    startLabel.layer.masksToBounds = YES;
    startLabel.layer.borderColor = [UIColor grayColor].CGColor;

    endLabel.layer.cornerRadius = 9.0;
    endLabel.layer.masksToBounds = YES;
    endLabel.layer.borderColor = [UIColor grayColor].CGColor;
    
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
}

// Display a message
- (void)setMessage:(NSString *)msg
{
    messageLabel.text = msg;
    
    [UIView animateWithDuration:1.0 animations:
     ^{
         messageLabel.alpha = 0.75;
     }];

    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(clearMessage) object:nil];
}

// Clear any currently displayed message
- (void)clearMessage
{
    [UIView animateWithDuration:1.0 animations:
     ^{
         messageLabel.alpha = 0.0;
     }];
}

- (void)disableSettings
{
    settingsButton.enabled = FALSE;
    settingsButton.alpha = 0.25;
    controlView.userInteractionEnabled = false;
    controlView.alpha = 0.25;
}

- (void)enableSettings
{
    settingsButton.enabled = TRUE;
    settingsButton.alpha = 1.0;
    controlView.userInteractionEnabled = true;
    controlView.alpha = 1.0;
}

// Jump to the location of the current data set
- (void)jumpToDataSet
{
    if (!dataSet)
        return;
    
    globeViewC.height = 0.001;
    MaplyCoordinate start;
    start.x = (dataSet->ll.x + dataSet->ur.x)/2.0;
    start.y = dataSet->ll.y - (dataSet->ur.y-dataSet->ll.y)/4.0;
    [globeViewC setPosition:start];    
}

// Load the given data set into memory.  Clear out one if it's already there.
- (void)loadDataSet:(LoadableTransitDataSet *)toLoad
{
    [self setMessage:[NSString stringWithFormat:@"Loading %@",toLoad.name]];
    
    if (dataSet)
    {
        [dataSet shutdown];
        dataSet = nil;
    }
    
    [self disableSettings];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,0),
                   ^{
                       TransitDataSet *newDataSet = [[TransitDataSet alloc] initWithDB:toLoad.stopTable routes:toLoad.lineJson stops:toLoad.stopJson viewC:baseViewC];
                       
                       dispatch_async(dispatch_get_main_queue(),
                                      ^{
                                          loadedDataSet = toLoad;
                                          dataSet = newDataSet;
                                          if (dataSet)
                                          {
                                              [self jumpToDataSet];
                                              
                                              dataSet.displayRoutes = true;
                                          }
                                          
                                          [self clearMessage];

                                          if ([dataSet->dataFields count] > 0)
                                          {
                                              dataSet.selectedField = [dataSet->dataFields objectAtIndex:0];
                                              [self performSelector:@selector(updateDisplay) withObject:nil afterDelay:0.0];
                                          }
                                          [self enableSettings];
                                      });
                   });
}

- (void)updateDisplay
{
    int dayOfWeek = segControl.selectedSegmentIndex;
    NSTimeInterval timeOffset = dayOfWeek * 24 * 60* 60;
    NSTimeInterval startTime = rangeSelect.leftValue + timeOffset;
    NSTimeInterval endTime = rangeSelect.rightValue + timeOffset;

    if (dataSet)
    {
        [self setMessage:@"Running Query"];
        [self disableSettings];
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,0),
                       ^{
                           [dataSet runQueryFrom:startTime to:endTime];
                           dispatch_async(dispatch_get_main_queue(),
                                          ^{
                                               [self enableSettings];
                                               [self clearMessage];
                                          });
                       });
    }
}

- (void)rangeSelectChanged:(id)sender
{
    int startMin = rangeSelect.leftValue / 60;
    int endMin = rangeSelect.rightValue / 60;
    int startHour = startMin / 60;
    int endHour = endMin / 60;

    int dispStartHour = (startHour == 0 ? 12 : (startHour < 13 ? startHour : startHour-12));
    int dispEndHour = (endHour == 0 ? 12 : (endHour < 13 ? endHour : endHour-12));
    startLabel.text = [NSString stringWithFormat:@"%.2d:%.2d%@",dispStartHour,startMin % 60,(startHour < 12) ? @"AM" : @"PM"];
    endLabel.text = [NSString stringWithFormat:@"%.2d:%.2d%@",dispEndHour,endMin % 60,(endHour < 12) ? @"AM" : @"PM"];
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

// Pop up the top level settings menu
- (IBAction)settingsAction:(id)sender
{
    UIButton *button = (UIButton *)sender;

    UITableViewController *tableViewC = [[UITableViewController alloc] initWithStyle:UITableViewStylePlain];
    tableViewC.tableView.dataSource = self;
    tableViewC.tableView.delegate = self;
    popNavC = [[UINavigationController alloc] initWithRootViewController:tableViewC];
    popNavC.navigationBarHidden = YES;
    popControl = [[UIPopoverController alloc] initWithContentViewController:popNavC];
    popControl.delegate = self;
    [popControl presentPopoverFromRect:button.frame inView:self.view permittedArrowDirections:UIPopoverArrowDirectionRight animated:YES];
}

- (void)userSelectedDataSet:(LoadableTransitDataSet *)theDataSet
{
    [self performSelector:@selector(popoverControllerDidDismissPopover:) withObject:popControl afterDelay:0.0];
    [popControl dismissPopoverAnimated:YES];
}

- (IBAction)autoScaleAction:(id)sender
{
    UIButton *button = (UIButton *)sender;
    autoScale = !autoScale;
    
    bool runQuery = false;
    if (autoScale)
    {
        [button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        [button setTitleShadowColor:[UIColor grayColor] forState:UIControlStateNormal];
        [button setBackgroundColor:[UIColor colorWithRed:0 green:0 blue:0 alpha:0.5]];
        runQuery = true;
    } else {
        [button setTitleColor:[UIColor colorWithRed:1.0 green:1.0 blue:1.0 alpha:0.25] forState:UIControlStateNormal];
        [button setTitleShadowColor:[UIColor grayColor] forState:UIControlStateNormal];
        [button setBackgroundColor:[UIColor colorWithRed:0 green:0 blue:0 alpha:0.5]];
    }
    if (dataSet)
        dataSet->autoScale = autoScale;

    if (runQuery)
        [self performSelector:@selector(updateDisplay) withObject:nil afterDelay:0.0];
}

#pragma mark - Popover delegate

- (void)popoverControllerDidDismissPopover:(UIPopoverController *)popoverController
{
    if (dataSetSelector)
    {
        if (dataSetSelector->selected != loadedDataSet)
            [self loadDataSet:dataSetSelector->selected];
        else
            [self jumpToDataSet];
    } else {
        if (routeSelector)
        {
            dataSet.routeEnables = routeSelector->enables;
        } else
        {
            if (dataFieldSelector)
            {
                if (dataSet)
                {
                    dataSet.selectedField = dataFieldSelector->selected;
                }
            }
        }
    }

    if (!dataSetSelector)
        [self performSelector:@selector(updateDisplay) withObject:nil afterDelay:0.0];
   
    routeSelector = nil;
    dataFieldSelector = nil;
    dataSetSelector = nil;
    popControl = nil;
}

#pragma mark - Table View data source and delegate

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return 3;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    cell.accessoryType = UITableViewCellAccessoryDetailDisclosureButton;
    
    switch (indexPath.row)
    {
        case 0:
            cell.textLabel.text = @"Data Sets";
            break;
        case 1:
            cell.textLabel.text = @"Routes";
            break;
        case 2:
            cell.textLabel.text = @"Data fields";
            break;
    }
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    switch (indexPath.row)
    {
        case 0:
        {
            UITableViewController *tableViewC = [[UITableViewController alloc] initWithStyle:UITableViewStylePlain];
            dataSetSelector = [[DataSetSelector alloc] initWithDataSets:loadableDataSets];
            dataSetSelector->selected = loadedDataSet;
            [dataSetSelector setTarget:self selector:@selector(userSelectedDataSet:)];
            tableViewC.tableView.dataSource = dataSetSelector;
            tableViewC.tableView.delegate = dataSetSelector;
            
            [popNavC pushViewController:tableViewC animated:YES];
        }
            break;
        case 1:
        {
            UITableViewController *tableViewC = [[UITableViewController alloc] initWithStyle:UITableViewStylePlain];
            routeSelector = [[RouteSelector alloc] initWithRoutes:dataSet->routes];
            if (dataSet.routeEnables)
                routeSelector->enables = [NSMutableArray arrayWithArray:dataSet.routeEnables];
            tableViewC.tableView.dataSource = routeSelector;
            tableViewC.tableView.delegate = routeSelector;
            
            [popNavC pushViewController:tableViewC animated:YES];
        }
            break;
        case 2:
        {
            UITableViewController *tableViewC = [[UITableViewController alloc] initWithStyle:UITableViewStylePlain];
            dataFieldSelector = [[DataFieldSelector alloc] initWithDataFields:dataSet->dataFields];
            dataFieldSelector->selected = dataSet.selectedField;
            tableViewC.tableView.dataSource = dataFieldSelector;
            tableViewC.tableView.delegate = dataFieldSelector;
            
            [popNavC pushViewController:tableViewC animated:YES];
        }
            break;
    }
}

@end
