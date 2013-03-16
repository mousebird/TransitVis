//
//  RouteSelector.h
//  UrbanDataChallenge
//
//  Created by Steve Gifford on 3/15/13.
//  Copyright (c) 2013 mousebird consulting. All rights reserved.
//

#import <UIKit/UIKit.h>

// Data source for table view in route selection
@interface RouteSelector : NSObject <UITableViewDataSource,UITableViewDelegate>
{
@public
    // An array of route strings
    NSArray *routes;
    NSMutableArray *enables;
}

// Initialize with the routes to use
- (id)initWithRoutes:(NSArray *)inRoutes;

@end
