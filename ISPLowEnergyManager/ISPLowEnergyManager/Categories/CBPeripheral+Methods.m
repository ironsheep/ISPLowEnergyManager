//
//  CBPeripheral+Methods.m
//  ISPLowEnergyManager
//
//  Created by Stephen M Moraco on 03/15/13.
//  Copyright (c) 2013 Iron Sheep Productions, LLC. All rights reserved.
//

#import "CBPeripheral+Methods.h"
#import "objc/runtime.h"

#pragma mark - CATEGORY CBPeripheral(Methods) Implementation

@implementation CBPeripheral (Methods)

#pragma mark -- Property Setters/Getters

// See: http://ddeville.me/2011/03/add-variables-to-an-existing-class-in-objective-c/
static char latestRSSIKey;

-(void)setLatestRSSI:(NSNumber *)latestRSSI
{
    objc_setAssociatedObject(self, &latestRSSIKey, latestRSSI, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

-(NSNumber *)latestRSSI
{
    return objc_getAssociatedObject(self, &latestRSSIKey) ;
}

-(NSString *)UUIDstr
{
    // from  http://ios-dev-blog.com/generate-unique-identifier/#more-369

//    NSString *strUUID = CFBridgingRelease(CFUUIDCreateString(NULL, self.UUID));
//    return strUUID;
//	CFStringRef string = CFUUIDCreateString(NULL, self.UUID);
//	return (NSString *)CFBridgingRelease(string);
//    NSString    *uuid = (__bridge_transfer  NSString *)CFUUIDCreateString(kCFAllocatorDefault, self.UUID);
//    return uuid;
#if TARGET_IPHONE_SIMULATOR

    // CRAP This DOES NOT crash on the SIMULATOR!!!
    return [NSString stringWithFormat:@"0001-SIMULATOR-1000"];;

#else
    // CRAP This crashes on the SIMULATOR!!!
	CFStringRef string = CFUUIDCreateString(NULL, self.UUID);
	return (NSString *)CFBridgingRelease(string);

#endif

    // TEST TEST
//    NSString *  result;
//	CFUUIDRef   uuid;
//	CFStringRef uuidStr;
//	//uuid = CFUUIDCreate(NULL);
//    uuid = self.UUID;
//	NSAssert(uuid != NULL, @"UUIDRef is NULL");
//	uuidStr = CFUUIDCreateString(NULL, uuid);
//	NSAssert(uuidStr != NULL, @"uuidStr is NULL");
//	result = [NSString stringWithFormat:@"%@", uuidStr];
//	NSAssert(result != nil, @"NSString is nil");
//	NSLog(@"UNIQUE ID %@", result);
//	CFRelease(uuidStr);
//	CFRelease(uuid);
//	return result;

}

-(NSString *)title
{
    NSString *strYN = (self.isConnected) ? @"YES": @"no";
    NSString *strTitle = [NSString stringWithFormat:@"%@:\n %@\n IsConnected=%@", self.name, self.UUIDstr, strYN];
    return strTitle;
}

@end
