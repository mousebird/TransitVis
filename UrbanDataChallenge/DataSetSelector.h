//
//  DataSetSelector.h
//  UrbanDataChallenge
//
//  Created by Steve Gifford on 3/20/13.
//  Copyright (c) 2013 mousebird consulting. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "LoadableTransitDataSet.h"

@interface DataSetSelector : NSObject <UITableViewDataSource,UITableViewDelegate>
{
@public
    NSArray *dataSets;
    LoadableTransitDataSet *selected;
}

// Initialize with loadable data sets
- (id)initWithDataSets:(NSArray *)dataSets;

// Callback for when a user selects a dta set
- (void)setTarget:(id)target selector:(SEL)sel;

@end
