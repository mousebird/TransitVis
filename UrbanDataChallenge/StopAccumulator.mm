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
StopAccumulatorGroup::StopAccumulatorGroup(MaplyVectorObject *stopsVec,NSArray *queryFields,const std::set<Route> &validRoutes)
: queryFields(queryFields), validRoutes(validRoutes)
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
            for (unsigned int ii=0;ii<[queryFields count];ii++)
                theStop->values.push_back(0.0);
            stopSet.insert(theStop);
        }
    }
}

// Construct with just the one stop
StopAccumulatorGroup::StopAccumulatorGroup(NSString *stopId,NSArray *queryFields,const std::set<Route> &validRoutes)
: queryFields(queryFields), validRoutes(validRoutes)
{
    StopAccumulator *theStop = new StopAccumulator();
    theStop->stop_id = [stopId cStringUsingEncoding:NSASCIIStringEncoding];
    for (unsigned int ii=0;ii<[queryFields count];ii++)
        theStop->values.push_back(0.0);
    stopSet.insert(theStop);
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
        stop.values.resize([queryFields count]);
        stop.stop_id = [[results stringForColumn:@"stop_id"] cStringUsingEncoding:NSASCIIStringEncoding];
        for (unsigned int ii=0;ii<[queryFields count];ii++)
            stop.values[ii] = (float)[results doubleForColumn:[queryFields objectAtIndex:ii]];

        // This needs to be on a route we care about
        std::string routeStr = [[results stringForColumn:@"route"] cStringUsingEncoding:NSASCIIStringEncoding];
        std::set<Route>::iterator rit = validRoutes.find(Route(routeStr));
        if (rit == validRoutes.end())
            continue;
        // Mark the route as in use
        if (!rit->used)
        {
            Route theRoute = *rit;
            validRoutes.erase(rit);
            theRoute.used = true;
            validRoutes.insert(theRoute);
        }
        
        StopAccumulatorSet::iterator existingIt = stopSet.find(&stop);
        if (existingIt != stopSet.end())
        {
            // Already one there
            StopAccumulator *existStop = *existingIt;
            for (unsigned int ii=0;ii<existStop->values.size();ii++)
                existStop->values[ii] += stop.values[ii];
        } else {
            // Note: For some reason we have orphan bus stops
//            StopAccumulator *newStop = new StopAccumulator(stop);
//            newStop->coord = MaplyCoordinateMakeWithDegrees(-[results doubleForColumn:@"longitude"], [results doubleForColumn:@"latitude"]);
//            stopSet.insert(newStop);
        }
    }

    return true;
}
