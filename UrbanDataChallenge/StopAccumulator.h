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
#import "FMDatabase.h"

// Used to accumulate basic stop data
class StopAccumulator
{
public:
    StopAccumulator() { }
    StopAccumulator(const StopAccumulator &that)
    {
        stop_id = that.stop_id;  lon = that.lon;  lat = that.lat;
        pass_on = that.pass_on;  pass_off = that.pass_off;
    }
    // Unique stop ID
    int stop_id;
    // Location on the map
    float lon,lat;
    // Values we're accumulating for now
    float pass_on,pass_off;
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
    StopAccumulatorGroup() {}
    ~StopAccumulatorGroup();
    
    // Run the accumulation over the results of a query
    bool accumulateStops(FMResultSet *results);
    
    StopAccumulatorSet stopSet;
};

#endif /* defined(__UrbanDataChallenge__StopAccumulator__) */
