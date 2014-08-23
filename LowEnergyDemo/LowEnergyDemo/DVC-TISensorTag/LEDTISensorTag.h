//
//  LEDTISensorTag.h
//  LowEnergyDemo
//
//    This is the interface to the singleton that represents the state of the Physical
//    TI Sensor tag as well as marshals all communication to/from
//
//  Created by Stephen M Moraco on 04/04/13.
//  Copyright (c) 2013 Iron Sheep Productions, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

#pragma mark CLASS LEDTISensorTag - PUBLIC Interface

@interface LEDTISensorTag : NSObject {
  @protected
}

// Declare block function
typedef void (^LEDCharacteristicValueUpdatedBlock)(NSString *);

extern NSString *kDEVICE_IS_READY_FOR_ACCESS;
extern NSString *kDEVICE_IS_NO_LONGER_READY;
extern NSString *kCHARACTERISTIC_VALUE_UPDATED;
extern NSString *kPERIPHERAL_SCAN_ENDED_NOTIFICATION;

#pragma mark --> PUBLIC PROPERTIES
@property (assign, nonatomic, readonly, getter=isDeviceReady) BOOL deviceReady;

#pragma mark ---> (Generic Access Service PROPERTIES)

@property (strong, nonatomic, readonly) NSString *deviceName;
@property (strong, nonatomic, readonly) NSString *modelNumber;

#pragma mark ---> (TISensorTag Properties PROPERTIES)
//   -------------------------------------
//   ----   TISensorTag Properties    ----
//   -------------------------------------
// Temp Service
@property (assign, nonatomic, readonly) double objectTemp;
@property (assign, nonatomic, readonly) double ambientTemp;
@property (assign, nonatomic, getter = isTempEnabled) BOOL tempEnable;
@property (assign, nonatomic, getter = isTempNotifying) BOOL tempNotify;

// Humidity Service
@property (assign, nonatomic, readonly) double tempInC;  // temp DegrC
@property (assign, nonatomic, readonly) double relHumidityPercent;  // RH%
@property (assign, nonatomic, getter = isHumidityEnabled) BOOL humidityEnable;
@property (assign, nonatomic, getter = isHumidityNotifying) BOOL humidityNotify;

// Barometric Pressure Service
@property (assign, nonatomic, readonly) double baroTempInC;  // temp DegrC
@property (assign, nonatomic, readonly) double baroPressure;  //
@property (assign, nonatomic, getter = isBarometerEnabled) BOOL barometerEnable;
@property (assign, nonatomic, getter = isBarometerCalibrated) BOOL barometerCalibrate;
@property (assign, nonatomic, getter = isBarometerNotifying) BOOL barometerNotify;

// Accelerometer Service
@property (assign, nonatomic, readonly) float accelerometerX;   // +/- G [-2.0 to +2.0]
@property (assign, nonatomic, readonly) float accelerometerY;  
@property (assign, nonatomic, readonly) float accelerometerZ;
@property (assign, nonatomic) uint8_t accelerometerPeriod;  // (n*10) mSec [10 to 255] (0-9 cause error!)
@property (assign, nonatomic, getter = isAccelerometerEnabled) BOOL accelerometerEnable;
@property (assign, nonatomic, getter = isAccelerometerNotifying) BOOL accelerometerNotify;

// Gyroscope Service
@property (assign, nonatomic, readonly) float gyroscopeX;   // Degr/Sec [-250.0 to +250.0]
@property (assign, nonatomic, readonly) float gyroscopeY;  
@property (assign, nonatomic, readonly) float gyroscopeZ;  
@property (assign, nonatomic, getter = isGyroscopeEnabled) BOOL gyroscopeEnable;
@property (assign, nonatomic, getter = isGyroscopeNotifying) BOOL gyroscopeNotify;

// Magnetometer Service
@property (assign, nonatomic, readonly) float magnetometerX;  // +/- magnetic force in uTera [-1000.0 to +1000.0]
@property (assign, nonatomic, readonly) float magnetometerY;   
@property (assign, nonatomic, readonly) float magnetometerZ;   
@property (assign, nonatomic) uint8_t magnetometerPeriod;  // (n) mSec
@property (assign, nonatomic, getter = isMagnetometerEnabled) BOOL magnetometerEnable;
@property (assign, nonatomic, getter = isMagnetometerNotifying) BOOL magnetometerNotify;

#pragma mark --> CLASS (Static) METHODS

+ (id)sharedInstance;

// common conversions
+(double)fahrenheitForTempInCentigrade:(double)tempInC;

#pragma mark --> PUBLIC Instance METHODS

// form expecting Notification Center notify of operation complete
-(void)readCharacteristicUUIDString:(NSString *)UUIDString;

// form when using blocks for completion handling
-(void)readCharacteristicUUIDString:(NSString *)UUIDString completion:(LEDCharacteristicValueUpdatedBlock)callback;


@end
