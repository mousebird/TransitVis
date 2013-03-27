//
//  LoadableTransitDataSet.m
//  UrbanDataChallenge
//
//  Created by Steve Gifford on 3/20/13.
//  Copyright (c) 2013 mousebird consulting. All rights reserved.
//

#import "LoadableTransitDataSet.h"

@implementation LoadableTransitDataSet

// Look for all the viable data sets in a particular directory
+ (NSArray *)FindAllDataSetsFrom:(NSString *)dir
{
    NSMutableArray *retSets = [NSMutableArray array];
    
    NSFileManager *defaultFileManager = [NSFileManager defaultManager];
    NSError *error = nil;
    NSArray *contents = [defaultFileManager contentsOfDirectoryAtPath:dir error:&error];
    for (NSString *file in contents)
    {
        NSString *ext = [file pathExtension];
        if (ext && ![ext compare:@"transitdb"])
        {
            NSString *fileName = [file lastPathComponent];
            if (fileName > 0)
            {
                NSString *baseName = [fileName stringByDeletingPathExtension];
                if (baseName)
                {
                    // Look for the files with this name
                    NSString *stopJsonFile = [NSString stringWithFormat:@"%@/%@_stops.geojson",dir,baseName];
                    NSString *routeJsonFile = [NSString stringWithFormat:@"%@/%@_routes.geojson",dir,baseName];
                    if ([defaultFileManager fileExistsAtPath:stopJsonFile] ||
                        [defaultFileManager fileExistsAtPath:routeJsonFile])
                    {
                        LoadableTransitDataSet *dataSet = [[LoadableTransitDataSet alloc] init];
                        dataSet.name = baseName;
                        dataSet.stopTable = [NSString stringWithFormat:@"%@/%@",dir,file];
                        dataSet.stopJson = stopJsonFile;
                        dataSet.lineJson = routeJsonFile;
                        [retSets addObject:dataSet];
                    }
                }
            }
        }
    }
    
    return retSets;
}

// Look for all the data sets in areas we know about
+ (NSArray *)FindAllDataSets
{
    NSString *bundleDir = [[NSBundle mainBundle] bundlePath];
    NSArray *fromBundle = [LoadableTransitDataSet FindAllDataSetsFrom:bundleDir];
    
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *docDir = ([paths count] > 0) ? [paths objectAtIndex:0] : nil;
    NSArray *fromDocs = nil;
    NSMutableArray *allFiles = [NSMutableArray arrayWithArray:fromBundle];
    if (docDir)
    {
        fromDocs = [LoadableTransitDataSet FindAllDataSetsFrom:docDir];
        [allFiles addObjectsFromArray:fromDocs];
    }
    
    return allFiles;
}


@end
