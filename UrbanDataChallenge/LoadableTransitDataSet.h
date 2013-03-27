//
//  LoadableTransitDataSet.h
//  UrbanDataChallenge
//
//  Created by Steve Gifford on 3/20/13.
//  Copyright (c) 2013 mousebird consulting. All rights reserved.
//

#import <Foundation/Foundation.h>

// Used to figure out what data sets have files in the bundle or documents dir.
// These can be loaded by the TransitDataSet.
@interface LoadableTransitDataSet : NSObject

// Name taken from the stop table
@property (nonatomic) NSString *name;
// Location of stop data sqlite db
@property (nonatomic) NSString *stopTable;
// Location of stop geojson
@property (nonatomic) NSString *stopJson;
// Location of line geojson
@property (nonatomic) NSString *lineJson;

// Look for all the loadable data sets in the bundle and Documents area
+ (NSArray *)FindAllDataSets;

@end
