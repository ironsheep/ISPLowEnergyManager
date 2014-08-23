//
//  LEDTempsViewController.m
//  LowEnergyDemo
//
//  Created by Stephen M Moraco on 04/04/13.
//  Copyright (c) 2013 Iron Sheep Productions, LLC. All rights reserved.
//

#import "LEDTempsViewController.h"
#import "LEDTISensorTag.h"
#import "LEDGattConsts.h"

#pragma mark CLASS LEDTempsViewController PRIVATE interface

@interface LEDTempsViewController () {
    
}

#pragma mark --> PRIVATE Properties

@property (weak, nonatomic) LEDTISensorTag *sensorTag;
@property (strong, nonatomic) NSArray *cbpPeripheralsFound;

#pragma mark --> IBOutlet Properties (handles to UI objects in view)

@property (weak, nonatomic) IBOutlet UILabel *lblDeviceName;

@property (weak, nonatomic) IBOutlet UISwitch *swTempEnable;
@property (weak, nonatomic) IBOutlet UILabel *lblAmbientTempInC;
@property (weak, nonatomic) IBOutlet UILabel *lblAmbientTempInF;
@property (weak, nonatomic) IBOutlet UILabel *lblObjectTempInC;
@property (weak, nonatomic) IBOutlet UILabel *lblObjectTempInF;

@property (weak, nonatomic) IBOutlet UISwitch *swHumidityEnable;
@property (weak, nonatomic) IBOutlet UILabel *lblTempInC;
@property (weak, nonatomic) IBOutlet UILabel *lblTempInF;
@property (weak, nonatomic) IBOutlet UILabel *lblPrcntRH;

@property (weak, nonatomic) IBOutlet UISwitch *swBaroEnable;
@property (weak, nonatomic) IBOutlet UILabel *lblBaroTempInC;
@property (weak, nonatomic) IBOutlet UILabel *lblBaroTempInF;
@property (weak, nonatomic) IBOutlet UILabel *lblBaroPressure;

#pragma mark --> IBAction Methods (Methods responding to user interaction)

- (IBAction)OnTempSwValueChanged:(UISwitch *)sender;
- (IBAction)OnHumidSwValueChanged:(UISwitch *)sender;
- (IBAction)OnBaroSwValueChanged:(UISwitch *)sender;

#pragma mark --> PRIVATE (Utility) Methods

-(void)enableUI:(BOOL)enable;

#pragma mark ---> PRIVATE NSNotificationCenter Callback Methods

- (void)deviceReady:(NSNotification *)notification;
- (void)valueUpdated:(NSNotification *)notification;


@end


#pragma mark - CLASS LEDTempsViewController Implementation

@implementation LEDTempsViewController

#pragma mark --> View Override Methods

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
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(discoverBLEDevicesEnded:) name:kPERIPHERAL_SCAN_ENDED_NOTIFICATION object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(valueUpdated:) name:kCHARACTERISTIC_VALUE_UPDATED object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(deviceReady:) name:kDEVICE_IS_READY_FOR_ACCESS object:nil];

    [self enableUI:NO];
    
    if(self.sensorTag.isDeviceReady)
    {
        DLog(@"- ready!");
        // telling ourself that panel is ready for access!
        [self deviceReady:nil];
    }
}

-(void)viewWillDisappear:(BOOL)animated
{
    DLog(@"");
    [super viewWillAppear:animated];

    // disnable notifcations
    self.sensorTag.tempNotify = NO;
    self.sensorTag.humidityNotify = NO;
    self.sensorTag.barometerNotify = NO;

    //[self.sensorTag removeBlocksForViewController:self];
    // unregister observation handlers
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)didReceiveMemoryWarning
{
    DLog(@"");
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


- (void)discoverBLEDevicesEnded:(NSNotification *)notification
{
    DLog(@" - notification=[%@]", notification);

    NSAssert([notification.object isKindOfClass:[NSArray class]], @"ERROR this is NOT a NSArray?!  What broke???");

    NSArray *cbpPanelsFoundAr = notification.object;
    self.cbpPeripheralsFound = cbpPanelsFoundAr;

    // if we've more than one panel, let's prompt for which we are to use...
    if(cbpPanelsFoundAr.count > 1)
    {
        [self performSegueWithIdentifier:@"selectDevice" sender:self];
    }
    else
    {
        [self deviceReady:notification];
    }
}

#pragma mark --> PRIVATE (Utility) Methods

-(void)enableUI:(BOOL)enable
{
    NSString *strEnblInterp = (enable) ? @"ENABLEd" : @"Disabled";
    DLog(@"- UI is now: %@", strEnblInterp);
    self.swTempEnable.enabled = enable;
    self.swHumidityEnable.enabled = enable;
    self.swBaroEnable.enabled = enable;
}


#pragma mark --> IBAction Methods (Methods responding to user interaction)

- (IBAction)OnTempSwValueChanged:(UISwitch *)sender
{
    NSString *strOnInterp = (sender.on) ? @"ON" : @"Off";
    DLog(@"- Temp Sensor Updating is now: %@", strOnInterp);
    self.sensorTag.tempEnable = sender.on;
}

- (IBAction)OnHumidSwValueChanged:(UISwitch *)sender
{
    NSString *strOnInterp = (sender.on) ? @"ON" : @"Off";
    DLog(@"- Humidity Sensor Updating is now: %@", strOnInterp);
    self.sensorTag.humidityEnable = sender.on;
}

- (IBAction)OnBaroSwValueChanged:(UISwitch *)sender {
    NSString *strOnInterp = (sender.on) ? @"ON" : @"Off";
    DLog(@"- Humidity Sensor Updating is now: %@", strOnInterp);
    self.sensorTag.barometerEnable = sender.on;
}

#pragma mark --> NSNotificationCenter Callback Methods

- (void)deviceReady:(NSNotification *)notification
{
    DLog(@"");

    self.lblDeviceName.text = self.sensorTag.deviceName;

    // enable notifcations
    self.sensorTag.tempNotify = YES;
    self.sensorTag.humidityNotify = YES;
    self.sensorTag.barometerNotify = YES;

    
    self.sensorTag.barometerCalibrate = YES;
    [self.sensorTag readCharacteristicUUIDString:kBARO_CALI_CHRSTC];

    [self enableUI:YES];
    
    // setup enables
    self.swHumidityEnable.on = self.sensorTag.humidityEnable;
    self.swTempEnable.on = self.sensorTag.tempEnable;
    self.swBaroEnable.on = self.sensorTag.barometerEnable;
}


- (void)valueUpdated:(NSNotification *)notification
{
    DLog(@"");
    NSString *strChrstcUUID = notification.object;
    const NSString *strDegreeSymbol = @"\u00B0";   // degree symbol
    
    if([strChrstcUUID isEqualToString:kIR_TEMP_DATA_CHRSTC])
    {
        // both our IR Temp Sensor Values should now be ready!
        //   NOTE: \\248 is degree symbol!
        self.lblObjectTempInC.text = [NSString stringWithFormat:@"%.1f %@C",self.sensorTag.objectTemp, strDegreeSymbol];
        self.lblObjectTempInF.text = [NSString stringWithFormat:@"%.1f %@F",[LEDTISensorTag fahrenheitForTempInCentigrade:self.sensorTag.objectTemp], strDegreeSymbol];
        self.lblAmbientTempInC.text = [NSString stringWithFormat:@"%.1f %@C",self.sensorTag.ambientTemp, strDegreeSymbol];
        self.lblAmbientTempInF.text = [NSString stringWithFormat:@"%.1f %@F",[LEDTISensorTag fahrenheitForTempInCentigrade:self.sensorTag.ambientTemp], strDegreeSymbol];
    }
    else if([strChrstcUUID isEqualToString:kHUMID_DATA_CHRSTC])
    {
        // both our Humidity Sensor Values should now be ready!
        self.lblTempInC.text = [NSString stringWithFormat:@"%.1f %@C",self.sensorTag.tempInC, strDegreeSymbol];
        self.lblTempInF.text = [NSString stringWithFormat:@"%.1f %@F",[LEDTISensorTag fahrenheitForTempInCentigrade:self.sensorTag.tempInC], strDegreeSymbol];
        self.lblPrcntRH.text = [NSString stringWithFormat:@"%.1f %%",self.sensorTag.relHumidityPercent];
    }
    else if([strChrstcUUID isEqualToString:kBARO_DATA_CHRSTC])
    {
        self.lblBaroTempInC.text = [NSString stringWithFormat:@"%.1f %@C",self.sensorTag.baroTempInC, strDegreeSymbol];
        self.lblBaroTempInF.text = [NSString stringWithFormat:@"%.1f %@F",[LEDTISensorTag fahrenheitForTempInCentigrade:self.sensorTag.baroTempInC], strDegreeSymbol];
        self.lblBaroPressure.text = [NSString stringWithFormat:@"%.1f hPa",self.sensorTag.baroPressure];
    }
}


@end
