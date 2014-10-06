//
//  LEDTempsViewController.m
//  LowEnergyDemo
//
//  Created by Stephen M Moraco on 04/04/13.
//  Copyright (c) 2013 Iron Sheep Productions, LLC. All rights reserved.
//
#import <CoreBluetooth/CoreBluetooth.h>

#import "LEDTempsViewController.h"
#import "LEDTISensorTag.h"
#import "LEDGattConsts.h"
#import "MBProgressHUD.h"

#pragma mark CLASS LEDTempsViewController PRIVATE interface

@interface LEDTempsViewController () {
    
}

#pragma mark --> PRIVATE Properties

@property (weak, nonatomic) LEDTISensorTag *sensorTag;
@property (strong, nonatomic) NSArray *cbpPeripheralsFound;
@property (strong, nonatomic) MBProgressHUD *HUD;

#pragma mark ---- IBOutlet Properties (handles to UI objects in view)

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

#pragma mark --> PRIVATE (Utility) Methods

-(void)enableUI:(BOOL)enable;

#pragma mark ---- IBAction Methods (Methods responding to user interaction)

- (IBAction)OnTempSwValueChanged:(UISwitch *)sender;
- (IBAction)OnHumidSwValueChanged:(UISwitch *)sender;
- (IBAction)OnBaroSwValueChanged:(UISwitch *)sender;


@end


#pragma mark - CLASS LEDTempsViewController Implementation

@implementation LEDTempsViewController {

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

- (void)viewDidLoad
{
    DLog(@"");
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

    [self enableUI:NO];
    
    if(self.sensorTag.isDeviceReady)
    {
        DLog(@"- ready!");
        // telling ourself that panel is ready for access!
        [self deviceReady:nil];
    }
}

- (void)viewDidAppear:(BOOL)animated
{
    DLog(@"");
    [super viewDidAppear:animated];

    if(!self.sensorTag.isDeviceReady)
    {
        [self showHuntingForSensorTags];
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

    // remove any callback block for this view controller
    [self.sensorTag removeBlocksForViewController:self];

    // unregister observation handlers
    [[NSNotificationCenter defaultCenter] removeObserver:self];

    if(!self.HUD.isHidden)
    {
        [self.HUD hide:YES];
    }
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if([[segue identifier] isEqualToString:@"selectDevice"]) {
        UINavigationController *navCtrller = (UINavigationController *)segue.destinationViewController;
        LEDDevicePicker *chooser = (LEDDevicePicker *)[navCtrller.viewControllers objectAtIndex:0];
        chooser.foundDevices = self.cbpPeripheralsFound;
        chooser.delegate = self;
    }
}

- (void)didReceiveMemoryWarning
{
    DLog(@"");
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)requestValuesOnceAfterCalibration
{
    static BOOL s_bIsFirstPassAfterCalibration = YES;
    if(s_bIsFirstPassAfterCalibration)
    {
        DLog(@"- now reading values...");
        s_bIsFirstPassAfterCalibration = NO;

        //   NOTE: \u00B0 is degree symbol!
        const NSString *strDegreeSymbol = @"\u00B0";

        [self.sensorTag readCharacteristicUUIDString:kIR_TEMP_DATA_CHRSTC observer:self completion:^(NSString *UUIDstr) {
            DLog(@"- handling arrival of [0x%@]", UUIDstr);

            // both our IR Temp Sensor Values should now be ready!
            self.lblObjectTempInC.text = [NSString stringWithFormat:@"%.1f %@C",self.sensorTag.objectTemp, strDegreeSymbol];
            self.lblObjectTempInF.text = [NSString stringWithFormat:@"%.1f %@F",[LEDTISensorTag fahrenheitForTempInCentigrade:self.sensorTag.objectTemp], strDegreeSymbol];
            self.lblAmbientTempInC.text = [NSString stringWithFormat:@"%.1f %@C",self.sensorTag.ambientTemp, strDegreeSymbol];
            self.lblAmbientTempInF.text = [NSString stringWithFormat:@"%.1f %@F",[LEDTISensorTag fahrenheitForTempInCentigrade:self.sensorTag.ambientTemp], strDegreeSymbol];
        }];

        [self.sensorTag readCharacteristicUUIDString:kHUMID_DATA_CHRSTC observer:self completion:^(NSString *UUIDstr) {
            DLog(@"- handling arrival of [0x%@]", UUIDstr);
            // both our Humidity Sensor Values should now be ready!
            self.lblTempInC.text = [NSString stringWithFormat:@"%.1f %@C",self.sensorTag.tempInC, strDegreeSymbol];
            self.lblTempInF.text = [NSString stringWithFormat:@"%.1f %@F",[LEDTISensorTag fahrenheitForTempInCentigrade:self.sensorTag.tempInC], strDegreeSymbol];
            self.lblPrcntRH.text = [NSString stringWithFormat:@"%.1f %%",self.sensorTag.relHumidityPercent];
        }];

        [self.sensorTag readCharacteristicUUIDString:kBARO_DATA_CHRSTC observer:self completion:^(NSString *UUIDstr) {
            DLog(@"- handling arrival of [0x%@]", UUIDstr);
            self.lblBaroTempInC.text = [NSString stringWithFormat:@"%.1f %@C",self.sensorTag.baroTempInC, strDegreeSymbol];
            self.lblBaroTempInF.text = [NSString stringWithFormat:@"%.1f %@F",[LEDTISensorTag fahrenheitForTempInCentigrade:self.sensorTag.baroTempInC], strDegreeSymbol];
            self.lblBaroPressure.text = [NSString stringWithFormat:@"%.1f hPa",self.sensorTag.baroPressure];
        }];

        // enable notifcations
        self.sensorTag.tempNotify = YES;
        self.sensorTag.humidityNotify = YES;
        self.sensorTag.barometerNotify = YES;
    }
}

- (void)deviceReady:(NSNotification *)notification
{
    DLog(@"");

    self.lblDeviceName.text = self.sensorTag.deviceName;

    if(!self.HUD.isHidden)
    {
        [self.HUD hide:YES];
    }

    self.sensorTag.barometerCalibrate = YES;

    [self.sensorTag readCharacteristicUUIDString:kBARO_CALI_CHRSTC observer:self completion:^(NSString *UUIDstr) {
        DLog(@"- handling arrival of [0x%@]", UUIDstr);

        [self requestValuesOnceAfterCalibration];
    }];

    [self enableUI:YES];

    // setup enables
    self.swHumidityEnable.on = self.sensorTag.humidityEnable;
    self.swTempEnable.on = self.sensorTag.tempEnable;
    self.swBaroEnable.on = self.sensorTag.barometerEnable;
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

//#pragma mark --> PRIVATE Property Overrides

//#pragma mark --> PRIVATE (Utility) Methods

#pragma mark --> PRIVATE (Utility) Methods

-(void)enableUI:(BOOL)enable
{
    NSString *strEnblInterp = (enable) ? @"ENABLEd" : @"Disabled";
    DLog(@"- UI is now: %@", strEnblInterp);
    self.swTempEnable.enabled = enable;
    self.swHumidityEnable.enabled = enable;
    self.swBaroEnable.enabled = enable;
}

- (void)showHuntingForSensorTags
{
    self.HUD = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    self.HUD.labelText = @"Looking for TI Sensor Tags";
}


#pragma mark --> NSNotificationCenter Callback Methods

- (void)discoverBLEDevicesEnded:(NSNotification *)notification
{
    DLog(@" - notification=[%@]", notification);

    if(notification.object == nil)
    {
        // we ended without finding any objects!
        if(!self.HUD.isHidden)
        {
            [self.HUD hide:YES];
        }

        UIAlertView *avAlert = [[UIAlertView alloc] initWithTitle:@"BTLE Demo: Alert" message:@"No TI Sensor Tag devices found!" delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles: @"Try Again", nil];
        [avAlert show];
    }
    else
    {
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
}


#pragma mark PROTOCOL <LEDDevicePickerDelegate> Methods

- (void)chooser:(UITableViewController *)chooser didCancel:(BOOL)didCancel
{
    DLog(@"- didCancel=%d", didCancel);
    [chooser dismissViewControllerAnimated:YES completion:nil];
}

- (void)chooser:(UITableViewController *)chooser selectedDeviceIndex:(NSUInteger)index
{
    DLog(@"- index=%lu", (unsigned long)index);
    CBPeripheral *selectedDevice = [self.cbpPeripheralsFound objectAtIndex:index];
    self.lblDeviceName.text = selectedDevice.name;
    [self.sensorTag selectTag:selectedDevice];
}

#pragma mark PROTOCOL <UIAlertViewDelegate> Methods

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    BOOL bDidCancel = (buttonIndex == alertView.cancelButtonIndex) ? YES : NO;
#ifdef DEBUG
    NSString *strYN = (bDidCancel) ? @"YES" : @"no";
#endif
    DLog(@"- user canceled? [%@]", strYN);
    if(!bDidCancel)
    {
        // user want's to rescan for devices!   Do it!
        [self showHuntingForSensorTags];
        [self.sensorTag rescanForTags];
    }
}

@end
