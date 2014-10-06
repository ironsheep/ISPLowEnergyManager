//
//  LEDViewControllerBase.m
//  LowEnergyDemo
//
//  Created by Stephen M Moraco on 10/03/14.
//  Copyright (c) 2014 Iron Sheep Productions, LLC. All rights reserved.
//

#import "LEDViewControllerBase.h"

#pragma mark CLASS LEDViewControllerBase PRIVATE Interface

@interface LEDViewControllerBase () {

}

//#pragma mark --> PRIVATE Properties

//#pragma mark --> PRIVATE Interface-builder Outlet Properties

//#pragma mark --> PRIVATE Interface-builder Action Methods

//#pragma mark --> PRIVATE (Utility) Methods

@end


#pragma mark - CLASS LEDViewControllerBase Implemention

@implementation LEDViewControllerBase {

}

//#pragma mark --> PUBLIC Property Synthesis Overrides

//#pragma mark --> PRIVATE Property Synthesis Overrides

//#pragma mark --> CLASS (Static) Methods

//#pragma mark --> PUBLIC Property Overrides

#pragma mark --> PUBLIC Instance Methods

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self) {
        // Custom initialization
        DLog(@"");
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.appDelegate = (LEDAppDelegate *)[[UIApplication sharedApplication] delegate];

    self.sensorTag = [LEDTISensorTag sharedInstance];
}

-(void)viewWillAppear:(BOOL)animated
{
    DLog(@"");
    [super viewWillAppear:animated];

    // register notification handlers
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(valueUpdated:) name:kCHARACTERISTIC_VALUE_UPDATED object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(deviceReady:) name:kDEVICE_IS_READY_FOR_ACCESS object:nil];

    // NOTE: this done by derived class (which becomes more readable by doing so)
    //    if(self.ledPanel.isDeviceReady)
    //    {
    //        // telling ourself that panel is ready for access!
    //        [self deviceReady:nil];
    //    }
}

-(void)viewWillDisappear:(BOOL)animated
{
    DLog(@"");
    [super viewWillDisappear:animated];

    // unregister notification handlers
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kCHARACTERISTIC_VALUE_UPDATED object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kDEVICE_IS_READY_FOR_ACCESS object:nil];

    // NOTE: this done by derived class (which becomes more readable by doing so)
    //    [self.ledPanel removeBlocksForViewController:self];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


#pragma mark -- NSNotificationCenter Callback Methods

- (void)deviceReady:(NSNotification *)notification
{
    // NOTE: override this in derived class to handle this event!
    DLog(@"");
}

- (void)valueUpdated:(NSNotification *)notification
{
    // NOTE: override this in derived class to handle this event!
    DLog(@"");
}


@end
