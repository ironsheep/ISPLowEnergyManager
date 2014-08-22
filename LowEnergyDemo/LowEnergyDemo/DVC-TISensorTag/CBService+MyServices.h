//
//  CBService+MyServices.h
//  ISPLowEnergyManager
//
//  Created by Stephen M Moraco on 03/16/13.
//  Copyright (c) 2013 Iron Sheep Productions, LLC. All rights reserved.
//

#import <CoreBluetooth/CoreBluetooth.h>

@interface CBService (MyServices)

@property (strong, nonatomic, readonly) NSString *friendlyName;

@end
