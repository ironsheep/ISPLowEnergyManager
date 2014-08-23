//
//  LEPPeripheralTriadParameter.m
//  ISPLowEnergyManager
//
//  Created by Stephen M Moraco on 03/16/13.
//  Copyright (c) 2013 Iron Sheep Productions, LLC. All rights reserved.
//

#import "ISPPeripheralTriadParameter.h"

#pragma mark CLASS ISPPeripheralTriadParameter PRIVATE Interface

@interface ISPPeripheralTriadParameter () {

}

#pragma mark --> PRIVATE Properties

@property (strong, nonatomic) CBPeripheral *peripheral;
@property (strong, nonatomic) id parameter;
@property (strong, nonatomic) NSError *error;

//#pragma mark --> PRIVATE Interface-builder Outlet Properties

//#pragma mark --> PRIVATE Interface-builder Action Methods

//#pragma mark --> PRIVATE (Utility) Methods

@end


#pragma mark - CLASS ISPPeripheralTriadParameter Implemention

@implementation ISPPeripheralTriadParameter {

}

//#pragma mark --> PUBLIC Property Synthesis Overrides

//#pragma mark --> PRIVATE Property Synthesis Overrides

//#pragma mark --> CLASS (Static) Methods

#pragma mark --> PUBLIC Property Overrides

-(CBService *)service
{
    return self.parameter;
}

-(CBCharacteristic *)characteristic
{
    return self.parameter;
}

-(CBDescriptor *)descriptor
{
    return self.parameter;
}


#pragma mark --> PUBLIC Instance Methods

-(id)initWithPeripheral:(CBPeripheral *)peripheral parameter:(id)parameter error:(NSError *)error
{
    self = [super init];
    if(self)
    {
        self.peripheral = peripheral;
        self.parameter = parameter;
        self.error = error;
    }
    return self;
}

//#pragma mark --> Interface-builder Action Methods

//#pragma mark --> PRIVATE Property Overrides

//#pragma mark --> PRIVATE (Utility) Methods



@end
