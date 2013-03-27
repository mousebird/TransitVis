//
//  DataSetSelector.m
//  UrbanDataChallenge
//
//  Created by Steve Gifford on 3/20/13.
//  Copyright (c) 2013 mousebird consulting. All rights reserved.
//

#import "DataSetSelector.h"

@implementation DataSetSelector
{
    id target;
    SEL sel;
}

- (id)initWithDataSets:(NSArray *)inDataSets
{
    self = [super init];
    if (!self)
        return nil;

    dataSets = inDataSets;
    selected = nil;
    
    return self;
}

- (void)setTarget:(id)inTarget selector:(SEL)inSel
{
    target = inTarget;
    sel = inSel;
}

- (int)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [dataSets count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.row >= [dataSets count])
        return nil;
    
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    
    LoadableTransitDataSet *dataSet = [dataSets objectAtIndex:indexPath.row];
    cell.textLabel.text = dataSet.name;
    
    cell.accessoryType = (dataSet == selected) ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    selected = [dataSets objectAtIndex:indexPath.row];
    if (target)
        [target performSelector:sel withObject:selected];
}

@end
