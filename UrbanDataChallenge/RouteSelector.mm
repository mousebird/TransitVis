//
//  RouteSelector.m
//  UrbanDataChallenge
//
//  Created by Steve Gifford on 3/15/13.
//  Copyright (c) 2013 mousebird consulting. All rights reserved.
//

#import "RouteSelector.h"

@implementation RouteSelector

- (id)initWithRoutes:(NSArray *)inRoutes
{
    self = [super init];
    if (!self)
        return nil;
    
    routes = inRoutes;
    enables = [NSMutableArray array];
    for (unsigned int ii=0;ii<[routes count];ii++)
        [enables addObject:@(true)];
    
    return self;
}

- (int)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    int num = 0;
    
    switch (section)
    {
        case 0:
            num = 2;
            break;
        case 1:
            num = [routes count];
            break;
    }
    
    return num;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == 0)
    {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"allCell"];
        if (!cell)
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"allCell"];
        switch (indexPath.row)
        {
            case 0:
                cell.textLabel.text = @"All Routes";
                break;
            case 1:
                cell.textLabel.text = @"No Routes";
                break;
        }
        
        return cell;
    }
    
    if (indexPath.row >= [routes count])
        return nil;
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"routeCell"];
    if (!cell)
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"routeCell"];
    cell.accessoryType = ([enables[indexPath.row] boolValue] ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone);
        cell.textLabel.text = [routes objectAtIndex:indexPath.row];
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    switch (indexPath.section)
    {
        case 0:
            switch (indexPath.row)
            {
                case 0:
                    for (unsigned int ii=0;ii<[enables count];ii++)
                        enables[ii] = @(true);
                    break;
                case 1:
                    for (unsigned int ii=0;ii<[enables count];ii++)
                        enables[ii] = @(false);
                    break;
            }
            [tableView reloadData];
            break;
        case 1:
            enables[indexPath.row] = @(!([enables[indexPath.row] boolValue]));
            [tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
            break;
    }
    
}

@end
