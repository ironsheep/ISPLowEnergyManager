//
//  CBUUID+Methods.m
//  ISPLowEnergyManager
//
//  Created by Stephen M Moraco on 03/17/13.
//  Copyright (c) 2013 Iron Sheep Productions, LLC. All rights reserved.
//

#import "CBUUID+Methods.h"

@implementation CBUUID (Methods)

-(NSString *)UUIDString
{
    // from  http://stackoverflow.com/questions/13275859/how-to-turn-cbuuid-into-string

    if ([self.data length] == 2)
    {
        const unsigned char *tokenBytes = [self.data bytes];
        return [NSString stringWithFormat:@"%02X%02X", tokenBytes[0], tokenBytes[1]];
    }
    else
    {
        NSAssert([self.data length] == 16, @"CBUUID that is NOT 2 or 16 bytes long!??!!!??");
        NSUUID* nsuuid = [[NSUUID alloc] initWithUUIDBytes:[self.data bytes]];
        return [nsuuid UUIDString];
    }
}

- (NSString *)description
{
    NSString *strDescription = [NSString stringWithFormat:@"<%@ 0x%.8x> [UUID=(0x%@)]",
                                NSStringFromClass([self class]),
                                (unsigned int)self,
                                self.UUIDString];
    return strDescription;
}


@end
