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
#import "DocumentTableViewController.h"

@interface PhotographersTableViewController () <DocumentTableViewControllerSegue>

@end

@implementation PhotographersTableViewController

@synthesize photoDatabase = _photoDatabase;

- (void)setDocument:(UIManagedDocument *)document
{
    self.photoDatabase = document;
}

- (UIManagedDocument *)document
{
    return self.photoDatabase;
}

- (void)startSpinner:(NSString *)activity
{
    self.navigationItem.title = activity;
    UIActivityIndicatorView *spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    [spinner startAnimating];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:spinner];
}

- (void)stopSpinner
{
    self.navigationItem.rightBarButtonItem = nil;
    self.navigationItem.title = self.title;
}

- (void)save
{
    [self.photoDatabase saveToURL:self.photoDatabase.fileURL 
                 forSaveOperation:UIDocumentSaveForOverwriting 
                completionHandler:^(BOOL success) {
                    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"Photographer"];
                    int photographercount = [self.photoDatabase.managedObjectContext countForFetchRequest:request 
                                                                                                    error:NULL];
                    NSString *documentNote = [NSString stringWithFormat:@"%d photographers", photographercount];
                    NSString *documentNoteKey = [self.photoDatabase.fileURL lastPathComponent];
                    [[NSUbiquitousKeyValueStore defaultStore] setObject:documentNote 
                                                                 forKey:documentNoteKey];
                    [[NSUbiquitousKeyValueStore defaultStore] synchronize];
    }];
}

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
    [self startSpinner:@"Flickr ..."];
    dispatch_queue_t queue = dispatch_queue_create("Flickr Fetcher Queue", NULL);
    dispatch_async(queue, ^{
        NSArray *photos = [FlickrFetcher recentGeoreferencedPhotos];
        [document.managedObjectContext performBlock:^{
            for (NSDictionary *flickrInfo in photos) {
                [Photo photoWithFlickrInfo:flickrInfo 
                    inManagedObjectContext:document.managedObjectContext];
            }
         [self save];
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

- (void)documentChanged:(NSNotification *)notification
{
    [self.photoDatabase.managedObjectContext mergeChangesFromContextDidSaveNotification:notification];
}

- (void)documentStateChanged:(NSNotification *)notification
{
    if (self.photoDatabase.documentState & UIDocumentStateInConflict) {
        // look at the changes in notification's userInfo and resolve conflicts
        //   or just take the latest version (by doing nothing)
        // in any case (even if you do nothing and take latest version),
        //   mark all old versions resolved ...
        NSArray *conflictingVersions = [NSFileVersion unresolvedConflictVersionsOfItemAtURL:self.photoDatabase.fileURL];
        for (NSFileVersion *version in conflictingVersions) {
            version.resolved = YES;
        }
        // ... and remove the old version files in a separate thread
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            NSFileCoordinator *coordinator = [[NSFileCoordinator alloc] initWithFilePresenter:nil];
            NSError *error;
            [coordinator coordinateWritingItemAtURL:self.photoDatabase.fileURL options:NSFileCoordinatorWritingForDeleting error:&error byAccessor:^(NSURL *newURL) {
                [NSFileVersion removeOtherVersionsOfItemAtURL:self.photoDatabase.fileURL error:NULL];
            }];
            if (error) NSLog(@"[%@ %@] %@ (%@)", NSStringFromClass([self class]), NSStringFromSelector(_cmd), error.localizedDescription, error.localizedFailureReason);
        });
    } else if (self.photoDatabase.documentState & UIDocumentStateSavingError) {
        // try again?
        // notify user?
    }
}

- (void)setPhotoDatabase:(UIManagedDocument *)photoDatabase
{
    if (_photoDatabase == photoDatabase) return;
    [[NSNotificationCenter defaultCenter] removeObserver:self 
                                                    name:NSPersistentStoreDidImportUbiquitousContentChangesNotification 
                                                  object:_photoDatabase.managedObjectContext.persistentStoreCoordinator];
    [[NSNotificationCenter defaultCenter] removeObserver:self 
                                                    name:UIDocumentStateChangedNotification 
                                                  object:_photoDatabase];
    _photoDatabase = photoDatabase;
    [self startSpinner:@"iCloud ..."];
    [[NSNotificationCenter defaultCenter] addObserver:self 
                                             selector:@selector(documentChanged:) 
                                                 name:NSPersistentStoreDidImportUbiquitousContentChangesNotification 
                                               object:_photoDatabase.managedObjectContext.persistentStoreCoordinator];    
    [[NSNotificationCenter defaultCenter] addObserver:self 
                                             selector:@selector(documentStateChanged:) 
                                                 name:UIDocumentStateChangedNotification 
                                               object:_photoDatabase];    
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

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self]; 
}

#pragma mark - Table view data source

- (UITableViewCell *)tableView:(UITableView *)tableView 
         cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"Photographer Cell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle 
                                             reuseIdentifier:CellIdentifier];
    
    [self stopSpinner];
    
    Photographer *photographer = [self.fetchedResultsController objectAtIndexPath:indexPath];
    cell.textLabel.text = photographer.name;
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%d photos", [photographer.photos count]];
    
    return cell;
}

-  (void)tableView:(UITableView *)tableView 
commitEditingStyle:(UITableViewCellEditingStyle)editingStyle 
 forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        if (!(self.photoDatabase.documentState & UIDocumentStateEditingDisabled)) {
            Photographer *photographer = [self.fetchedResultsController objectAtIndexPath:indexPath];
            [self.fetchedResultsController.managedObjectContext deleteObject:photographer];
            [self save];
        } else {
            // notifiy user
            // not allow us to get here
        }
    }
}

#pragma mark - Table view delegate

@end
