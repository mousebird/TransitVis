//
//  StopAccumulator.h
//  UrbanDataChallenge
//
//  Created by Steve Gifford on 2/18/13.
//  Copyright (c) 2013 mousebird consulting. All rights reserved.
//

#ifndef __UrbanDataChallenge__StopAccumulator__
#define __UrbanDataChallenge__StopAccumulator__

#include <set>
#include <vector>
#import <string>
#import "FMDatabase.h"
#import "WhirlyGlobeComponent.h"

// Used to accumulate basic stop data
class StopAccumulator
{
public:
    StopAccumulator() { }
    StopAccumulator(const StopAccumulator &that)
    {
        stop_id = that.stop_id;  coord = that.coord;
        values = that.values;
    }
    // Unique stop ID
    std::string stop_id;
    // Location on the map
    MaplyCoordinate coord;
    // Values we're accumulating for now
    std::vector<float> values;
};

// Comparator for pointers
struct StopAccumulatorCmp
{
    bool operator()(const StopAccumulator *a,const StopAccumulator *b)
    {
        return a->stop_id < b->stop_id;
    }
};

typedef std::set<StopAccumulator *,StopAccumulatorCmp> StopAccumulatorSet;

// Result of a query
class StopAccumulatorGroup
{
public:
    // Representation of a route and we track if we used it or not
    class Route
    {
    public:
        Route(const std::string &name) : name(name), used(false) { }
        bool operator < (const Route &that) const { return name < that.name; }
        std::string name;
        bool used;
    };

    StopAccumulatorGroup(MaplyVectorObject *stops,NSArray *queryFields,const std::set<StopAccumulatorGroup::Route> &validRoutes);
    StopAccumulatorGroup(NSString *stopID,NSArray *queryFields,const std::set<StopAccumulatorGroup::Route> &validRoutes);
    ~StopAccumulatorGroup();
    
    // Run the accumulation over the results of a query
    bool accumulateStops(FMResultSet *results);

    std::set<Route> validRoutes;
    NSArray *queryFields;
    StopAccumulatorSet stopSet;
};

#endif /* defined(__UrbanDataChallenge__StopAccumulator__) */
