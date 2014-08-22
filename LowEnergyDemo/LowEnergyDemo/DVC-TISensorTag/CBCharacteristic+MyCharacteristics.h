//
//  CBCharacteristic+MyCharacteristics.h
//  ISPLowEnergyManager
//
//  Created by Stephen M Moraco on 03/17/13.
//  Copyright (c) 2013 Iron Sheep Productions, LLC. All rights reserved.
//

#import <CoreBluetooth/CoreBluetooth.h>

@interface CBCharacteristic (MyCharacteristics)

@property (strong, nonatomic, readonly) NSString *friendlyName;

@end
