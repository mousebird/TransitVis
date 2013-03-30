//
//  TransitDataSet.h
//  UrbanDataChallenge
//
//  Created by Steve Gifford on 3/15/13.
//  Copyright (c) 2013 mousebird consulting. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "WhirlyGlobeComponent.h"
#import "FMDatabase.h"

// Info about a single query-able field in the main table
@interface TransitDataField : NSObject

// The raw name we can use for queries
@property(nonatomic) NSString *rawFieldName;
// A friendly name to display to users
@property(nonatomic) NSString *displayFieldName;
// A user friendly description of the field
@property(nonatomic) NSString *fieldDesc;
// Units, used for comparison
@property(nonatomic) NSString *units;

@end

// Information about a specific stop related to the current query
@interface TransitStopInfo : NSObject

// Unique stop ID
@property(nonatomic) NSString *stopId;
// User friendly stop name
@property(nonatomic) NSString *stopName;
// Dictionary of values related to the active query
@property(nonatomic) NSDictionary *values;
// Routes this stop is included in
@property(nonatomic) NSArray *routes;

@end

/* Encapsulates a single transit data set and queries we can make against it.
 */
@interface TransitDataSet : NSObject
{
@public
    // Display view controller
    MaplyBaseViewController *viewC;
    // SQlite database
    FMDatabase *db;
    // Routes in displayable form
    MaplyVectorObject *routeVec;
    // Stops in displayable form
    MaplyVectorObject *stopVec;
    
    // All the displayable fields.  These are TransitDataField objects
    NSArray *dataFields;
    
    // Names of all the transit routes.  These are strings.
    NSArray *routes;

    // Bounding box of stops
    MaplyCoordinate ll,ur;
    
    // Set if we're doing autoscale
    bool autoScale;
    // Used if we're not doing autoscale, or set to the last scale calculation
    float scale;
}

// Initialize with the database name, route name (geojson file) and view controller
- (id)initWithDB:(NSString *)dbName routes:(NSString *)routeName stops:(NSString *)stopName viewC:(MaplyBaseViewController *)viewC;

// Turn this on/off to control route display
@property (nonatomic,assign) bool displayRoutes;

// Set this to an array of NSNumber booleans telling us what routes are on/off
@property (nonatomic,strong) NSArray *routeEnables;

// Set this to field we want displayed
@property (nonatomic,strong) NSMutableArray *selectedFields;

// Colors we'll use for the cylinders.
@property (nonatomic,strong) NSArray *colors;

// Run the simple query.  Obviously more to this soon.
- (NSAttributedString *)runQueryFrom:(NSTimeInterval)startTime to:(NSTimeInterval)endTime;

// Rerun the query on a single stop to get more info
- (void)rerunQueryOnStop:(TransitStopInfo *)stopInfo from:(NSTimeInterval)startTime to:(NSTimeInterval)endTime;

// Info for the given stop
- (TransitStopInfo *)infoForStop:(NSString *)stopId;

// Clear out everything we're displaying
- (void)shutdown;

@end
