//
//  ISPLowEnergyManager.h
//  ISPLowEnergyManager
//
//  Created by Stephen M Moraco on 03/12/13.
//  Copyright (c) 2013 Iron Sheep Productions, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>
#import "ISPPeripheralTriadParameter.h"
#import "ISPNotificationConsts.h"

#pragma mark CLASS LEPBluetoothManager - PUBLIC Interface

@interface ISPLowEnergyManager : NSObject <CBCentralManagerDelegate, CBPeripheralDelegate> {

}

#pragma mark -- PUBLIC PROPERTIES

@property (strong, nonatomic) NSDictionary *serviceCharacteristics;
@property (strong, nonatomic) NSArray *servicesWithIncludes;
@property (strong, nonatomic) NSString *searchUUID;
@property (strong, nonatomic) NSString *searchDeviceName;
@property (strong, nonatomic) NSString *alternateSearchDeviceName;
@property (assign, nonatomic) NSTimeInterval searchDurationInSeconds;
@property (assign, nonatomic) NSUInteger numberOfDevicesToLocate;
@property (strong, nonatomic, readonly) NSArray *peripherals;
@property (assign, nonatomic, getter=isDeviceScanEnabled) BOOL deviceScanEnable;
@property (assign, nonatomic, getter=isServicesDiscoveryEnabled) BOOL servicesDiscoveryEnable;
@property (strong, nonatomic) NSNumber *connectedPeripheralRssi;

#pragma mark -- CLASS METHODS

+ (id)sharedInstance;


#pragma mark -- INSTANCE METHODS

- (void)startScanningForUUIDString:(NSString *)uuidString;
- (void)stopScanning;

- (void)rescanForPeripherals;

- (void)connectPeripheral:(CBPeripheral*)peripheral;
- (void)disconnectPeripheral:(CBPeripheral*)peripheral;


- (NSNumber *)rssiForPeripheral:(CBPeripheral*)peripheral;

//- (void)readValueForCharacteristic:(CBCharacteristic *)characteristic;
//- (void)writeValue:(NSData *)data forCharacteristic:(CBCharacteristic *)characteristic type:(CBCharacteristicWriteType)type;

- (void)readValueForCharacteristicUUID:(NSString *)characteristicUUID;
- (void)setNotifyValue:(BOOL)bNotify forCharacteristicUUID:(NSString *)UUIDString;
- (void)writeValue:(NSData *)data forCharacteristicUUID:(NSString *)characteristicUUID type:(CBCharacteristicWriteType)type;
@end

