//
//  DataFieldSelector.m
//  UrbanDataChallenge
//
//  Created by Steve Gifford on 3/15/13.
//  Copyright (c) 2013 mousebird consulting. All rights reserved.
//

#import "DataFieldSelector.h"

@implementation DataFieldSelector

- (id)initWithDataFields:(NSArray *)inFields
{
    self = [super init];
    if (!self)
        return nil;
    
    fields = inFields;
    selected = nil;
    
    return self;
}

- (int)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [fields count];
}

- (float)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 86.0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.row >= [fields count])
        return nil;
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"fieldCell"];
    if (!cell)
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"fieldCell"];
    
    TransitDataField *field = [fields objectAtIndex:indexPath.row];
    cell.textLabel.text = field->displayFieldName;
    cell.detailTextLabel.text = field->fieldDesc;
    cell.detailTextLabel.numberOfLines = 0;

    cell.accessoryType = (field == selected) ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    selected = [fields objectAtIndex:indexPath.row];
    [tableView reloadData];
}

@end
