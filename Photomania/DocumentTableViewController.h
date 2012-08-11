//
//  DocumentTableViewController.h
//  Photomania
//
//  Created by Martin Mandl on 11.08.12.
//  Copyright (c) 2012 m2m. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol DocumentTableViewControllerSegue <NSObject>

@property (nonatomic, strong) UIManagedDocument *document;

@end

@interface DocumentTableViewController : UITableViewController

@end
