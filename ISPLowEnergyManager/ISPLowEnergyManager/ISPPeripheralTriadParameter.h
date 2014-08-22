//
//  ISPPeripheralTriadParameter.h
//  ISPLowEnergyManager
//
//  Created by Stephen M Moraco on 03/16/13.
//  Copyright (c) 2013 Iron Sheep Productions, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "CBUUID+Methods.h"  // so clients can use the UUID stuff

@interface ISPPeripheralTriadParameter : NSObject {

}

// the triad
@property (strong, nonatomic, readonly) CBPeripheral *peripheral;
@property (strong, nonatomic, readonly) NSError *error;

// typed aliases for "parameter" property
@property (strong, nonatomic, readonly) CBService *service;
@property (strong, nonatomic, readonly) CBCharacteristic *characteristic;
@property (strong, nonatomic, readonly) CBDescriptor *descriptor;

-(id)initWithPeripheral:(CBPeripheral *)peripheral parameter:(id)parameter error:(NSError *)error;

@end
