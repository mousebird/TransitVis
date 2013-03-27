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
@property (nonatomic,strong) TransitDataField *selectedField;

// Run the simple query.  Obviously more to this soon.
- (void)runQueryFrom:(NSTimeInterval)startTime to:(NSTimeInterval)endTime;

// Clear out everything we're displaying
- (void)shutdown;

@end
