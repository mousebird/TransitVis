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
        value = that.value;
    }
    // Unique stop ID
    std::string stop_id;
    // Location on the map
    MaplyCoordinate coord;
    // Values we're accumulating for now
    float value;
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
    StopAccumulatorGroup(MaplyVectorObject *stops,NSString *queryField,const std::set<std::string> &validRoutes);
    ~StopAccumulatorGroup();
    
    // Run the accumulation over the results of a query
    bool accumulateStops(FMResultSet *results);

    std::set<std::string> validRoutes;
    NSString *queryField;
    StopAccumulatorSet stopSet;
};

#endif /* defined(__UrbanDataChallenge__StopAccumulator__) */
