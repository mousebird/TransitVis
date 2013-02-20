//
//  StopAccumulator.cpp
//  UrbanDataChallenge
//
//  Created by Steve Gifford on 2/18/13.
//  Copyright (c) 2013 mousebird consulting. All rights reserved.
//

#include "StopAccumulator.h"

// Destructor has to clean out the allocated stops
// Note: We could do this with Boost, obviously
StopAccumulatorGroup::~StopAccumulatorGroup()
{
    for (StopAccumulatorSet::iterator it = stopSet.begin();
         it != stopSet.end(); ++it)
        delete *it;
    stopSet.clear();
}

// Run through the results and gather up stats
bool StopAccumulatorGroup::accumulateStops(FMResultSet *results)
{
    while ([results next])
    {
        StopAccumulator stop;
        stop.stop_id = [results intForColumn:@"stop_id"];
        stop.pass_on = [results intForColumn:@"passengers_on"];
        stop.pass_off = [results intForColumn:@"passengers_off"];
        stop.lat = [results doubleForColumn:@"latitude"];
        stop.lon = [results doubleForColumn:@"longitude"];
        
        StopAccumulatorSet::iterator existingIt = stopSet.find(&stop);
        if (existingIt != stopSet.end())
        {
            // Already one there
            StopAccumulator *existStop = *existingIt;
            existStop->pass_on += stop.pass_on;
            existStop->pass_off += stop.pass_off;
        } else {
            // Add it
            StopAccumulator *newStop = new StopAccumulator(stop);
            stopSet.insert(newStop);
        }
    }

    return true;
}