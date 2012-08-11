//
//  DocumentTableViewController.m
//  Photomania
//
//  Created by Martin Mandl on 11.08.12.
//  Copyright (c) 2012 m2m. All rights reserved.
//

#import "DocumentTableViewController.h"
#import "AskerViewController.h"
#import <CoreData/CoreData.h>

@interface DocumentTableViewController () <AskerViewControllerDelegate>

@property (nonatomic, strong) NSArray *documents;
@property (nonatomic, strong) NSMetadataQuery *iCloudQuery;

@end

@implementation DocumentTableViewController

@synthesize documents = _documents;
@synthesize iCloudQuery = _iCloudQuery;

- (void)setDocuments:(NSArray *)documents
{
    if (documents == _documents) return;    
    documents = [documents sortedArrayUsingComparator:^NSComparisonResult(NSURL *url1, NSURL *url2) {
        return [[url1 lastPathComponent] caseInsensitiveCompare:[url2 lastPathComponent]];
    }];
    if ([_documents isEqualToArray:documents]) return;    
    _documents = documents;
    [self.tableView reloadData];
}

#pragma mark - iCloud Query

- (NSMetadataQuery *)iCloudQuery
{
    if (!_iCloudQuery) {
        _iCloudQuery = [[NSMetadataQuery alloc] init];
        _iCloudQuery.searchScopes = [NSArray arrayWithObject:NSMetadataQueryUbiquitousDocumentsScope];
        _iCloudQuery.predicate = [NSPredicate predicateWithFormat:@"%K like '*'", NSMetadataItemFSNameKey];
        [[NSNotificationCenter defaultCenter] addObserver:self 
                                                 selector:@selector(processCloutQueryResults:) 
                                                     name:NSMetadataQueryDidFinishGatheringNotification 
                                                   object:_iCloudQuery];
        [[NSNotificationCenter defaultCenter] addObserver:self 
                                                 selector:@selector(processCloutQueryResults:) 
                                                     name:NSMetadataQueryDidUpdateNotification 
                                                   object:_iCloudQuery];
        [[NSNotificationCenter defaultCenter] addObserver:self 
                                                 selector:@selector(ubiquitousKeyValueStoreUpdate:) 
                                                     name:NSUbiquitousKeyValueStoreDidChangeExternallyNotification 
                                                   object:[NSUbiquitousKeyValueStore defaultStore]];
    }
    return _iCloudQuery;
}

- (void)ubiquitousKeyValueStoreUpdate:(NSNotification *)notification
{
    [self.tableView reloadData];
}

- (NSURL *)iCloudURL
{
    return [[NSFileManager defaultManager] URLForUbiquityContainerIdentifier:nil];
}

- (NSURL *)iCloudDocumentsURL
{
    return [[self iCloudURL] URLByAppendingPathComponent:@"Documents"];
}

- (NSURL *)filePackageURLForCloudURL:(NSURL *)url {
    if ([[url path] hasPrefix:[[self iCloudDocumentsURL] path]]) {
        NSArray *iCloudDocumentsURLComponents = [[self iCloudDocumentsURL] pathComponents];
        NSArray *urlComponents = [url pathComponents];
        if ([iCloudDocumentsURLComponents count] < [urlComponents count]) {
            urlComponents = [urlComponents subarrayWithRange:NSMakeRange(0, [iCloudDocumentsURLComponents count] + 1)];
            url = [NSURL fileURLWithPathComponents:urlComponents];
        }
    }
    return url;
}

- (void)processCloutQueryResults:(NSNotification *)notification
{
    [self.iCloudQuery disableUpdates];
    NSMutableArray *documents = [NSMutableArray array];
    int resultCount = [self.iCloudQuery resultCount];
    for (int i = 0; i < resultCount; i++) {
        NSMetadataItem *item = [self.iCloudQuery resultAtIndex:i];
        NSURL *url = [item valueForAttribute:NSMetadataItemURLKey];
        url = [self filePackageURLForCloudURL:url];
        [documents addObject:url];
    }
    self.documents = documents;    
    [self.iCloudQuery enableUpdates];
}

#pragma mark - View Controller Lifecycle

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self.tableView reloadData];
    if (![self.iCloudQuery isStarted]) [self.iCloudQuery startQuery];
    [self.iCloudQuery enableUpdates];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return YES;
}

- (void)viewWillDisappear:(BOOL)animated
{
    [self.iCloudQuery disableUpdates];
    [super viewWillDisappear:animated];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Table view data source

- (NSInteger)tableView:(UITableView *)tableView 
 numberOfRowsInSection:(NSInteger)section
{
    return [self.documents count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView 
         cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"Document Cell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    
    NSURL *url = [self.documents objectAtIndex:indexPath.row];
    cell.textLabel.text = [url lastPathComponent];
    cell.detailTextLabel.text = [[NSUbiquitousKeyValueStore defaultStore] 
                                 objectForKey:[url lastPathComponent]];
    
    return cell;
}


-  (void)tableView:(UITableView *)tableView 
commitEditingStyle:(UITableViewCellEditingStyle)editingStyle 
 forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        NSURL *url = [self.documents objectAtIndex:indexPath.row];
        NSMutableArray *documents = [self.documents mutableCopy];
        [documents removeObject:url];
        _documents = documents; // setter is not called because of method below        
        [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] 
                         withRowAnimation:UITableViewRowAnimationFade];
        [self removeCloudURL:url];
    }   
}


#pragma mark - Segue

- (NSURL *)iCloudCoreDataLogFilesURL
{
    return [[self iCloudURL] URLByAppendingPathComponent:@"CoreData"];
}

- (void)setPersistentStoreOptionsInDocument:(UIManagedDocument *)document
{
    NSMutableDictionary *options = [NSMutableDictionary dictionary];
    [options setObject:[NSNumber numberWithBool:YES] forKey:NSMigratePersistentStoresAutomaticallyOption];
    [options setObject:[NSNumber numberWithBool:YES] forKey:NSInferMappingModelAutomaticallyOption];
    
    NSString *name = [document.fileURL lastPathComponent];
    [options setObject:name forKey:NSPersistentStoreUbiquitousContentNameKey];
    NSURL *logsURL = [self iCloudCoreDataLogFilesURL];
    [options setObject:logsURL forKey:NSPersistentStoreUbiquitousContentURLKey];
    // if file exists use contens of document.fileURL/@"DocumentMetadata.plist" instead
    
    document.persistentStoreOptions = options;
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([segue.identifier isEqualToString:@"Add Document"]) {
        AskerViewController *asker = (AskerViewController *)segue.destinationViewController;
        asker.question = @"New document name:";
        asker.delegate = self;
    } else {
        NSIndexPath *indexPath;
        if ([sender isKindOfClass:[NSIndexPath class]]) {
            indexPath = (NSIndexPath *)sender;
        } else if ([sender isKindOfClass:[UITableViewCell class]]) {
            indexPath = [self.tableView indexPathForCell:sender];
        } else if (!sender || (sender == self) || (sender == self.tableView)) {
            indexPath = [self.tableView indexPathForSelectedRow];
        }
        
        if (indexPath && [segue.identifier isEqualToString:@"Show Document"]) {
            if ([segue.destinationViewController conformsToProtocol:@protocol(DocumentTableViewControllerSegue)]) {
                NSURL *url = [self.documents objectAtIndex:indexPath.row];
                [segue.destinationViewController setTitle:[url lastPathComponent]];
                UIManagedDocument *document = [[UIManagedDocument alloc] initWithFileURL:url];            
                [self setPersistentStoreOptionsInDocument:document];
                [segue.destinationViewController setDocument:document];
            }
        }        
    }
}

- (void)askerViewController:(AskerViewController *)sender 
             didAskQuestion:(NSString *)question 
               andGotAnswer:(NSString *)answer
{
    NSURL *url = [[self iCloudDocumentsURL] URLByAppendingPathComponent:answer];
    NSMutableArray *documents = [self.documents mutableCopy];
    [documents addObject:url];
    self.documents = documents;
    int row = [self.documents indexOfObject:url];
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:row inSection:0];
    [self performSegueWithIdentifier:@"Show Document" sender:indexPath];
    [self dismissModalViewControllerAnimated:YES];
}


- (void)logError:(NSError *)error inMethod:(SEL)method
{
    NSString *errorDescription = error.localizedDescription;
    if (!errorDescription) errorDescription = @"???";
    NSString *errorFailureReason = error.localizedFailureReason;
    if (!errorFailureReason) errorFailureReason = @"???";
    if (error) NSLog(@"[%@ %@] %@ (%@)", NSStringFromClass([self class]), NSStringFromSelector(method), errorDescription, errorFailureReason);
}

- (void)removeCloudURL:(NSURL *)url
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSFileCoordinator *coordinator = [[NSFileCoordinator alloc] initWithFilePresenter:nil];
        NSError *coordinationError;
        [coordinator coordinateWritingItemAtURL:url options:NSFileCoordinatorWritingForDeleting error:&coordinationError byAccessor:^(NSURL *newURL) {
            NSError *removeError;
            [[[NSFileManager alloc] init] removeItemAtURL:newURL error:&removeError];
            [self logError:removeError inMethod:_cmd];
            // remove the CoreData log files
        }]; 
        [self logError:coordinationError inMethod:_cmd];
    });    
}



@end
