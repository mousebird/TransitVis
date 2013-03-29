//
//  TransitDataSet.m
//  UrbanDataChallenge
//
//  Created by Steve Gifford on 3/15/13.
//  Copyright (c) 2013 mousebird consulting. All rights reserved.
//

#import <string>
#import "TransitDataSet.h"
#import "StopAccumulator.h"

@implementation TransitDataField
@end

@implementation TransitStopInfo
@end

@implementation TransitDataSet
{
    // Set if we're displaying the routes
    MaplyComponentObject *routeObj;
    
    // Set if we're displaying the results of a query
    MaplyComponentObject *shapesObj,*labelsObj;
}

- (id)initWithDB:(NSString *)dbPath routes:(NSString *)routePath stops:(NSString *)stopPath viewC:(MaplyBaseViewController *)inViewC
{
    self = [super init];
    if (!self)
        return nil;
    
    viewC = inViewC;
    
    // Load the main database
    db = [[FMDatabase alloc] initWithPath:dbPath];
    if (![db open])
    {
        db = nil;
        return nil;
    }
    
    // Let's figure out what all the routes are
    {
        NSMutableArray *routeNames = [NSMutableArray array];
        FMResultSet *results = [db executeQuery:@"SELECT distinct route from stopinfo order by route;"];
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
            dataField.rawFieldName = [results stringForColumn:@"raw_field_name"];
            dataField.displayFieldName = [results stringForColumn:@"friendly_field_name"];
            dataField.fieldDesc = [results stringForColumn:@"friendly_field_descriptor"];
            dataField.units = [results stringForColumn:@"units"];
            if (dataField.rawFieldName && dataField.displayFieldName)
                [displayFields addObject:dataField];
        }
        dataFields = displayFields;
    }

    // Displayable route data
    NSData *routeData = [[NSData alloc] initWithContentsOfFile:routePath];
    routeVec = [MaplyVectorObject VectorObjectFromGeoJSON:routeData];
    if (!routeData || !routeVec)
        return nil;

    // Same for stops
    NSData *stopData = [[NSData alloc] initWithContentsOfFile:stopPath];
    stopVec = [MaplyVectorObject VectorObjectFromGeoJSON:stopData];
    if (!stopData || !stopVec)
        return nil;
    
    // Let's get the bounding box for the stops to figure out where we are
    [stopVec boundingBoxLL:&ll ur:&ur];
    
    _displayRoutes = false;
    
    autoScale = true;
    scale = 1.0;
    
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
        if (routeVec)
        {
            [viewC setVectorDesc:@{kMaplyVecWidth: @(4.0), kMaplyColor: [UIColor grayColor], kMaplyDrawOffset: @(0.01)}];
            routeObj = [viewC addVectors:@[routeVec]];
            [viewC setVectorDesc:@{kMaplyVecWidth: [NSNull null], kMaplyColor: [NSNull null], kMaplyDrawOffset: [NSNull null]}];
        }
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
    if (labelsObj)
        [viewC removeObject:labelsObj];
    labelsObj = nil;
}

// Pass back info about the given stop
- (TransitStopInfo *)infoForStop:(NSString *)stopId
{
    // Note: This will be slow
    NSArray *stops = [stopVec splitVectors];
    MaplyVectorObject *found = nil;
    for (MaplyVectorObject *stop in stops)
    {
        NSString *stopStr = [stop.attributes[@"STOPID"] stringValue];
        if (!stopStr)
            stopStr = stop.attributes[@"stopCode"];
        if (stopStr && ![stopStr compare:stopId])
        {
            found = stop;
            break;
        }
    }
    if (!found)
        return nil;
    
    TransitStopInfo *stopInfo = [[TransitStopInfo alloc] init];
    stopInfo.stopId = stopId;
    stopInfo.stopName = found.attributes[@"STOPNAME"];
    if (!stopInfo.stopName)
        stopInfo.stopName = found.attributes[@"stopName"];
    
    return stopInfo;
}

static const float MaxCylinderRadius = 0.000002;
static const float MaxCylinderHeight = 0.0003;
static const float CylinderOffset = 0.000001;

- (NSAttributedString *)runQueryFrom:(NSTimeInterval)startTime to:(NSTimeInterval)endTime
{
    // No field to display
    if ([_selectedFields count] == 0)
        return [[NSAttributedString alloc] initWithString:@""];
    
    if (shapesObj)
        [viewC removeObject:shapesObj];
    shapesObj = nil;
    
    // Assemble a list of routes we can search on
    std::set<std::string> validRoutes;
    for (unsigned int ii=0;ii<[routes count];ii++)
    {
        NSString *routeName = [routes objectAtIndex:ii];
        if (!_routeEnables || [[_routeEnables objectAtIndex:ii] boolValue])
        {
            std::string str = [routeName cStringUsingEncoding:NSASCIIStringEncoding];
            if (!str.empty())
                validRoutes.insert(str);
        }
    }
    
    NSString *query = [NSString stringWithFormat:@"SELECT * FROM stopinfo where time_stop > %f AND time_stop < %f;",startTime,endTime];
    FMResultSet *results = [db executeQuery:query];

    // Merge the results together by stop
    NSMutableArray *fieldNames = [NSMutableArray array];
    for (unsigned int ii=0;ii<[_selectedFields count];ii++)
        [fieldNames addObject:((TransitDataField *)_selectedFields[ii]).rawFieldName];
    StopAccumulatorGroup stopGroup(stopVec,fieldNames,validRoutes);
    stopGroup.accumulateStops(results);

    // Look for maximum value for scale
    float max_total=0;
    for (StopAccumulatorSet::iterator it = stopGroup.stopSet.begin();
         it != stopGroup.stopSet.end(); ++it)
    {
        StopAccumulator *stop = *it;
        float sum = 0;
        for (unsigned int ii=0;ii<stop->values.size();ii++)
            sum += stop->values[ii];
            max_total = std::max(sum,max_total);
    }
    if (autoScale)
        scale = 1.0/(max_total == 0.0 ? 1.0 : max_total);

    // Work through the stop results, one by one
    //    int numStops = stopGroup.stopSet.size();
    NSMutableArray *shapes = [NSMutableArray array];
    //                       NSMutableArray *labels = [NSMutableArray array];
    for (StopAccumulatorSet::iterator it = stopGroup.stopSet.begin();
        it != stopGroup.stopSet.end(); ++it)
    {
       StopAccumulator *stop = *it;
        float base = 0.0;
        for (unsigned int ii=0;ii<stop->values.size();ii++)
        {
            float disp_val = stop->values[ii] * scale * MaxCylinderHeight;
            if (disp_val > 0)
            {
                MaplyShapeCylinder *cyl = [[MaplyShapeCylinder alloc] init];
                cyl.baseCenter = stop->coord;
                cyl.baseHeight = CylinderOffset+base;
                cyl.radius = MaxCylinderRadius;
                cyl.height = disp_val;
                cyl.selectable = true;
                cyl.userObject = [NSString stringWithFormat:@"%s",stop->stop_id.c_str()];
                if ([_colors count] > 0)
                    cyl.color = [_colors objectAtIndex:ii%[_colors count]];
                [shapes addObject:cyl];
                base += disp_val;
                
//                               MaplyScreenLabel *label = [[MaplyScreenLabel alloc] init];
//                               label.loc = stop->coord;
//                               label.text = [NSString stringWithFormat:@"%.2f",stop->value];
//                               [labels addObject:label];
            }
        }
    }
    
    dispatch_async(dispatch_get_main_queue(),
                  ^{
                      [viewC setShapeDesc:@{kMaplyColor: [UIColor redColor]}];
                      shapesObj = [viewC addShapes:shapes];
                      [viewC setShapeDesc:@{kMaplyColor: [NSNull null]}];
                      [viewC setScreenLabelDesc:@{kMaplyTextColor: [UIColor whiteColor], kMaplyShadowColor: [UIColor blackColor], kMaplyLabelHeight: @(10.0)}];
//                                          labelsObj = [viewC addScreenLabels:labels];
                      [viewC setScreenLabelDesc:@{kMaplyTextColor: [NSNull null], kMaplyShadowColor: [NSNull null], kMaplyLabelHeight: [NSNull null]}];
                  });
    
    // Construct a return string that describes what the user is seeing
    NSMutableAttributedString *retStr = [[NSMutableAttributedString alloc] init];
    NSString *units = nil;
    for (unsigned int ii=0;ii<[_selectedFields count];ii++)
    {
        TransitDataField *dataField = _selectedFields[ii];
        units = dataField.units;
        if (ii > 0)
            [retStr appendAttributedString:[[NSAttributedString alloc] initWithString:@" + "]];
        int start = [retStr length];
        int len = [dataField.displayFieldName length];
        [retStr appendAttributedString:[[NSAttributedString alloc] initWithString:dataField.displayFieldName]];
        if ([_colors count] > 0)
        {
            UIColor *color = nil;
            color = [_colors objectAtIndex:ii%[_colors count]];
            float r,g,b,a;
            [color getRed:&r green:&g blue:&b alpha:&a];
            r = std::min(r+0.5,1.0);  g = std::min(g+0.5,1.0);  b = std::min(b+0.5,1.0);
            color = [UIColor colorWithRed:r green:g blue:b alpha:1.0];
            [retStr addAttribute:NSForegroundColorAttributeName value:color range:NSMakeRange(start,len)];
        }
    }
    [retStr appendAttributedString:[[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@" (max: %.2f %@)",max_total,units]]];
    
    return retStr;
}

@end
