//
//  PhotosByPhotographerTableViewController.m
//  Photomania
//
//  Created by Martin Mandl on 31.07.12.
//  Copyright (c) 2012 m2m. All rights reserved.
//

#import "PhotosByPhotographerTableViewController.h"
#import "ImageViewController.h"
#import "Photo.h"

@interface PhotosByPhotographerTableViewController ()

@end

@implementation PhotosByPhotographerTableViewController

@synthesize photographer = _photographer;

- (void)setupFetchedResultsController
{
    NSFetchRequest *reqest = [NSFetchRequest fetchRequestWithEntityName:@"Photo"];
    reqest.predicate = [NSPredicate predicateWithFormat:@"whoTook.name = %@", self.photographer.name];
    reqest.sortDescriptors = [NSArray arrayWithObject:
                              [NSSortDescriptor sortDescriptorWithKey:@"title" 
                                                            ascending:YES 
                                                             selector:@selector(localizedCaseInsensitiveCompare:)]];
    self.fetchedResultsController = [[NSFetchedResultsController alloc] 
                                     initWithFetchRequest:reqest 
                                     managedObjectContext:self.photographer.managedObjectContext
                                     sectionNameKeyPath:nil 
                                     cacheName:nil];
}

- (void)setPhotographer:(Photographer *)photographer
{
    if (_photographer == photographer) return; 
    _photographer = photographer;
    self.title = photographer.name;
    [self setupFetchedResultsController];
}


#pragma mark - Live cycle

#pragma mark - Table view data source

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"Photo Cell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle 
                                             reuseIdentifier:CellIdentifier];
    
    Photo *photo = [self.fetchedResultsController objectAtIndexPath:indexPath];
    cell.textLabel.text = photo.title;
    cell.detailTextLabel.text = photo.subtitle;
    
    return cell;
}

#pragma mark - Table view delegate

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    NSIndexPath *indexPath = [self.tableView indexPathForCell:sender];
    Photo *photo = [self.fetchedResultsController objectAtIndexPath:indexPath]; // ask NSFRC for the NSMO at the row in question
    if ([segue.identifier isEqualToString:@"Show Photo"]) {
        [segue.destinationViewController setImageURL:[NSURL URLWithString:photo.imageUrl]];
        [segue.destinationViewController setTitle:photo.title];
    }
}

@end
