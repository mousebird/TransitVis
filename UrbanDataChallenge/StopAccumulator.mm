 //
//  StopAccumulator.cpp
//  UrbanDataChallenge
//
//  Created by Steve Gifford on 2/18/13.
//  Copyright (c) 2013 mousebird consulting. All rights reserved.
//

#import <string>
#include "StopAccumulator.h"

// Construct with the vectors for the stops
StopAccumulatorGroup::StopAccumulatorGroup(MaplyVectorObject *stopsVec,NSString *queryField,const std::set<std::string> &validRoutes)
: queryField(queryField), validRoutes(validRoutes)
{
    NSArray *stops = [stopsVec splitVectors];
    for (MaplyVectorObject *stop in stops)
    {
        StopAccumulator *theStop = new StopAccumulator();
        theStop->coord = [stop center];
        NSString *stopStr = nil;
        if (!(stopStr = [stop.attributes[@"STOPID"] stringValue]))
            stopStr = stop.attributes[@"stopCode"];
        if (stopStr)
        {
            theStop->stop_id = [stopStr cStringUsingEncoding:NSASCIIStringEncoding];
            theStop->value = 0.0;
            stopSet.insert(theStop);
        }
    }
}

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
        stop.stop_id = [[results stringForColumn:@"stop_id"] cStringUsingEncoding:NSASCIIStringEncoding];
        stop.value = (float)[results doubleForColumn:queryField];

        // This needs to be on a route we care about
        std::string routeStr = [[results stringForColumn:@"route"] cStringUsingEncoding:NSASCIIStringEncoding];
        if (validRoutes.find(routeStr) == validRoutes.end())
            continue;
        
        StopAccumulatorSet::iterator existingIt = stopSet.find(&stop);
        if (existingIt != stopSet.end())
        {
            // Already one there
            StopAccumulator *existStop = *existingIt;
            existStop->value += stop.value;
        } else {
            // Note: For some reason we have orphan bus stops
//            StopAccumulator *newStop = new StopAccumulator(stop);
//            newStop->coord = MaplyCoordinateMakeWithDegrees(-[results doubleForColumn:@"longitude"], [results doubleForColumn:@"latitude"]);
//            stopSet.insert(newStop);
        }
    }

    return true;
}
