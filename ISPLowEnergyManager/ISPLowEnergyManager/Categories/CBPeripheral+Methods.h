//
//  CBPeripheral+Methods.h
//  ISPLowEnergyManager
//
//  Created by Stephen M Moraco on 03/15/13.
//  Copyright (c) 2013 Iron Sheep Productions, LLC. All rights reserved.
//

#import <CoreBluetooth/CoreBluetooth.h>

#pragma mark CATEGORY CBPeripheral(Methods) Interface

@interface CBPeripheral (Methods)


#pragma mark --> PUBLIC PROPERTIES

@property (strong, nonatomic) NSNumber *latestRSSI;

@property (weak, nonatomic, readonly) NSString *UUIDstr;
@property (weak, nonatomic, readonly) NSString *title;

@end
