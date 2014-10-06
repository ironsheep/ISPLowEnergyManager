//
//  LEDViewControllerBase.h
//  LowEnergyDemo
//
//  Created by Stephen M Moraco on 10/03/14.
//  Copyright (c) 2014 Iron Sheep Productions, LLC. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "LEDAppDelegate.h"
#import "MBProgressHUD.h"
#import "LEDTISensorTag.h"

@interface LEDViewControllerBase : UIViewController {

}

#pragma mark --> PUBLIC Properties

@property (weak, nonatomic) LEDAppDelegate *appDelegate;
@property (strong, nonatomic) MBProgressHUD *progressHUD;

@property (weak, nonatomic) LEDTISensorTag *sensorTag;


//#pragma mark --> Interface-builder Outlet Properties

//#pragma mark --> CLASS (Static) Methods

#pragma mark --> PUBLIC Instance Methods

- (void)deviceReady:(NSNotification *)notification;
- (void)valueUpdated:(NSNotification *)notification;

//#pragma mark --> Interface-builder Action Methods

@end
