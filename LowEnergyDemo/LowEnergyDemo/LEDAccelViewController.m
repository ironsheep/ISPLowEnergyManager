//
//  LEDAccelViewController.m
//  LowEnergyDemo
//
//  Created by Stephen M Moraco on 04/18/13.
//  Copyright (c) 2013 Iron Sheep Productions, LLC. All rights reserved.
//

#import "LEDAccelViewController.h"
#import "LEDTISensorTag.h"
#import "LEDGattConsts.h"

#pragma mark CLASS LEDAccelViewController PRIVATE interface

@interface LEDAccelViewController () {
    
}

#pragma mark -- PRIVATE Properties

@property (weak, nonatomic) LEDTISensorTag *sensorTag;

#pragma mark -- IBOutlet Properties (handles to UI objects in view)

@property (weak, nonatomic) IBOutlet UILabel *lblDeviceName;

@property (weak, nonatomic) IBOutlet UISwitch *swAccelEnable;
@property (weak, nonatomic) IBOutlet UISwitch *swGyroEnable;
@property (weak, nonatomic) IBOutlet UISwitch *swMagnetoEnable;

@property (weak, nonatomic) IBOutlet UILabel *lblAccelX;
@property (weak, nonatomic) IBOutlet UILabel *lblAccelY;
@property (weak, nonatomic) IBOutlet UILabel *lblAccelZ;
@property (weak, nonatomic) IBOutlet UILabel *lblGyroX;
@property (weak, nonatomic) IBOutlet UILabel *lblGyroY;
@property (weak, nonatomic) IBOutlet UILabel *lblGyroZ;
@property (weak, nonatomic) IBOutlet UILabel *lblMagnetoX;
@property (weak, nonatomic) IBOutlet UILabel *lblMagnetoY;
@property (weak, nonatomic) IBOutlet UILabel *lblMagnetoZ;

@property (weak, nonatomic) IBOutlet UITextField *tfPeriod;
@property (weak, nonatomic) IBOutlet UIStepper *stpPeriod;
@property (weak, nonatomic) IBOutlet UITextField *tfMagPeriod;
@property (weak, nonatomic) IBOutlet UIStepper *stpMagPeriod;

#pragma mark -- IBAction Methods (Methods responding to user interaction)

- (IBAction)OnAccelSwValueChanged:(UISwitch *)sender;
- (IBAction)OnPeriodTouchUp:(UIStepper *)sender;
- (IBAction)OnPeriodValueChanged:(UIStepper *)sender;
- (IBAction)OnGyroSwValueChanged:(UISwitch *)sender;
- (IBAction)OnMagnetoSwValueChanged:(UISwitch *)sender;
- (IBAction)OnMagPeriodTouchUp:(UIStepper *)sender;
- (IBAction)OnMagPeriodValueChanged:(UIStepper *)sender;

#pragma mark -- PRIVATE (Utility) Methods

-(void)enableUI:(BOOL)enable;

#pragma mark -- PRIVATE NSNotificationCenter Callback Methods

- (void)deviceReady:(NSNotification *)notification;
- (void)valueUpdated:(NSNotification *)notification;

@end


#pragma mark - CLASS LEDAccelViewController Implementation

@implementation LEDAccelViewController {
    
}

#pragma mark -- View Override Methods

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.

    self.sensorTag = [LEDTISensorTag sharedInstance];
}

-(void)viewWillAppear:(BOOL)animated
{
    DLog(@"");
    [super viewWillAppear:animated];

    // register notification handlers
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(valueUpdated:) name:kCHARACTERISTIC_VALUE_UPDATED object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(deviceReady:) name:kDEVICE_IS_READY_FOR_ACCESS object:nil];

    [self enableUI:NO];

    // post the starting interpreted value
    [self OnPeriodValueChanged:self.stpPeriod];
    [self OnMagPeriodValueChanged:self.stpMagPeriod];

    if(self.sensorTag.isDeviceReady)
    {
        // telling ourself that panel is ready for access!
        [self deviceReady:nil];
    }
}

-(void)viewWillDisappear:(BOOL)animated
{
    DLog(@"");
    [super viewWillAppear:animated];

    // disable notifcations
    self.sensorTag.accelerometerNotify = NO;
    self.sensorTag.gyroscopeNotify = NO;
    self.sensorTag.magnetometerNotify = NO;

    // unregister observation handlers
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


#pragma mark -- PRIVATE (Utility) Methods

-(void)enableUI:(BOOL)enable
{
    NSString *strEnblInterp = (enable) ? @"ENABLEd" : @"Disabled";
    DLog(@"- UI is now: %@", strEnblInterp);
    self.swAccelEnable .enabled = enable;
    self.stpPeriod.enabled = enable;
    self.swGyroEnable.enabled = enable;
    self.swMagnetoEnable.enabled = enable;
    self.stpMagPeriod.enabled = enable;
}


#pragma mark -- PRIVATE NSNotificationCenter Callback Methods

- (void)deviceReady:(NSNotification *)notification
{
    DLog(@"");

    self.lblDeviceName.text = self.sensorTag.deviceName;

    // request a couple values in order to prepopulate UI controls
    [self.sensorTag readCharacteristicUUIDString:kACCEL_PERI_CHRSTC];   // request this value
    [self.sensorTag readCharacteristicUUIDString:kMAGNETO_PERI_CHRSTC];   // request this value, too

    // enable notifcations
    self.sensorTag.accelerometerNotify = YES;
    self.sensorTag.gyroscopeNotify = YES;
    self.sensorTag.magnetometerNotify = YES;

    // device is ready, allow our user to interact!
    [self enableUI:YES];

    // setup enables
    self.swAccelEnable.on = self.sensorTag.accelerometerEnable;
    self.swGyroEnable.on = self.sensorTag.gyroscopeEnable;
    self.swMagnetoEnable.on = self.sensorTag.magnetometerEnable;
}


- (void)valueUpdated:(NSNotification *)notification
{
    NSString *strChrstcUUID = notification.object;
    const NSString *strDegreeSymbol = @"\u00B0";   // degree symbol

    if([strChrstcUUID isEqualToString:kACCEL_DATA_CHRSTC])
    {
        //  our Accelerometer Sensor Values should now be ready!
        self.lblAccelX.text = [NSString stringWithFormat:@"%.1f G",self.sensorTag.accelerometerX];
        self.lblAccelY.text = [NSString stringWithFormat:@"%.1f G",self.sensorTag.accelerometerY];
        self.lblAccelZ.text = [NSString stringWithFormat:@"%.1f G",self.sensorTag.accelerometerZ];
    }
    else if([strChrstcUUID isEqualToString:kACCEL_PERI_CHRSTC])
    {
        // record the latest value to the stepper
        self.stpPeriod.value = self.sensorTag.accelerometerPeriod;
        // interpret the stepper value to our read-only display
        [self OnPeriodValueChanged:self.stpPeriod];
    }
    if([strChrstcUUID isEqualToString:kGYRO_DATA_CHRSTC])
    {
        //  our Accelerometer Sensor Values should now be ready!
        self.lblGyroX.text = [NSString stringWithFormat:@"%.1f %@/s",self.sensorTag.gyroscopeX, strDegreeSymbol];
        self.lblGyroY.text = [NSString stringWithFormat:@"%.1f %@/s",self.sensorTag.gyroscopeY, strDegreeSymbol];
        self.lblGyroZ.text = [NSString stringWithFormat:@"%.1f %@/s",self.sensorTag.gyroscopeZ, strDegreeSymbol];
    }
    if([strChrstcUUID isEqualToString:kMAGNETO_DATA_CHRSTC])
    {
        //  our Accelerometer Sensor Values should now be ready!
        self.lblMagnetoX.text = [NSString stringWithFormat:@"%.1f uT",self.sensorTag.magnetometerX];
        self.lblMagnetoY.text = [NSString stringWithFormat:@"%.1f uT",self.sensorTag.magnetometerY];
        self.lblMagnetoZ.text = [NSString stringWithFormat:@"%.1f uT",self.sensorTag.magnetometerZ];
    }
    else if([strChrstcUUID isEqualToString:kMAGNETO_PERI_CHRSTC])
    {
        // record the latest value to the stepper
        self.stpMagPeriod.value = self.sensorTag.magnetometerPeriod;
        // interpret the stepper value to our read-only display
        [self OnMagPeriodValueChanged:self.stpMagPeriod];
    }
}


#pragma mark -- IBAction Methods (Methods responding to user interaction)

- (IBAction)OnAccelSwValueChanged:(UISwitch *)sender
{
    NSString *strOnInterp = (sender.on) ? @"ON" : @"Off";
    DLog(@"- Accelerometer Updating is now: %@", strOnInterp);
    self.sensorTag.accelerometerEnable = sender.on;
}

- (IBAction)OnPeriodTouchUp:(UIStepper *)sender
{
    self.sensorTag.accelerometerPeriod = (int)sender.value;
}

- (IBAction)OnPeriodValueChanged:(UIStepper *)sender
{
    // interpret the current stepper value to our read-only display
    //   (scale the units so is easier to read!)
    double fActualPeriod = (sender.value * 10.0) / 1000.0;  // convert to mSec
    BOOL bDisplayInmSec = (fActualPeriod < 1.0) ? YES : NO; // determine which form to display
    
    NSString *strUnits = (bDisplayInmSec) ? @"mSec" : @"Sec";   // setup units
    double fScaledPeriod = (bDisplayInmSec) ? fActualPeriod * 1000.0 : fActualPeriod;   // re-scale the value
    DLog(@"Stepper(%d), Actual(%f) Scaled(%f)", (int)sender.value, fActualPeriod, fScaledPeriod);

    // now show in desired format
    if(bDisplayInmSec)
    {
        self.tfPeriod.text = [NSString stringWithFormat:@"%d %@", (int)fScaledPeriod, strUnits];
    }
    else
    {
        self.tfPeriod.text = [NSString stringWithFormat:@"%.2f %@", fScaledPeriod, strUnits];
    }
}

- (IBAction)OnGyroSwValueChanged:(UISwitch *)sender
{
    NSString *strOnInterp = (sender.on) ? @"ON" : @"Off";
    DLog(@"- Gyroscope Updating is now: %@", strOnInterp);
    self.sensorTag.gyroscopeEnable = sender.on;
}

- (IBAction)OnMagnetoSwValueChanged:(UISwitch *)sender
{
    NSString *strOnInterp = (sender.on) ? @"ON" : @"Off";
    DLog(@"- Magnetometer Updating is now: %@", strOnInterp);
    self.sensorTag.magnetometerEnable = sender.on;
}

- (IBAction)OnMagPeriodTouchUp:(UIStepper *)sender
{
    self.sensorTag.magnetometerPeriod = (int)sender.value;
}

- (IBAction)OnMagPeriodValueChanged:(UIStepper *)sender
{
    // interpret the current stepper value to our read-only display
    //   (scale the units so is easier to read!)
    double fActualPeriod = (sender.value * 10.0) / 1000.0;  // convert to mSec
    BOOL bDisplayInmSec = (fActualPeriod < 1.0) ? YES : NO; // determine which form to display

    NSString *strUnits = (bDisplayInmSec) ? @"mSec" : @"Sec";   // setup units
    double fScaledPeriod = (bDisplayInmSec) ? fActualPeriod * 1000.0 : fActualPeriod;   // re-scale the value
    DLog(@"Stepper(%d), Actual(%f) Scaled(%f)", (int)sender.value, fActualPeriod, fScaledPeriod);

    // now show in desired format
    if(bDisplayInmSec)
    {
        self.tfMagPeriod.text = [NSString stringWithFormat:@"%d %@", (int)fScaledPeriod, strUnits];
    }
    else
    {
        self.tfMagPeriod.text = [NSString stringWithFormat:@"%.2f %@", fScaledPeriod, strUnits];
    }
}

@end
