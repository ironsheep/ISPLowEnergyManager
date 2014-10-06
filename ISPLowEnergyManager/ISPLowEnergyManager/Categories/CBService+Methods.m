//
//  CBService+Methods.m
//  ISPLowEnergyManager
//
//  Created by Stephen M Moraco on 03/15/13.
//  Copyright (c) 2013 Iron Sheep Productions, LLC. All rights reserved.
//

#import "CBService+Methods.h"
#import "objc/runtime.h"

@implementation CBService (Methods)

#pragma mark -- Property Setters/Getters


// See: http://ddeville.me/2011/03/add-variables-to-an-existing-class-in-objective-c/

static char containingServiceKey;

-(void)setContainingService:(CBService *)containingService
{
    objc_setAssociatedObject(self, &containingServiceKey, containingService, OBJC_ASSOCIATION_ASSIGN);
}

-(CBService *)containingService
{
    return objc_getAssociatedObject(self, &containingServiceKey) ;
}



static char secondaryKey;

-(void)setSecondary:(BOOL)secondary
{
    NSNumber *nbrSecondary = [NSNumber numberWithBool:secondary];
    objc_setAssociatedObject(self, &secondaryKey, nbrSecondary, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

-(BOOL)isSecondary
{
    BOOL bIsSecondaryStatus = NO;
    NSNumber *nbrSecondary = objc_getAssociatedObject(self, &secondaryKey);
    if(nbrSecondary != nil)
    {
        bIsSecondaryStatus = [nbrSecondary boolValue];
    }
    return bIsSecondaryStatus;
}



static char configuredKey;

-(void)setConfigured:(BOOL)configured
{
    NSNumber *nbrConfigured = [NSNumber numberWithBool:configured];
    objc_setAssociatedObject(self, &configuredKey, nbrConfigured, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

-(BOOL)isConfigured
{
    BOOL bIsConfiguredStatus = NO;
    NSNumber *nbrConfigured = objc_getAssociatedObject(self, &configuredKey) ;
    if(nbrConfigured != nil)
    {
        bIsConfiguredStatus = [nbrConfigured boolValue];
    }
    return bIsConfiguredStatus;
}


- (NSString *)description
{
    NSString *strDescription = [NSString stringWithFormat:@"<%@ 0x%.8x> [UUID=(0x%@)]",
                                NSStringFromClass([self class]),
                                (unsigned int)self,
                                self.UUID.UUIDString];
    return strDescription;
}


@end
