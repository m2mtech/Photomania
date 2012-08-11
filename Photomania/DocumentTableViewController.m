//
//  DocumentTableViewController.m
//  Photomania
//
//  Created by Martin Mandl on 11.08.12.
//  Copyright (c) 2012 m2m. All rights reserved.
//

#import "DocumentTableViewController.h"

@interface DocumentTableViewController ()

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
    }
    return _iCloudQuery;
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

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
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

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [self.documents count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"Document Cell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    
    NSURL *url = [self.documents objectAtIndex:indexPath.row];
    cell.textLabel.text = [url lastPathComponent];
    
    return cell;
}

/*
// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // Delete the row from the data source
        [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationFade];
    }   
    else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
    }   
}
*/

@end
