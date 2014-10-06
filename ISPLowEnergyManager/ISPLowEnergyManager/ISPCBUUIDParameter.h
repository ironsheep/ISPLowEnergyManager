//
//  LEMCBUUIDParameter.h
//  ISPLowEnergyManager
//
//  Created by Stephen M Moraco on 03/07/14.
//  Copyright (c) 2014 Iron Sheep Productions, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>


//#pragma mark PROTOCOL Forward Declarations


#pragma mark CLASS LEMCBUUIDParameter PUBLIC Interface

@interface ISPCBUUIDParameter : NSObject {

}

#pragma mark --> PUBLIC Properties
@property (strong, nonatomic, readonly) NSString *UUIDString;
@property (strong, nonatomic, readonly) NSString *UUIDFriendlyName;

//#pragma mark --> Interface-builder Outlet Properties

#pragma mark --> CLASS (Static) Methods
+ (id)parameterWithUUIDString:()UUIDString andUUIDFriendlyName:(NSString *)friendlyName;

#pragma mark --> PUBLIC Instance Methods
- (id)initWithUUIDString:()UUIDString andUUIDFriendlyName:(NSString *)friendlyName;

//#pragma mark --> Interface-builder Action Methods

@end
