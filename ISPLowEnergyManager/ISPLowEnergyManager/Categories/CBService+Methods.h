//
//  CBService+Methods.h
//  ISPLowEnergyManager
//
//  Created by Stephen M Moraco on 03/15/13.
//  Copyright (c) 2013 Iron Sheep Productions, LLC. All rights reserved.
//

#import <CoreBluetooth/CoreBluetooth.h>
#import "CBUUID+Methods.h"

#pragma mark CATEGORY CBService(Methods) Interface

@interface CBService (Methods)


#pragma mark --> PUBLIC PROPERTIES

@property (assign, nonatomic, getter = isConfigured) BOOL configured;
@property (assign, nonatomic, getter = isSecondary) BOOL secondary;
@property (weak, nonatomic) CBService *containingService;


@end
