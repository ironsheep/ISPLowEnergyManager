//
//  LEDPayloadUtils.h
//  LowEnergyDemo
//
//  Created by Stephen M Moraco on 04/17/13.
//  Copyright (c) 2013 Iron Sheep Productions, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface LEDPayloadUtils : NSObject

+(uint16_t)uint16ValueFromBytes:(uint8_t *)bytesAr;

@end
