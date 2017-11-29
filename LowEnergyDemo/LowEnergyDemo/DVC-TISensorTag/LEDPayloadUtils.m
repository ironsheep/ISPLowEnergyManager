//
//  LEDPayloadUtils.m
//  LowEnergyDemo
//
//  Created by Stephen M Moraco on 04/17/13.
//  Copyright (c) 2013 Iron Sheep Productions, LLC. All rights reserved.
//

#import "LEDPayloadUtils.h"

@implementation LEDPayloadUtils

+(uint16_t)uint16ValueFromBytes:(uint8_t*)bytesAr
{
    uint16_t nValue = bytesAr[1];
    nValue <<= 8;
    nValue += bytesAr[0];
    return nValue;
}

+(int16_t)int16ValueFromBytes:(uint8_t*)bytesAr
{
    return (int16_t)[self uint16ValueFromBytes:bytesAr];
}

@end
