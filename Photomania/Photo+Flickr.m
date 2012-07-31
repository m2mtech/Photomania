//
//  Photo+Flickr.m
//  Photomania
//
//  Created by Martin Mandl on 31.07.12.
//  Copyright (c) 2012 m2m. All rights reserved.
//

#import "Photo+Flickr.h"
#import "Photographer+Create.h"
#import "FlickrFetcher.h"

@implementation Photo (Flickr)

+ (Photo *)photoWithFlickrInfo:(NSDictionary *)flickrInfo 
        inManagedObjectContext:(NSManagedObjectContext *)context
{
    Photo *photo;
    
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"Photo"];
    request.predicate = [NSPredicate predicateWithFormat:@"unique = %@", 
                         [flickrInfo objectForKey:FLICKR_PHOTO_ID]];
    NSSortDescriptor *sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"title" 
                                                                     ascending:YES];
    request.sortDescriptors = [NSArray arrayWithObject:sortDescriptor];
    NSError *error;
    NSArray *matches = [context executeFetchRequest:request error:&error];
    
    if (!matches || ([matches count] > 1)) {
        // handle error
    } else if (![matches count]) {
        photo = [NSEntityDescription insertNewObjectForEntityForName:@"Photo" 
                                              inManagedObjectContext:context];
        photo.title = [flickrInfo objectForKey:FLICKR_PHOTO_TITLE];        
        photo.subtitle = [flickrInfo valueForKeyPath:FLICKR_PHOTO_DESCRIPTION];        
        photo.imageUrl = [[FlickrFetcher urlForPhoto:flickrInfo 
                                              format:FlickrPhotoFormatLarge] absoluteString];        
        photo.whoTook = [Photographer photographerWithName:[flickrInfo objectForKey:FLICKR_PHOTO_OWNER] 
                                    inManagedObjectContext:context];
        photo.unique = [flickrInfo objectForKey:FLICKR_PHOTO_ID];
    } else {
        photo = [matches lastObject];
    }
    return photo;    
}

@end
