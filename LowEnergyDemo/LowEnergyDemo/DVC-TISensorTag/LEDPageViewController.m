//
//  LEDPageViewController.m
//  LowEnergyDemo
//
//  Created by Stephen M Moraco on 04/17/13.
//  Copyright (c) 2013 Iron Sheep Productions, LLC. All rights reserved.
//

#import "LEDPageViewController.h"

@interface LEDPageViewController () {

}

@end


@implementation LEDPageViewController {
    
}

- (UIViewController *)pageViewController:(UIPageViewController *)pageViewController viewControllerBeforeViewController:(UIViewController *)viewController
{
    return nil;
}

- (UIViewController *)pageViewController:(UIPageViewController *)pageViewController viewControllerAfterViewController:(UIViewController *)viewController
{
    return nil;
}

- (NSInteger)presentationCountForPageViewController:(UIPageViewController *)pageViewController
{
    // The number of items reflected in the page indicator.
    return 3;
}
- (NSInteger)presentationIndexForPageViewController:(UIPageViewController *)pageViewController
{
    // The selected item reflected in the page indicator.
    return 0;
}

@end
