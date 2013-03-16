//
//  StopAccumulator.h
//  UrbanDataChallenge
//
//  Created by Steve Gifford on 2/22/13.
//  Copyright (c) 2013 mousebird consulting. All rights reserved.
//

#import "RouteParser.h"

NSArray *ParseTransitRoutes(FMDatabase *db)
{
    NSString *query = [NSString stringWithFormat:@"SELECT * FROM routeinfo;"];

    FMResultSet *results = [db executeQuery:query];
    
    NSMutableArray *retVecs = [NSMutableArray array];
    // Work through the individual lines
    while ([results next])
    {
        int route_number = [results intForColumn:@"route_number"];
        if (route_number != 1)
            continue;
        NSString *route_details = [results stringForColumn:@"route_details"];
        NSArray *tokens = [route_details componentsSeparatedByString:@","];
        // Expecting pairs
        if ([tokens count] % 2 != 0)
            continue;
        int numCoords = [tokens count]/2;
        MaplyCoordinate coords[numCoords];
        for (unsigned int ii=0;ii<numCoords;ii++)
        {
            MaplyCoordinate &coord = coords[ii];
            coord.y = [[tokens objectAtIndex:ii*2] floatValue];
            // Note: Longitude flipped
            coord.x = -[[tokens objectAtIndex:(ii*2+1)] floatValue];
            coord = MaplyCoordinateMakeWithDegrees(coord.x, coord.y);
        }
        
        MaplyVectorObject *routeVec = [[MaplyVectorObject alloc] initWithLineString:coords numCoords:numCoords attributes:@{@"route_number": @(route_number)}];
        if (routeVec)
            [retVecs addObject:routeVec];
        
        break;
    }
    
    return retVecs;
}
