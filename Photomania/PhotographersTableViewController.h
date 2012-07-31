//
//  PhotographersTableViewController.h
//  Photomania
//
//  Created by Martin Mandl on 31.07.12.
//  Copyright (c) 2012 m2m. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "CoreDataTableViewController.h"

@interface PhotographersTableViewController : CoreDataTableViewController

@property (nonatomic, strong) UIManagedDocument *photoDatabase;

@end
