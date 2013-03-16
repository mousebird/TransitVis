//
//  TransitDataSet.m
//  UrbanDataChallenge
//
//  Created by Steve Gifford on 3/15/13.
//  Copyright (c) 2013 mousebird consulting. All rights reserved.
//

#import "TransitDataSet.h"
#import "StopAccumulator.h"

@implementation TransitDataField
@end

@implementation TransitDataSet

- (id)initWithDB:(NSString *)dbName routes:(NSString *)routeName stops:(NSString *)stopName viewC:(MaplyBaseViewController *)inViewC
{
    self = [super init];
    if (!self)
        return nil;
    
    viewC = inViewC;
    
    // Load the main database
    NSString *dbPath = [[NSBundle mainBundle] pathForResource:dbName ofType:@"db"];
    if (dbPath)
    {
        db = [[FMDatabase alloc] initWithPath:dbPath];
        if (![db open])
        {
            db = nil;
            return nil;
        }
    }
    
    // Let's figure out what all the routes are
    {
        NSMutableArray *routeNames = [NSMutableArray array];
        FMResultSet *results = [db executeQuery:@"SELECT distinct route from stopinfo;"];
        while ([results next])
        {
            NSString *routeStr = [results stringForColumn:@"route"];
            if (routeStr)
                [routeNames addObject:routeStr];
        }
        
        routes = routeNames;
    }
    
    // Look at the display info table for the field descriptions
    {
        NSMutableArray *displayFields = [NSMutableArray array];
        FMResultSet *results = [db executeQuery:@"SELECT * from displayableinfo;"];
        while ([results next])
        {
            TransitDataField *dataField = [[TransitDataField alloc] init];
            dataField->rawFieldName = [results stringForColumn:@"raw_field_name"];
            dataField->displayFieldName = [results stringForColumn:@"friendly_field_name"];
            dataField->fieldDesc = [results stringForColumn:@"friendly_field_descriptor"];
            if (dataField->rawFieldName && dataField->displayFieldName)
                [displayFields addObject:dataField];
        }
        dataFields = displayFields;
    }

    // Displayable route data
    NSData *routeData = [[NSData alloc] initWithContentsOfFile:[[NSBundle mainBundle] pathForResource:routeName ofType:@"geojson"]];
    routeVec = [MaplyVectorObject VectorObjectFromGeoJSON:routeData];

    // Same for stops
    NSData *stopData = [[NSData alloc] initWithContentsOfFile:[[NSBundle mainBundle] pathForResource:stopName ofType:@"geojson"]];
    stopVec = [MaplyVectorObject VectorObjectFromGeoJSON:stopData];
    
    _displayRoutes = false;
    
    queryQueue = dispatch_queue_create("com.mousebirdconsulting.queryQueue", NULL);
    
    return self;
}

- (void)setDisplayRoutes:(bool)newDisplayRoutes
{
    if (routeObj)
        [viewC removeObject:routeObj];
    routeObj = nil;

    _displayRoutes = newDisplayRoutes;
    if (_displayRoutes)
    {
        [viewC setVectorDesc:@{kMaplyVecWidth: @(4.0), kMaplyColor: [UIColor blackColor], kMaplyDrawOffset: @(0.01)}];
        routeObj = [viewC addVectors:@[routeVec]];
        [viewC setVectorDesc:@{kMaplyVecWidth: [NSNull null], kMaplyColor: [NSNull null], kMaplyDrawOffset: [NSNull null]}];
    } else {
        if (routeObj)
            [viewC removeObject:routeObj];
        routeObj = nil;
    }
}

- (void)shutdown
{
    if (routeObj)
        [viewC removeObject:routeObj];
    routeObj = nil;
    if (shapesObj)
        [viewC removeObject:shapesObj];
    shapesObj = nil;
}

static const float MaxCylinderRadius = 0.000002;
static const float MaxCylinderHeight = 0.002;
static const float CylinderOffset = 0.000001;

// Naive data extraction
- (void)runQueryFrom:(NSTimeInterval)startTime to:(NSTimeInterval)endTime
{
    // No field to display
    if (!_selectedField)
        return;
    
    if (shapesObj)
        [viewC removeObject:shapesObj];
    shapesObj = nil;
        
//    [rangeSelect setAlpha:0.2];
//    [rangeSelect setUserInteractionEnabled:NO];
//    [segControl setAlpha:0.2];
//    [segControl setUserInteractionEnabled:NO];
    
    dispatch_async(queryQueue,
                   ^{
                       NSString *query = [NSString stringWithFormat:@"SELECT * FROM stopinfo where time_stop > %f AND time_stop < %f;",startTime,endTime];
                       FMResultSet *results = [db executeQuery:query];
                       
                       // Merge the results together by stop
                       StopAccumulatorGroup stopGroup(stopVec,_selectedField->rawFieldName);
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
//                       UIColor *onColor = [UIColor colorWithRed:79/255.0 green:16/255.0 blue:173/255.0 alpha:1.0];
//                       UIColor *offColor = [UIColor colorWithRed:225/255.0 green:0.0 blue:76/255.0 alpha:1.0];
                       UIColor *cylColor = [UIColor colorWithRed:225/255.0 green:0.0 blue:76/255.0 alpha:1.0];
                       
                       // Work through the stop results, one by one
                       //    int numStops = stopGroup.stopSet.size();
                       NSMutableArray *shapes = [NSMutableArray array];
                       for (StopAccumulatorSet::iterator it = stopGroup.stopSet.begin();
                            it != stopGroup.stopSet.end(); ++it)
                       {
                           StopAccumulator *stop = *it;
                           //        int total = stop->pass_on+stop->pass_off;
//                           float disp_on = stop->pass_on / max_total * MaxCylinderHeight;
//                           float disp_off = stop->pass_off / max_total * MaxCylinderHeight;
//                           
//                           // Passengers getting on at the stop (displayed at the bottom)
//                           if (disp_on > 0)
//                           {
//                               MaplyShapeCylinder *cyl = [[MaplyShapeCylinder alloc] init];
//                               // Note: Lon is flipped
//                               cyl.baseCenter = stop->coord;
//                               cyl.baseHeight = CylinderOffset;
//                               cyl.radius = MaxCylinderRadius;
//                               cyl.height = disp_on;
//                               cyl.color = onColor;
//                               [shapes addObject:cyl];
//                           }
//                           // Passengers getting off at the stop (displayed at the top)
//                           if (disp_off > 0)
//                           {
//                               MaplyShapeCylinder *cyl = [[MaplyShapeCylinder alloc] init];
//                               // Note: lon is flipped
//                               cyl.baseCenter = stop->coord;
//                               cyl.baseHeight = disp_on+CylinderOffset;
//                               cyl.radius = MaxCylinderRadius;
//                               cyl.height = disp_off;
//                               cyl.color = offColor;
//                               [shapes addObject:cyl];
//                           }
                           
                           // Note: Would be good to have min/max data values in the table
                           float disp_val = stop->value / max_total * MaxCylinderHeight;
                           if (disp_val > 0)
                           {
                               MaplyShapeCylinder *cyl = [[MaplyShapeCylinder alloc] init];
                               cyl.baseCenter = stop->coord;
                               cyl.baseHeight = CylinderOffset;
                               cyl.radius = MaxCylinderRadius;
                               cyl.height = disp_val;
//                               cyl.color = cylColor;
                               [shapes addObject:cyl];
                           }
                       }
                       
                       dispatch_async(dispatch_get_main_queue(),
                                      ^{
                                          [viewC setShapeDesc:@{kMaplyColor: [UIColor redColor]}];
                                          shapesObj = [viewC addShapes:shapes];
                                          [viewC setShapeDesc:@{kMaplyColor: [NSNull null]}];
                                          
//                                          [rangeSelect setAlpha:1.0];
//                                          [rangeSelect setUserInteractionEnabled:YES];
//                                          [segControl setAlpha:1.0];
//                                          [segControl setUserInteractionEnabled:YES];
                                      });
                   });
}


@end
