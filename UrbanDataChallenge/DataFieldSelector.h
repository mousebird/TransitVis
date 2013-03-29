//
//  DataFieldSelector.h
//  UrbanDataChallenge
//
//  Created by Steve Gifford on 3/15/13.
//  Copyright (c) 2013 mousebird consulting. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "TransitDataSet.h"

// Table data source and delegate for selecting data fields to view
@interface DataFieldSelector : NSObject <UITableViewDataSource,UITableViewDelegate>

// Array of TransitDataField objects
@property (nonatomic) NSArray *fields;
// Ones we've selected and in which order
@property (nonatomic) NSMutableArray *selections;

// Initialize with data fields and colors to display them with
- (id)initWithDataFields:(NSArray *)inFields colors:(NSArray *)colors;

@end
