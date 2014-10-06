//
//  LEMCBUUIDParameter.m
//  ISPLowEnergyManager
//
//  Created by Stephen M Moraco on 03/07/14.
//  Copyright (c) 2014 Iron Sheep Productions, LLC. All rights reserved.
//

#import "ISPCBUUIDParameter.h"


#pragma mark CLASS LEMCBUUIDParameter PRIVATE Interface

@interface ISPCBUUIDParameter () {

}

#pragma mark --> PRIVATE Properties
@property (strong, nonatomic, readwrite) NSString *UUIDString;
@property (strong, nonatomic, readwrite) NSString *UUIDFriendlyName;


//#pragma mark --> PRIVATE (Utility) Methods


@end


#pragma mark - CLASS LEMCBUUIDParameter Implemention

@implementation ISPCBUUIDParameter {

}

//#pragma mark --> PUBLIC Property Synthesis Overrides

//#pragma mark --> PRIVATE Property Synthesis Overrides

#pragma mark --> CLASS (Static) Methods
+ (id)parameterWithUUIDString:()UUIDString andUUIDFriendlyName:(NSString *)friendlyName
{
    ISPCBUUIDParameter *newInstance = [[ISPCBUUIDParameter alloc] initWithUUIDString:UUIDString andUUIDFriendlyName:friendlyName];
    return newInstance;
}

#pragma mark --> PUBLIC Property Overrides

- (NSString *)description
{
    NSString *strDescription = [NSString stringWithFormat:@"<%@ 0x%.8x> [UUID=(%@), FriendlyName=(%@)]",
                                NSStringFromClass([self class]),
                                (unsigned int)self,
                                self.UUIDString,
                                self.UUIDFriendlyName];
    return strDescription;
}

#pragma mark --> PUBLIC Instance Methods
- (id)initWithUUIDString:()UUIDString andUUIDFriendlyName:(NSString *)friendlyName
{
    self = [super init];
    if(self)
    {
        self.UUIDString = UUIDString;
        self.UUIDFriendlyName = friendlyName;
        DLog(@"- self=[%@]", self);
    }
    return self;
}

//#pragma mark --> Interface-builder Action Methods

//#pragma mark --> PRIVATE Property Overrides

//#pragma mark --> PRIVATE (Utility) Methods

@end
