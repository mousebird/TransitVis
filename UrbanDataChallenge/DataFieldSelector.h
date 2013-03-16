//
//  DataFieldSelector.h
//  UrbanDataChallenge
//
//  Created by Steve Gifford on 3/15/13.
//  Copyright (c) 2013 mousebird consulting. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "TransitDataSet.h"

@interface DataFieldSelector : NSObject <UITableViewDataSource,UITableViewDelegate>
{
@public
    // Array of TransitDataField objects
    NSArray *fields;
    TransitDataField *selected;
}

// Initialize with data fields
- (id)initWithDataFields:(NSArray *)inFields;

@end
