//
//  LEDDevicePicker.h
//  LowEnergyDemo
//
//  Created by Stephen M Moraco on 10/03/14.
//  Copyright (c) 2014 Iron Sheep Productions, LLC. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol LEDDevicePickerDelegate;

@interface LEDDevicePicker : UITableViewController {

}
@property (weak, nonatomic) NSArray *foundDevices;
@property (weak, nonatomic) id<LEDDevicePickerDelegate> delegate;

@end


@protocol LEDDevicePickerDelegate <NSObject>

- (void)chooser:(UITableViewController *)chooser didCancel:(BOOL)didCancel;
- (void)chooser:(UITableViewController *)chooser selectedDeviceIndex:(NSUInteger)index;

@end
