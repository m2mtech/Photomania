//
//  Photo+Flickr.h
//  Photomania
//
//  Created by Martin Mandl on 31.07.12.
//  Copyright (c) 2012 m2m. All rights reserved.
//

#import "Photo.h"

@interface Photo (Flickr)

+ (Photo *)photoWithFlickrInfo:(NSDictionary *)flickrInfo 
        inManagedObjectContext:(NSManagedObjectContext *)context;

@end
