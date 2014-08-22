//
//  CBService+Methods.h
//  ISPLowEnergyManager
//
//  Created by Stephen M Moraco on 03/15/13.
//  Copyright (c) 2013 Iron Sheep Productions, LLC. All rights reserved.
//

#import <CoreBluetooth/CoreBluetooth.h>
#import "CBUUID+Methods.h"

@interface CBService (Methods)

@property (assign, nonatomic, getter = isConfigured) BOOL configured;
@property (assign, nonatomic, getter = isSecondary) BOOL secondary;
@property (weak, nonatomic) CBService *containingService;


@end
