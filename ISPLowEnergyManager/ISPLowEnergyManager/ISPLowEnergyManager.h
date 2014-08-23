//
//  ISPLowEnergyManager.h
//  ISPLowEnergyManager
//
//  Created by Stephen M Moraco on 03/12/13.
//  Copyright (c) 2013 Iron Sheep Productions, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>

//#pragma mark PROTOCOL Forward Declarations

#pragma mark CLASS ISPLowEnergyManager - PUBLIC Interface

@interface ISPLowEnergyManager : NSObject <CBCentralManagerDelegate, CBPeripheralDelegate> {
    
}

#pragma mark --> PUBLIC PROPERTIES

@property (strong, nonatomic) NSString *searchUUID;
@property (assign, nonatomic) NSTimeInterval searchDurationInSeconds;
@property (assign, nonatomic) NSUInteger numberOfDevicesToLocate;
@property (strong, nonatomic, readonly) NSArray *peripherals;


#pragma mark --> CLASS (Static) Methods

+ (id)sharedInstance;


#pragma mark --> INSTANCE METHODS

- (void)enableScanningWhenReady;
- (void)startScanningForUUIDString:(NSString *)uuidString;
- (void)stopScanning;

- (void)connectPeripheral:(CBPeripheral*)peripheral;
- (void)disconnectPeripheral:(CBPeripheral*)peripheral;

- (void)exploreConnectedPeripheralService:(CBService *)service;

- (NSNumber *)rssiForPeripheral:(CBPeripheral*)peripheral;

@end

