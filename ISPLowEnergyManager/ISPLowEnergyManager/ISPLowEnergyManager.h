//
//  ISPLowEnergyManager.h
//  ISPLowEnergyManager
//
//  Created by Stephen M Moraco on 08/22/14.
//  Copyright (c) 2014 Iron Sheep Productions, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol CBCentralManagerDelegate;
@protocol CBPeripheralDelegate;

@class CBService;
@class CBPeripheral;

@interface ISPLowEnergyManager : NSObject <CBCentralManagerDelegate, CBPeripheralDelegate> {
    
}

#pragma mark -- PUBLIC PROPERTIES

@property (strong, nonatomic) NSString *searchUUID;

#pragma mark -- CLASS METHODS

+ (id)sharedInstance;

// CLASS UTILITY Methods
// compose a Characteristic-Descriptor key
+(NSString *)keyForDescriptor:(CBDescriptor *)descriptor ofCharacteristic:(CBCharacteristic *)characteristic;

// break apart a Characteristic-Descriptor key
+(void)UUIDsForDescriptorKey:(NSString *)descriptorKey characteristicKeyPortion:(NSString **)characteristicUUIDString descriptorKeyPortion:(NSString **)descriptorUUIDString;
+(NSString *)characteristicUUIDStringForDescriptorKey:(NSString *)descriptorKey;
+(NSString *)descriptorUUIDStringForDescriptorKey:(NSString *)descriptorKey;

#pragma mark -- INSTANCE METHODS

// locate Bluetooth Devices
//  -- look for a single device (nil==all devices)
- (void)startScanningForUUIDString:(NSString *)uuidString;
//  -- look for two or more devices (nil==all devices)
- (void)startScanningForListOfUUIDs:(NSArray *)uuidList;

// stop looking for devices
- (void)stopScanning;

// connect to a specific device
- (void)connectPeripheral:(CBPeripheral*)peripheral;

// disconnect from the device
- (void)disconnectPeripheral:(CBPeripheral*)peripheral;

// locate all services, included services, service characteristics and characterstic-descriptors for a device
- (void)exploreConnectedPeripheralService:(CBService *)service;



@end
