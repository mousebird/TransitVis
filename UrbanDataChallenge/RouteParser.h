//
//  StopAccumulator.h
//  UrbanDataChallenge
//
//  Created by Steve Gifford on 2/22/13.
//  Copyright (c) 2013 mousebird consulting. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "WhirlyGlobeComponent.h"

#import "FMDatabase.h"

// Turn the routes into vectors.  One linear per route.
NSArray *ParseTransitRoutes(FMDatabase *);
