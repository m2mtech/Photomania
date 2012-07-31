//
//  PhotographersTableViewController.m
//  Photomania
//
//  Created by Martin Mandl on 31.07.12.
//  Copyright (c) 2012 m2m. All rights reserved.
//

#import "PhotographersTableViewController.h"
#import "FlickrFetcher.h"
#import "Photographer.h"
#import "Photo+Flickr.h"

@interface PhotographersTableViewController ()

@end

@implementation PhotographersTableViewController

@synthesize photoDatabase = _photoDatabase;

- (void)setupFetchedResultsController
{
    NSFetchRequest *reqest = [NSFetchRequest fetchRequestWithEntityName:@"Photographer"];
    reqest.sortDescriptors = [NSArray arrayWithObject:
                              [NSSortDescriptor sortDescriptorWithKey:@"name" 
                                                            ascending:YES 
                                                             selector:@selector(localizedCaseInsensitiveCompare:)]];
    self.fetchedResultsController = [[NSFetchedResultsController alloc] 
                                     initWithFetchRequest:reqest 
                                     managedObjectContext:self.photoDatabase.managedObjectContext 
                                       sectionNameKeyPath:nil 
                                                cacheName:nil];
}

- (void)fetchFlickrDataIntoDocument:(UIManagedDocument *)document
{
    dispatch_queue_t queue = dispatch_queue_create("Flickr Fetcher Queue", NULL);
    dispatch_async(queue, ^{
        NSArray *photos = [FlickrFetcher recentGeoreferencedPhotos];
        [document.managedObjectContext performBlock:^{
            for (NSDictionary *flickrInfo in photos) {
                [Photo photoWithFlickrInfo:flickrInfo 
                    inManagedObjectContext:document.managedObjectContext];
            }
            [document saveToURL:document.fileURL forSaveOperation:UIDocumentSaveForOverwriting completionHandler:NULL];
        }];        
    });
    dispatch_release(queue);
}

- (void)useDocument
{
    if (![[NSFileManager defaultManager] fileExistsAtPath:[self.photoDatabase.fileURL path]]) {
        [self.photoDatabase saveToURL:self.photoDatabase.fileURL 
                     forSaveOperation:UIDocumentSaveForCreating 
                    completionHandler:^(BOOL success) {
            [self setupFetchedResultsController];
            [self fetchFlickrDataIntoDocument:self.photoDatabase];
        }];
    } else if (self.photoDatabase.documentState == UIDocumentStateClosed) {
        [self.photoDatabase openWithCompletionHandler:^(BOOL success) {
            [self setupFetchedResultsController];            
        }];        
    } else if (self.photoDatabase.documentState == UIDocumentStateNormal) {
        [self setupFetchedResultsController];
    }
}

- (void)setPhotoDatabase:(UIManagedDocument *)photoDatabase
{
    if (_photoDatabase == photoDatabase) return;
    _photoDatabase = photoDatabase;
    [self useDocument];
}

#pragma mark - Live cycle

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    if (!self.photoDatabase) {
        NSURL *url = [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory 
                                                             inDomains:NSUserDomainMask] lastObject];
        url = [url URLByAppendingPathComponent:@"Default Photo Database"];
        self.photoDatabase = [[UIManagedDocument alloc] initWithFileURL:url];        
    }
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    NSIndexPath *indexPath = [self.tableView indexPathForCell:sender];
    Photographer *photographer = [self.fetchedResultsController objectAtIndexPath:indexPath];
    
    if ([segue.destinationViewController respondsToSelector:@selector(setPhotographer:)]) {
    	[segue.destinationViewController performSelector:@selector(setPhotographer:) withObject:photographer];
    }
}

#pragma mark - Table view data source

- (UITableViewCell *)tableView:(UITableView *)tableView 
         cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"Photographer Cell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle 
                                             reuseIdentifier:CellIdentifier];
    
    Photographer *photographer = [self.fetchedResultsController objectAtIndexPath:indexPath];
    cell.textLabel.text = photographer.name;
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%d photos", [photographer.photos count]];
    
    return cell;
}

#pragma mark - Table view delegate

@end
