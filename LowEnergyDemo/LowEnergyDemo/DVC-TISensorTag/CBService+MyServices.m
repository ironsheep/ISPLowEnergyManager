//
//  CBService+MyServices.m
//  ISPLowEnergyManager
//
//  Created by Stephen M Moraco on 03/16/13.
//  Copyright (c) 2013 Iron Sheep Productions, LLC. All rights reserved.
//

#import <ISPLowEnergyManager/CBService+Methods.h>

#import "CBService+MyServices.h"
#import "LEDGattConsts.h"

@implementation CBService (MyServices)

-(NSString *)friendlyName
{
    static NSDictionary *s_dctServiceNames = nil;

    if(s_dctServiceNames == nil) {
        s_dctServiceNames = [NSDictionary dictionaryWithObjects:
                             [NSArray arrayWithObjects:
                              @"Generic Access Service <1800>",
                              @"GATT Service <1801>",
                              @"Device Information Service <180A>",
                              @"IR Temperature Service <F000AA00*>",
                              @"Accelerometer Service  <F000AA10*>",
                              @"Humidity Service  <F000AA20*>",
                              @"Magnetometer Service  <F000AA30*>",
                              @"Barometer Service  <F000AA40*>",
                              @"Gyroscope Service  <F000AA50*>",
                              @"SK Keypressed Service  <FFE0>",
                              @"TEST Service <F000AA60*>",
                              @"??? Service <F000FFC0*>",
                              nil]
                                                        forKeys:
                             [NSArray arrayWithObjects:
                              kGENERIC_ACCESS_SVC,
                              kGATT_SVC,
                              kDEVICE_INFORMATION_SVC,
                              kIR_TEMPERATURE_SVC,
                              kACCELEROMETER_SVC,
                              kHUMIDITY_SVC,
                              kMAGNETOMETER_SVC,
                              kBAROMETER_SVC,
                              kGYROSCOPE_SVC,
                              kSK_KEYPRESSED_SVC,
                              kTEST_SVC,
                              kUNKNOWN_SVC,
                              nil]
                             ];
    }
    NSString *strFriendlyName = [s_dctServiceNames valueForKey:self.UUID.UUIDString];
    if(strFriendlyName == nil)
    {
        strFriendlyName = self.UUID.UUIDString;
    }
    return strFriendlyName;
}

@end


