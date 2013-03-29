//
//  DataFieldSelector.m
//  UrbanDataChallenge
//
//  Created by Steve Gifford on 3/15/13.
//  Copyright (c) 2013 mousebird consulting. All rights reserved.
//

#import "DataFieldSelector.h"

@implementation DataFieldSelector
{
    NSArray *_colors;
}

- (id)initWithDataFields:(NSArray *)inFields colors:(NSArray *)colors
{
    self = [super init];
    if (!self)
        return nil;
    
    _fields = inFields;
    _selections = [NSMutableArray array];
    _colors = colors;
    
    return self;
}

- (int)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [_fields count];
}

- (float)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 86.0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.row >= [_fields count])
        return nil;
    
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
    
    TransitDataField *field = [_fields objectAtIndex:indexPath.row];
    cell.textLabel.text = field.displayFieldName;
    cell.textLabel.backgroundColor = [UIColor clearColor];
    cell.detailTextLabel.text = field.fieldDesc;
    cell.detailTextLabel.numberOfLines = 0;
    cell.detailTextLabel.backgroundColor = [UIColor clearColor];
    
    int selectId = [_selections indexOfObject:field];
    if (selectId != NSNotFound)
    {
        UIColor *theColor = [_colors objectAtIndex:selectId % [_colors count]];
        float r,g,b,a;
        [theColor getRed:&r green:&g blue:&b alpha:&a];
        cell.contentView.backgroundColor = [UIColor colorWithRed:r green:g blue:b alpha:0.25];
    }
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    TransitDataField *selected = [_fields objectAtIndex:indexPath.row];
    
    if ([_selections indexOfObject:selected] == NSNotFound)
    {
        // See what the units are of existing selections
        NSString *units = nil;
        if ([_selections count] > 0)
        {
            TransitDataField *existing = [_selections objectAtIndex:0];
            units = existing.units;
        }
        if (units && [units compare:selected.units])
            [_selections removeAllObjects];
        
        [_selections addObject:selected];
    } else {
        [_selections removeObject:selected];
    }

    NSMutableArray *allRows = [NSMutableArray array];
    for (unsigned int ii=0;ii<[_fields count];ii++)
        [allRows addObject:[NSIndexPath indexPathForRow:ii inSection:0]];
    [tableView reloadRowsAtIndexPaths:allRows withRowAnimation:UITableViewRowAnimationFade];
}

@end
