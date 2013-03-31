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

@interface MainViewController () <WhirlyGlobeViewControllerDelegate,UITableViewDataSource,UITableViewDelegate,UIWebViewDelegate>

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
    IBOutlet UIButton *leftButton,*rightButton;
    IBOutlet UILabel *displayLabel;
    
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
    
    // Colors we use for data field display
    NSArray *dataFieldColors;
    
    UIView *selectView;
    bool pickingEnabled;
    UIAlertView *alertView;
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
    globeViewC.autoMoveToTap = false;
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
    
    // Colors used in data field display
    dataFieldColors = @[[UIColor redColor],[UIColor colorWithRed:0.25 green:0.25 blue:1.0 alpha:1.0],[UIColor greenColor]];

    // Look for data sets
    loadableDataSets = [LoadableTransitDataSet FindAllDataSets];
    
    // Load the first data set we found
    if ([loadableDataSets count] > 0)
    {
        [self loadDataSet:[loadableDataSets objectAtIndex:0]];
    } else {
        // Let them know about it
        alertView = [[UIAlertView alloc] initWithTitle:@"No Data" message:@"You need to load at least one data set.  Tap the info button and read the directions for where to get a data set." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [alertView show];
        [self clearMessage];
        [self clearDisplayMessage];
        [self disableSettings];
    }
    
    messageLabel.layer.cornerRadius = 9.0;
    messageLabel.layer.masksToBounds = YES;
    messageLabel.layer.borderColor = [UIColor grayColor].CGColor;
    displayLabel.layer.cornerRadius = 9.0;
    displayLabel.layer.masksToBounds = YES;
    displayLabel.layer.borderColor = [UIColor grayColor].CGColor;

    
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
    
    // Note: Obviously fill these in correctly in the future
    leftButton.enabled = false;
    leftButton.alpha = 0.25;
    leftButton.layer.cornerRadius = 9.0;
    leftButton.layer.masksToBounds = YES;
    leftButton.layer.borderColor = [UIColor grayColor].CGColor;
    rightButton.enabled = false;
    rightButton.alpha = 0.25;
    rightButton.layer.cornerRadius = 9.0;
    rightButton.layer.masksToBounds = YES;
    rightButton.layer.borderColor = [UIColor grayColor].CGColor;
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

- (void)setDisplayMessage:(NSAttributedString *)msg
{
    displayLabel.attributedText = msg;
    
    [UIView animateWithDuration:1.0 animations:
     ^{
         displayLabel.alpha = 0.75;
     }];
    
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(clearDisplayMessage) object:nil];
}

- (void)clearDisplayMessage
{
    [UIView animateWithDuration:1.0 animations:
     ^{
         displayLabel.alpha = 0.0;
         displayLabel.text = @"";
     }];    
}

- (void)disableSettings
{
    settingsButton.enabled = FALSE;
    settingsButton.alpha = 0.25;
    controlView.userInteractionEnabled = false;
    controlView.alpha = 0.25;
    pickingEnabled = false;
}

- (void)enableSettings
{
    settingsButton.enabled = TRUE;
    settingsButton.alpha = 1.0;
    controlView.userInteractionEnabled = true;
    controlView.alpha = 1.0;
    pickingEnabled = true;
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
    [self clearSelection];
    
    [self setMessage:[NSString stringWithFormat:@"Loading %@",toLoad.name]];
    [self clearDisplayMessage];
    
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
                                          dataSet.colors = dataFieldColors;
                                          if (dataSet)
                                          {
                                              [self jumpToDataSet];
                                              
                                              dataSet.displayRoutes = true;

                                              if ([dataSet->dataFields count] > 0)
                                              {
                                                  dataSet.selectedFields = [NSMutableArray arrayWithObject:[dataSet->dataFields objectAtIndex:0]];
                                                  [self performSelector:@selector(updateDisplay) withObject:nil afterDelay:0.0];
                                              }
                                          }
                                          
                                          [self clearMessage];

                                          [self enableSettings];
                                      });
                   });
}

- (void)calcStartTime:(NSTimeInterval *)startTime endTime:(NSTimeInterval *)endTime
{
    int dayOfWeek = segControl.selectedSegmentIndex;
    NSTimeInterval timeOffset = dayOfWeek * 24 * 60* 60;
    *startTime = rangeSelect.leftValue + timeOffset;
    *endTime = rangeSelect.rightValue + timeOffset;
}

- (void)updateDisplay
{
    [self clearSelection];
    
    NSTimeInterval startTime,endTime;
    [self calcStartTime:&startTime endTime:&endTime];
    
    if (dataSet)
    {
        [self setMessage:@"Running Query"];
        [self clearDisplayMessage];
        [self disableSettings];
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,0),
                       ^{
                           NSAttributedString *queryMsg = [dataSet runQueryFrom:startTime to:endTime];
                           dispatch_async(dispatch_get_main_queue(),
                                          ^{
                                              [self enableSettings];
                                              [self clearMessage];
                                              [self setDisplayMessage:queryMsg];
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

- (IBAction)infoAction:(id)sender
{
    UIView *senderView = (UIView *)sender;
    
    UIViewController *webViewC = [[UIViewController alloc] init];
    UIWebView *webView = [[UIWebView alloc] init];
    [webViewC.view addSubview:webView];
    webView.frame = webViewC.view.bounds;
    webView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [webView loadRequest:[NSURLRequest requestWithURL:[[NSBundle mainBundle] URLForResource:@"info" withExtension:@"html"]]];
    webView.delegate = self;
    
    popControl = [[UIPopoverController alloc] initWithContentViewController:webViewC];
    popControl.popoverContentSize = CGSizeMake(640,600);
    [popControl presentPopoverFromRect:senderView.frame inView:self.view permittedArrowDirections:UIPopoverArrowDirectionAny animated:YES];
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
//                    dataSet.selectedField = dataFieldSelector->selected;
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
            dataFieldSelector = [[DataFieldSelector alloc] initWithDataFields:dataSet->dataFields colors:dataFieldColors];
            dataFieldSelector.selections = dataSet.selectedFields;
            tableViewC.tableView.dataSource = dataFieldSelector;
            tableViewC.tableView.delegate = dataFieldSelector;
            
            [popNavC pushViewController:tableViewC animated:YES];
        }
            break;
    }
}

#pragma mark - WhirlyGlobe delegate

static const float MarginWidth = 10.0;
static const float MarginHeight = 4.0;
static const float InterMarginHeight = 2.0;

// Construct a view used for selection display
- (UIView *)makeSelectView:(TransitStopInfo *)stopInfo full:(bool)fullInfo
{
    // We put the data in the content view
    UIView *contentView = [[UIView alloc] init];
    contentView.backgroundColor = [UIColor colorWithRed:0.25 green:0.25 blue:0.25 alpha:0.5];

    float totHeight = MarginHeight;
    float maxWidth = 0.0;
    // Label is the name of the stop
    {
        UILabel *label = [[UILabel alloc] init];
        label.font = [UIFont boldSystemFontOfSize:12.0];
        label.text = stopInfo.stopName;
        CGSize textSize = [label.text sizeWithFont:label.font];
        label.frame = CGRectMake(MarginWidth,totHeight,textSize.width,textSize.height);
        maxWidth = std::max(maxWidth,textSize.width);
        totHeight += textSize.height + InterMarginHeight;
        label.backgroundColor = [UIColor clearColor];
        label.textColor = [UIColor whiteColor];
        [contentView addSubview:label];
    }
    
    if (fullInfo)
    {
        // Data values to draw
        for (NSDictionary *entry in [stopInfo.values allValues])
        {
            NSString *name = entry[@"name"];
            NSNumber *val = entry[@"value"];
            if (name && val)
            {
                UILabel *label = [[UILabel alloc] init];
                label.font = [UIFont systemFontOfSize:12.0];
                label.text = [NSString stringWithFormat:@"%@: %@",name,[val stringValue]];
                CGSize textSize = [label.text sizeWithFont:label.font];
                label.frame = CGRectMake(MarginWidth,totHeight,textSize.width,textSize.height);
                totHeight += textSize.height + InterMarginHeight;
                maxWidth = std::max(maxWidth,textSize.width);
                label.backgroundColor = [UIColor clearColor];
                label.textColor = [UIColor whiteColor];
                [contentView addSubview:label];                
            }
        }
        // Routes
        if ([stopInfo.routes count] > 0)
        {
            NSMutableString *str = [NSMutableString stringWithString:(([stopInfo.routes count] > 1) ? @"Routes" : @"Route")];
            for (NSString *route in stopInfo.routes)
            {
                [str appendFormat:@" %@",route];
            }
            UILabel *label = [[UILabel alloc] init];
            label.font = [UIFont systemFontOfSize:12.0];
            label.text = str;
            CGSize textSize = [label.text sizeWithFont:label.font];
            label.frame = CGRectMake(MarginWidth,totHeight,textSize.width,textSize.height);
            totHeight += textSize.height + InterMarginHeight;
            maxWidth = std::max(maxWidth,textSize.width);
            label.backgroundColor = [UIColor clearColor];
            label.textColor = [UIColor whiteColor];
            [contentView addSubview:label];
        }
    }

    // Size the content view to the content
    contentView.layer.cornerRadius = 9.0;
    contentView.layer.masksToBounds = YES;
    contentView.layer.borderColor = [UIColor grayColor].CGColor;
    float width = maxWidth+2*MarginWidth;
    float height = totHeight+MarginHeight;
    contentView.frame = CGRectMake(-width/2,0,width,height);

    // We've got a stop level view so the content can center itself
    UIView *topView = [[UIView alloc] init];
    topView.frame = CGRectMake(0, 0, width, height);
    topView.backgroundColor = [UIColor clearColor];
    topView.clipsToBounds = NO;
    topView.hidden = YES;
    [topView addSubview:contentView];
    
    return topView;
}

- (void)clearSelection
{
    if (selectView)
    {
        [baseViewC removeViewTrackForView:selectView];
        [selectView removeFromSuperview];
        selectView = nil;
    }
}

// Display the current selection (no delay)
- (void)selectionDisplay:(TransitStopInfo *)stopInfo cylinder:(MaplyShapeCylinder *)cyl full:(bool)full
{
    selectView = [self makeSelectView:stopInfo full:full];
    MaplyViewTracker *viewTrack = [[MaplyViewTracker alloc] init];
    viewTrack.view = selectView;
    viewTrack.loc = cyl.baseCenter;
    // Note: Could use a visibility range
    [baseViewC addViewTracker:viewTrack];
}

- (void)globeViewController:(WhirlyGlobeViewController *)viewC didSelect:(NSObject *)selectedObj atLoc:(WGCoordinate)coord onScreen:(CGPoint)screenPt
{
    [self clearSelection];
    if (!pickingEnabled)
        return;
    
    if ([selectedObj isKindOfClass:[MaplyShapeCylinder class]])
    {
        MaplyShapeCylinder *cyl = (MaplyShapeCylinder *)selectedObj;
        if ([cyl.userObject isKindOfClass:[NSString class]])
        {
            NSString *stopId = (NSString *)cyl.userObject;
            TransitStopInfo *stopInfo = [dataSet infoForStop:stopId];
            if (stopInfo)
            {
                // Display what we have
                [self selectionDisplay:stopInfo cylinder:cyl full:false];
                
                [self disableSettings];
                
                // Query for more data
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),
                               ^{
                                   NSTimeInterval startTime,endTime;
                                   [self calcStartTime:&startTime endTime:&endTime];
                                   [dataSet rerunQueryOnStop:stopInfo from:startTime to:endTime];
                                   
                                   dispatch_async(dispatch_get_main_queue(),
                                                  ^{
                                                      if (selectView)
                                                      {
                                                          [self clearSelection];
                                                          [self selectionDisplay:stopInfo cylinder:cyl full:true];
                                                      }
                                                      [self enableSettings];
                                                  });
                               });
            }
        }
    }
}

- (void)globeViewController:(WhirlyGlobeViewController *)viewC didTapAt:(WGCoordinate)coord
{
    [self clearSelection];
}

#pragma mark - UIWebViewDelegate

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType
{
    if (navigationType == UIWebViewNavigationTypeLinkClicked)
    {
        [popControl dismissPopoverAnimated:NO];
        [[UIApplication sharedApplication] openURL:request.URL];
        
        return NO;
    }
    return YES;
}

@end
