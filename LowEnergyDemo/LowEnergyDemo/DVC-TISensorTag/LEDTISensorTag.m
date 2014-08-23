//
//  LEDTISensorTag.m
//  LowEnergyDemo
//
//    This is the implementation of the singleton that represents the state of the Physical TI
//    Sensor tag as well as marshals all communication to/from
//
//  Created by Stephen M Moraco on 04/04/13.
//  Copyright (c) 2013 Iron Sheep Productions, LLC. All rights reserved.
//

#import <CoreBluetooth/CoreBluetooth.h>
#import <ISPLowEnergyManager/ISPLowEnergyManager.h>
#import <ISPLowEnergyManager/ISPNotificationConsts.h>
#import <ISPLowEnergyManager/ISPPeripheralTriadParameter.h>

#import "LEDTISensorTag.h"
#import "LEDGattConsts.h"
#import "LEDPayloadUtils.h"

#import "MBProgressHUD.h"

#pragma mark CLASS LEDTISensorTag - PRIVATE Interface

@interface LEDTISensorTag () {

}

#pragma mark --> PRIVATE PROPERTIES

@property (weak, nonatomic) ISPLowEnergyManager *btLEManager;
@property (strong, nonatomic) MBProgressHUD *progressHUD;
@property (strong, nonatomic) NSDictionary *dctServices;
@property (strong, nonatomic) NSDictionary *dctCharacteristics;
@property (strong, nonatomic) NSDictionary *dctCharacteristicDescriptors;
@property (strong, nonatomic) NSMutableDictionary *dctCallbacks;
@property (strong, nonatomic) CBPeripheral *cbpTISensorTag;
@property (strong, nonatomic) NSArray *arWritablePropertyKeys;

@property (strong, nonatomic) NSString *deviceName;
@property (strong, nonatomic) NSString *modelNumber;


@property (assign, nonatomic, getter=isDeviceReady) BOOL deviceReady;

// Temp Service
@property (assign, nonatomic) double objectTemp;    // temp DegrC
@property (assign, nonatomic) double ambientTemp;   // temp DegrC
// Humidity Service
@property (assign, nonatomic) double tempInC;       // temp DegrC
@property (assign, nonatomic) double relHumidityPercent;  // RH%

// Barometric Pressure Service
@property (assign, nonatomic) double baroTempInC;  // temp DegrC
@property (assign, nonatomic) double baroPressure;  //

// Accelerometer Service
@property (assign, nonatomic) float accelerometerX;  // +/- G [-2 to +2]
@property (assign, nonatomic) float accelerometerY;  
@property (assign, nonatomic) float accelerometerZ;  

// Gyroscope Service
@property (assign, nonatomic) float gyroscopeX;  // Degr/Sec [-250 to +250]
@property (assign, nonatomic) float gyroscopeY;  
@property (assign, nonatomic) float gyroscopeZ;  

// Magnetometer Service
@property (assign, nonatomic) float magnetometerX;  // +/- magnetic force in uTera [-1000 to +1000]
@property (assign, nonatomic) float magnetometerY;  
@property (assign, nonatomic) float magnetometerZ;  

#pragma mark --> PRIVATE (Utility) Methods

- (void)discoverBLEDeviceSuccess:(NSNotification *)notification;
- (void)discoverBLEDeviceServicesSuccess:(NSNotification *)notification;
- (void)discoverBLEDeviceCharacteristicsSuccess:(NSNotification *)notification;
- (void)discoverBLEDeviceCharacteristicDescriptorsSuccess:(NSNotification *)notification;
- (void)updateValueForCharacteristic:(NSNotification *)notification;
- (void)updateNotifyStateForCharacteristic:(NSNotification *)notification;

- (void)applicationWillTerminate:(NSNotification *)notification;

// form expecting Notification Center notify of operation complete
-(void)setNotifyValue:(BOOL)enableNotify forCharacteristicUUIDString:(NSString *)UUIDString;

@end

#pragma mark - INTERNAL USE KeyPath Constants

// NOTE: one of these def's for each Writeable PROPERTY
#define kKeypathTempEnable @"tempEnable"
#define kKeypathTempNotify @"tempNotify"
#define kKeypathHumidityEnable @"humidityEnable"
#define kKeypathHumidityNotify @"humidityNotify"
#define kKeypathBarometerEnable @"barometerEnable"
#define kKeypathBarometerNotify @"barometerNotify"
#define kKeypathBarometerCalibrate @"barometerCalibrate"
#define kKeypathAccelerometerPeriod @"accelerometerPeriod"
#define kKeypathAccelerometerEnable @"accelerometerEnable"
#define kKeypathAccelerometerNotify @"accelerometerNotify"
#define kKeypathMagnetometerEnable @"magnetometerEnable"
#define kKeypathMagnetometerNotify @"magnetometerNotify"
#define kKeypathMagnetometerPeriod @"magnetometerPeriod"
#define kKeypathGyroscopeEnable @"gyroscopeEnable"
#define kKeypathGyroscopeNotify @"gyroscopeNotify"


#pragma mark - CLASS LEDTISensorTag - Implementation

@implementation LEDTISensorTag {
@private  // not needed, just a reminder ;-)
    BOOL m_bIgnoreNextValueChange;
    // calibration coefficients read from sensor (used in baro calcs)
    BOOL m_bHaveCalibrationData;
    uint16_t m_nC1;
    uint16_t m_nC2;
    uint16_t m_nC3;
    uint16_t m_nC4;
    int16_t m_nC5;
    int16_t m_nC6;
    int16_t m_nC7;
    int16_t m_nC8;
}

NSString *kDEVICE_IS_READY_FOR_ACCESS = @"DEVICE_IS_READY_FOR_ACCESS";
NSString *kCHARACTERISTIC_VALUE_UPDATED = @"CHARACTERISTIC_VALUE_UPDATED";
NSString *kPERIPHERAL_SCAN_ENDED_NOTIFICATION = @"PANEL_NOTIFICATION_PERIPHERAL_SCAN_ENDED";

#pragma mark --> CLASS (Static) METHODS

+ (id) sharedInstance
{
	static LEDTISensorTag	*s_pSharedSingleInstance= nil;

	if (!s_pSharedSingleInstance) {
        DLog(@"");
		s_pSharedSingleInstance = [[LEDTISensorTag alloc] init];
    }

	return s_pSharedSingleInstance;
}

+(double)fahrenheitForTempInCentigrade:(double)tempInC
{
    double fTempInF = ((tempInC * 9) / 5) + 32;
    return fTempInF;
}


//#pragma mark --> PUBLIC Property Setters (writeable properties, only)

#pragma mark --> Instance Methods


- (id) init
{
    self = [super init];
    if (self) {
        DLog(@"");

        self.btLEManager = [ISPLowEnergyManager sharedInstance];

        self.arWritablePropertyKeys = [NSArray arrayWithObjects:
                                       kKeypathTempEnable,
                                       kKeypathTempNotify,
                                       kKeypathHumidityEnable,
                                       kKeypathHumidityNotify,
                                       kKeypathBarometerEnable,
                                       kKeypathBarometerNotify,
                                       kKeypathBarometerCalibrate,
                                       kKeypathAccelerometerPeriod,
                                       kKeypathAccelerometerEnable,
                                       kKeypathAccelerometerNotify,
                                       kKeypathMagnetometerEnable,
                                       kKeypathMagnetometerNotify,
                                       kKeypathMagnetometerPeriod,
                                       kKeypathGyroscopeEnable,
                                       kKeypathGyroscopeNotify,
                                       nil];
        
        self.progressHUD = [[MBProgressHUD alloc] init];
        self.progressHUD.labelText = @"SCANNING";
        self.progressHUD.detailsLabelText = @"Looking for TI devices";

        // if want TI Sensor Tag object:
        self.btLEManager.searchUUID = nil; //kGENERIC_ACCESS_SVC;  //kIR_TEMPERATURE_SVC;
        self.btLEManager.numberOfDevicesToLocate = 2;
        self.btLEManager.searchDurationInSeconds = 3.0;

        self.dctCallbacks = [NSMutableDictionary dictionary];  // start with no registered callbacks

        self.deviceReady = NO;

        // register observation for each of our Writeable PROPERTies
        for (NSString *currPropertyKey in self.arWritablePropertyKeys) {
            [self addObserver: self
                   forKeyPath: currPropertyKey
                      options: NSKeyValueObservingOptionNew	// return the new value in dict
                      context: NULL];
        }
        
        // register notification handlers
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(discoverBLEDevicesStarted:) name:kNOTIFICATION_DEVICE_SCAN_STARTED object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(discoverBLEDevicesEnded:) name:kNOTIFICATION_DEVICE_SCAN_STOPPED object:nil];


        //[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(discoverBLEDeviceSuccess:) name:kNOTIFICATION_ADD_BLE_DEVICE object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(discoverBLEDeviceServicesSuccess:) name:kNOTIFICATION_DEVICE_SERVICES_DISCOVERED object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(discoverBLEDeviceCharacteristicsSuccess:) name:kNOTIFICATION_DEVICE_CHARACTERISTICS_DISCOVERED object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(discoverBLEDeviceCharacteristicDescriptorsSuccess:) name:kNOTIFICATION_DEVICE_DISCOVERED_CHARACTERISTIC_DESCRIPTORS object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateValueForCharacteristic:) name:kNOTIFICATION_DEVICE_UPDATED_CHARACTERISTIC_VALUE object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateNotifyStateForCharacteristic:) name:kNOTIFICATION_DEVICE_UPDATED_CHARACTERISTIC_NOTIF_STATE object:nil];

        // now, proceed to find devices when ready...
        [self.btLEManager enableScanningWhenReady];
    }
    return self;
}

- (void) dealloc
{
    DLog(@"");

    // We are a singleton and as such, dealloc shouldn't be called.
    NSAssert(false, @"dealloc should NOT be called on singleton!!!");
}


// form expecting Notification Center notify of operation complete
-(void)readCharacteristicUUIDString:(NSString *)UUIDString
{
    DLog(@"- UUIDString=[%@]", UUIDString);

    // our Characteristics MUST already be present!
    NSAssert(self.dctCharacteristics != nil && [self.dctCharacteristics count] > 0, @"[CODE/DATA] ERROR- Characteristics not yet present?!  What broke???");

    CBCharacteristic *desiredChrstc = [self.dctCharacteristics valueForKey:UUIDString];
    if(desiredChrstc != nil)
    {
        DLog(@"- Characteristic=[%@]", desiredChrstc);
        [self.cbpTISensorTag readValueForCharacteristic:desiredChrstc];
    }
    else
    {
        DLog(@"ERROR[CODE]: Characteristic [%@] not found!", UUIDString);
        // our Characteristics MUST already be present!
        NSAssert(false, @"[CODE] ERROR: Characteristic NOT found?!  Bad UUID?  Char's not read from device yet?");
    }
}


// form when using blocks for completion handling
-(void)readCharacteristicUUIDString:(NSString *)UUIDString completion:(LEDCharacteristicValueUpdatedBlock)callback
{
    LEDCharacteristicValueUpdatedBlock priorCallback = [self.dctCallbacks objectForKey:UUIDString];
    NSAssert(priorCallback == nil, @"[CODE] 2nd callback registered with 1st still active!");

    // record that we have a callback for this UUID
    DLog(@"- recording callback for [%@]", UUIDString);
    [self.dctCallbacks setObject:[callback copy] forKey:UUIDString];

    // now go read ask for the value of the characteristic
    [self readCharacteristicUUIDString:UUIDString];
}

-(void)setNotifyValue:(BOOL)enableNotify forCharacteristicUUIDString:(NSString *)UUIDString
{
    // our Characteristics MUST already be present!
    NSAssert(self.dctCharacteristics != nil && [self.dctCharacteristics count] > 0, @"[CODE/DATA] ERROR- Characteristics not yet present?!  What broke???");

    NSString *strNotifyEnable = (enableNotify) ? @"ON" : @"Off";
    DLog(@"- Notify:[%@] for Characteristic=[%@]", strNotifyEnable, UUIDString);
    
    CBCharacteristic *desiredChrstc = [self.dctCharacteristics valueForKey:UUIDString];
    if(desiredChrstc != nil)
    {
        DLog(@"- Characteristic=[%@]", desiredChrstc);
        [self.cbpTISensorTag setNotifyValue:enableNotify forCharacteristic:desiredChrstc];
    }
    else
    {
        DLog(@"ERROR[CODE]: Characteristic [%@] not found!", UUIDString);
        // our Characteristics MUST already be present!
        NSAssert(false, @"[CODE] ERROR: Characteristic NOT found?!  Bad UUID?  Char's not read from device yet?");
    }
}

#pragma mark --> PRIVATE (Utility) Methods

-(void)writeValue:(NSData *)data forCharacteristicUUIDString:(NSString *)UUIDString
{
    DLog(@"- Data=[%@], UUIDString=[%@]", data, UUIDString);

    // our Characteristics MUST already be present!
    NSAssert(self.dctCharacteristics != nil && [self.dctCharacteristics count] > 0, @"[CODE/DATA] ERROR- Characteristics not yet present?!  What broke???");

    CBCharacteristic *desiredChrstc = [self.dctCharacteristics valueForKey:UUIDString];
    if(desiredChrstc != nil)
    {
        DLog(@"- Characteristic=[%@]", desiredChrstc);
        [self.cbpTISensorTag writeValue:data forCharacteristic:desiredChrstc type:CBCharacteristicWriteWithResponse];
    }
    else
    {
        DLog(@"ERROR[CODE]: Characteristic [%@] not found!", UUIDString);
        // our Characteristics MUST already be present!
        NSAssert(false, @"[CODE] ERROR: Characteristic NOT found?!  Bad UUID?  Char's not read from device yet?");
    }
}

-(CBService *)serviceForUUID:(NSString *)UUIDString
{
    DLog(@"- UUIDString=[%@]", UUIDString);

    // our Services MUST already be present!
    NSAssert(self.dctServices != nil && [self.dctServices count] > 0, @"[CODE/DATA] ERROR- Services not yet present?!  What broke???");

    // our service MUST be found!
    CBService *foundService = [self.dctServices objectForKey:UUIDString];
    if(foundService == nil)
    {
        DLog(@"ERROR[CODE]: Service [%@] not found!", UUIDString);
    }
    NSAssert(foundService != nil, @"[CODE]- ERROR missing a Service?!  What broke???");
    return foundService;
}

- (void)selectDevice:(CBPeripheral *)device
{
    self.cbpTISensorTag = device;
    DLog(@"- selected our TI Device: [%@]", self.cbpTISensorTag);
    self.deviceName = self.cbpTISensorTag.name;
    [self.btLEManager connectPeripheral:self.cbpTISensorTag];
}

#pragma mark - NSNotificationCenter Callback Methods

- (void)discoverBLEDevicesStarted:(NSNotification *)notification
{
    DLog(@" - notification=[%@]", notification);
    //[self showScanIndicator];
    [self.progressHUD show:YES];

}

- (void)discoverBLEDeviceSuccess:(NSNotification *)notification
{
    // validate that we only get this type of object from our callback!
    NSAssert([notification.object isKindOfClass:[CBPeripheral class]], @"ERROR this is NOT a CBPeripheral?!  What broke???");

    self.cbpTISensorTag = notification.object;
    DLog(@"- located our Sensor Tag: [%@]", self.cbpTISensorTag);

    self.deviceName = self.cbpTISensorTag.name;
    //[self hideScanIndicator];

    DLog(@"*** Request STOP SCAN")
    [self.btLEManager stopScanning];

    DLog(@"*** Now connect to device")
    [self.btLEManager connectPeripheral:self.cbpTISensorTag];
}

- (void)discoverBLEDevicesEnded:(NSNotification *)notification
{
    DLog(@" - notification=[%@]", notification);
    //[self hideScanIndicator];
    [self.progressHUD hide:YES];

    NSAssert([notification.object isKindOfClass:[NSArray class]], @"ERROR this is NOT a NSArray?!  What broke???");

    NSArray *cbpPanelsFoundAr = notification.object;
    if(cbpPanelsFoundAr.count == 0)
    {
        DLog(@"*** No TI devices found!")
    }
    else if(cbpPanelsFoundAr.count == 1)
    {
        //DLog(@"*** Request STOP SCAN")
        //[self.btLEManager stopScanning];   // this is already done!

        DLog(@"*** Now connect to only TI device")
        [self selectDevice:[cbpPanelsFoundAr objectAtIndex:0]];

        //[[NSNotificationCenter defaultCenter] postNotificationName:kPERIPHERAL_SCAN_ENDED_NOTIFICATION object:notification.object];
    }
    else
    {
        DLog(@"*** Found more than one TI device =[%@]!", cbpPanelsFoundAr)
        // have many radios but up dialog so can select one!
        [[NSNotificationCenter defaultCenter] postNotificationName:kPERIPHERAL_SCAN_ENDED_NOTIFICATION object:notification.object];
    }
}

- (void)discoverBLEDeviceServicesSuccess:(NSNotification *)notification
{
    // validate that we only get this type of object from our callback!
    NSAssert([notification.object isKindOfClass:[NSDictionary class]], @"ERROR this is NOT a NSDictionary?!  What broke???");
    self.dctServices = notification.object;
    DLog(@"- located our Panel-Services: [%@]", self.dctServices);
}

- (void)discoverBLEDeviceCharacteristicsSuccess:(NSNotification *)notification
{
    // validate that we only get this type of object from our callback!
    NSAssert([notification.object isKindOfClass:[NSDictionary class]], @"ERROR this is NOT a NSDictionary?!  What broke???");
    self.dctCharacteristics = notification.object;
    DLog(@"- located our Panel-Characteristics: [%@]", self.dctCharacteristics);

    // NOTE: following two lines are fix for No "Characteristic Descriptors" found on TI Devices ??
    self.deviceReady = YES; // let others see if we have come ready as well!
    [[NSNotificationCenter defaultCenter] postNotificationName:kDEVICE_IS_READY_FOR_ACCESS object:nil];
}

- (void)discoverBLEDeviceCharacteristicDescriptorsSuccess:(NSNotification *)notification
{
    // validate that we only get this type of object from our callback!
    NSAssert([notification.object isKindOfClass:[NSDictionary class]], @"ERROR this is NOT a NSDictionary?!  What broke???");
    self.dctCharacteristicDescriptors = notification.object;
    DLog(@"- located our Panel-CharacteristicDescriptors: [%@]", self.dctCharacteristicDescriptors);

    self.deviceReady = YES; // let others see if we have come ready as well!
                            // tell our listeners that they can now access radio!
    [[NSNotificationCenter defaultCenter] postNotificationName:kDEVICE_IS_READY_FOR_ACCESS object:nil];
}

-(double)calcTargetObjectTempFromRaw:(uint16_t)nObjectTemp withAmbient:(double)currAmbient
{
    //-- calculate target temperature [Â°C] -
    double Vobj2 = (double)nObjectTemp * 1.0;
    Vobj2 *= 0.00000015625;
    
    double Tdie2 = currAmbient + 273.15;
    const double S0 = 6.4E-14;            // Calibration factor

    const double a1 = 1.75E-3;
    const double a2 = -1.678E-5;
    const double b0 = -2.94E-5;
    const double b1 = -5.7E-7;
    const double b2 = 4.63E-9;
    const double c2 = 13.4;
    const double Tref = 298.15;
    double S = S0*(1.0 + a1 *(Tdie2 - Tref)+ a2 * pow((Tdie2 - Tref), 2));
    double Vos = b0 + b1 * (Tdie2 - Tref) + b2 * pow((Tdie2 - Tref), 2);
    double fObj = (Vobj2 - Vos) + c2 * pow((Vobj2 - Vos), 2);
    double tObj = pow(pow(Tdie2, 4) + (fObj/S), 0.25);
    tObj = (tObj - 273.15);
    return tObj;
}

- (void)updateValueForCharacteristic:(NSNotification *)notification
{
    NSAssert([notification.object isKindOfClass:[ISPPeripheralTriadParameter class]], @"ERROR this is NOT a ISPPeripheralTriadParameter?!  What broke???");
    ISPPeripheralTriadParameter *infoObject = notification.object;

    NSString *strArrivingChrstcUUID = infoObject.characteristic.UUID.str;
    NSData *dat = infoObject.characteristic.value;
    DLog(@"dat=[%@]", dat);

    if([strArrivingChrstcUUID isEqualToString:kMODEL_NUMBER_CHRSTC])
    {
        NSString *strValue = [[NSString alloc] initWithData:dat encoding:NSUTF8StringEncoding];
        self.modelNumber = strValue;
    }
    else if([strArrivingChrstcUUID isEqualToString:kMANUFACTURER_NAME_CHRSTC])
    {
        //NSString *strValue = [[NSString alloc] initWithData:dat encoding:NSUTF8StringEncoding];
        //self.manufacturerName = strValue;
    }
    else if([strArrivingChrstcUUID isEqualToString:kFIRMWARE_REVISION_CHRSTC])
    {
        //NSString *strValue = [[NSString alloc] initWithData:dat encoding:NSUTF8StringEncoding];
        //self.firmwareRevision = strValue;
    }
    else if([strArrivingChrstcUUID isEqualToString:kHARDWARE_REVISION_CHRSTC])
    {
        //NSString *strValue = [[NSString alloc] initWithData:dat encoding:NSUTF8StringEncoding];
        //self.hardwareRevision = strValue;
    }
    else if([strArrivingChrstcUUID isEqualToString:kIR_TEMP_DATA_CHRSTC])
    {
        // pull out both temps and post to properties
        //
        // following built from:  http://processors.wiki.ti.com/index.php/SensorTag_User_Guide#IR_Temperature_Sensor
        //  [within Section entitled: "IR Temperature Sensor"]
        //
        const int kREQUIRED_DATA_LEN = 4;
        NSAssert([dat length] == kREQUIRED_DATA_LEN, @"Incorrect data length [(%d)!=%d]!", [dat length], kREQUIRED_DATA_LEN);

        uint8_t nValuesAr[kREQUIRED_DATA_LEN];
        [dat getBytes:&nValuesAr[0] length:kREQUIRED_DATA_LEN];

        uint16_t nObjectTemp = [LEDPayloadUtils uint16ValueFromBytes:&nValuesAr[0]];
        uint16_t nAmbientTemp = [LEDPayloadUtils uint16ValueFromBytes:&nValuesAr[2]];
        
        DLog(@"- IR Svc: amb:0x%.4X, obj:0x%.4X", nAmbientTemp, nObjectTemp);

        // if all values are zero then sensor is off and this is "late" notification of value, ignore it!
        if((nAmbientTemp == nObjectTemp && nObjectTemp == 0))
        {
            DLog(@"- IR Svc: {value ignored}");
        }
        else
        {
            //-- calculate die temperature [Â°C] --
            self.ambientTemp = ((double)nAmbientTemp)/128.0;
            
             //-- calculate target temperature [Â°C] -
            self.objectTemp = [self calcTargetObjectTempFromRaw:nObjectTemp withAmbient:self.ambientTemp];
            
            DLog(@"- IR Svc: amb:%.1lf, obj:%.1lf", self.ambientTemp, self.objectTemp);
        }
    }
    else if([strArrivingChrstcUUID isEqualToString:kHUMID_DATA_CHRSTC])
    {
        // pull out both temp and humidity and post to properties
        //
        // following built from:  http://processors.wiki.ti.com/index.php/SensorTag_User_Guide#Humidity_Sensor_2
        //  [within Section entitled: "Humidity Sensor"]
        //
        const int kREQUIRED_DATA_LEN = 4;
        NSAssert([dat length] == kREQUIRED_DATA_LEN, @"Incorrect data length [(%d)!=%d]!", [dat length], kREQUIRED_DATA_LEN);

        uint8_t nValuesAr[kREQUIRED_DATA_LEN];
        [dat getBytes:&nValuesAr[0] length:kREQUIRED_DATA_LEN];

        uint16_t nTempInC = [LEDPayloadUtils uint16ValueFromBytes:&nValuesAr[0]];
        uint16_t nRelHumid = [LEDPayloadUtils uint16ValueFromBytes:&nValuesAr[2]];
        DLog(@"- Humidity Svc: tempInC:0x%.4X, RH%%:0x%.4X", nTempInC, nRelHumid);

        // if all valules are zero then sensor is off and this is "late" notification of value, ignore it!
        if(nTempInC == nRelHumid && nRelHumid == 0)
        {
            DLog(@"- IR Svc: {value ignored}");
        }
        else
        {
            self.tempInC = -46.85 + 175.72/65536.0 * (double)nTempInC;

            nRelHumid &= ~0x0003; // clear bits [1..0] (status bits)
                                  //-- calculate relative humidity [%RH] --
            self.relHumidityPercent = -6.0 + 125.0/65536.0 * (double)nRelHumid; // RH= -6 + 125 * SRH/2^16
            DLog(@"- Humidity Svc: TempInC:%.1lf, %%RelHumidity:%.1lf", self.tempInC, self.relHumidityPercent);
        }
    }
    else if([strArrivingChrstcUUID isEqualToString:kBARO_DATA_CHRSTC])
    {
        // pull out both temp and pressure and post to properties
        //
        // following built from:  http://processors.wiki.ti.com/index.php/SensorTag_User_Guide#Barometric_Pressure_Sensor_2
        //  [within Section entitled: "Barometric Pressure Sensor"]
        //
        const int kREQUIRED_DATA_LEN = 4;
        NSAssert([dat length] == kREQUIRED_DATA_LEN, @"Incorrect data length [(%d)!=%d]!", [dat length], kREQUIRED_DATA_LEN);

        uint8_t nValuesAr[kREQUIRED_DATA_LEN];
        [dat getBytes:&nValuesAr[0] length:kREQUIRED_DATA_LEN];

        NSAssert(m_bHaveCalibrationData == YES, @"ERROR!? Calibration has NOT yet arrived!");
        
        uint16_t nBaroTemp = [LEDPayloadUtils uint16ValueFromBytes:&nValuesAr[0]];
        uint16_t nBaroPressure = [LEDPayloadUtils uint16ValueFromBytes:&nValuesAr[2]];
        DLog(@"- Baro Svc: tempInC:0x%.4X, Pressure:0x%.4X", nBaroTemp, nBaroPressure);

        if(nBaroTemp == nBaroPressure && nBaroPressure == 0)
        {
            DLog(@"- Barometer Svc: {value ignored}");
        }
        else
        {
            uint16_t Tr = nBaroTemp;
            // ***  Compute temperature in C  ***
            //
            // Formula from application note, rev_X:
            //  Ta = ((c1 * Tr) / 2^24) + (c2 / 2^10)
            //
            {
                // Ta = ((c1 * Tr) / 2^24)
                int64_t val = ((int64_t)(m_nC1 * Tr) * 100);
                int64_t Ta = (val >> 24);
                
                // TA += (c2 / 2^10)
                val = ((int64_t)m_nC2 * 100);
                Ta += (val >> 10);
                
                self.baroTempInC = (double)Ta / 100.0;
            }

            // ***  compute barometric pressure in hPa (hecto-pascal)  ***
            //
            // Formula from application note, rev_X:
            // Sensitivity = (c3 + ((c4 * Tr) / 2^17) + ((c5 * Tr^2) / 2^34))
            // Offset = (c6 * 2^14) + ((c7 * Tr) / 2^3) + ((c8 * Tr^2) / 2^19)
            // Pa = (Sensitivity * Pr + Offset) / 2^14
            //
            uint16_t Pr = nBaroPressure;
            
            // Sensitivity = C3
            int64_t nSensitivity = (int64_t)m_nC3;
            
            // Sensitivity += ((c4 * Tr) / 2^17)
            int64_t val = (int64_t)m_nC4 * Tr;
            nSensitivity += (val >> 17);
            
            // Sensitivity += ((c5 * Tr^2) / 2^34))
            val = (int64_t)m_nC5 * Tr * Tr;
            nSensitivity += (val >> 34);
            
            // Offset = (c6 * 2^14) 
            int64_t nOffset = (int64_t)m_nC6 << 14;
            
            // Offset += ((c7 * Tr) / 2^3)
            val = (int64_t)m_nC7 * Tr;
            nOffset += (val >> 3);
            
            // Offset += ((c8 * Tr^2) / 2^19)
            val = (int64_t)m_nC8 * Tr * Tr;
            nOffset += (val >> 19);
            
            // Pressure (Pa) = (Sensitivity * Pr + Offset) / 2^14
            int64_t pres = ((int64_t)(nSensitivity * Pr) + nOffset) >> 14;
            self.baroPressure = (double)pres / 100.0;
        }
    }
    else if([strArrivingChrstcUUID isEqualToString:kACCEL_DATA_CHRSTC])
    {
        // pull out accel X,Y, and Z and post to properties
        //
        // following built from:  http://processors.wiki.ti.com/index.php/SensorTag_User_Guide#Accelerometer_2
        //  [within Section entitled: "Accelerometer Sensor"]
        //
        const int kREQUIRED_DATA_LEN = 3;
        NSAssert([dat length] == kREQUIRED_DATA_LEN, @"Incorrect data length [(%d)!=%d]!", [dat length], kREQUIRED_DATA_LEN);

        int8_t nValuesAr[kREQUIRED_DATA_LEN];
        [dat getBytes:&nValuesAr[0] length:kREQUIRED_DATA_LEN];

        if(nValuesAr[0] == nValuesAr[1] && nValuesAr[1] == nValuesAr[2] && nValuesAr[2] == 0)
        {
            DLog(@"- Accelerometer Svc: {value ignored}");
        }
        else
        {
            self.accelerometerX = (nValuesAr[0] / 1.0) / (256.0 / 4.0);
            self.accelerometerY = (nValuesAr[1] / 1.0) / (256.0 / 4.0);
            self.accelerometerZ = (nValuesAr[2] / 1.0) / (256.0 / 4.0);
        }
    }
    else if([strArrivingChrstcUUID isEqualToString:kACCEL_PERI_CHRSTC])
    {
        // pull out period and post to property
        //
        // following built from:  http://processors.wiki.ti.com/index.php/SensorTag_User_Guide#Accelerometer_2
        //  [within Section entitled: "Accelerometer Sensor"]
        //
        const int kREQUIRED_DATA_LEN = 1;
        NSAssert([dat length] == kREQUIRED_DATA_LEN, @"Incorrect data length [(%d)!=%d]!", [dat length], kREQUIRED_DATA_LEN);

        uint8_t nValuesAr[kREQUIRED_DATA_LEN];
        [dat getBytes:&nValuesAr[0] length:kREQUIRED_DATA_LEN];

        DLog(@"- ignoring next value change");
        m_bIgnoreNextValueChange = YES;  // ignore ourself writing to this property
        self.accelerometerPeriod = nValuesAr[0];
    }
    else if([strArrivingChrstcUUID isEqualToString:kGYRO_DATA_CHRSTC])
    {
        // pull out Gyroscope X,Y, and Z and post to properties
        //
        // following built from:  http://processors.wiki.ti.com/index.php/SensorTag_User_Guide#Gyroscope_2
        //  [within Section entitled: "Gyroscope Sensor"]
        //
        const int kREQUIRED_DATA_LEN = 6;
        NSAssert([dat length] == kREQUIRED_DATA_LEN, @"Incorrect data length [(%d)!=%d]!", [dat length], kREQUIRED_DATA_LEN);

        uint8_t nValuesAr[kREQUIRED_DATA_LEN];
        [dat getBytes:&nValuesAr[0] length:kREQUIRED_DATA_LEN];

        int16_t nGyroX = [LEDPayloadUtils uint16ValueFromBytes:&nValuesAr[0]];
        int16_t nGyroY = [LEDPayloadUtils uint16ValueFromBytes:&nValuesAr[2]];
        int16_t nGyroZ = [LEDPayloadUtils uint16ValueFromBytes:&nValuesAr[4]];
        DLog(@"- Gyro X(0x%.4X), Y(0x%.4X), Z(0x%.4X)", nGyroX, nGyroY, nGyroZ);
        
        bool bSensorIsOff = YES;
        for (int nValueIdx=0; nValueIdx < kREQUIRED_DATA_LEN-1; nValueIdx++) {
            if(nValuesAr[nValueIdx] != 0)
            {
                bSensorIsOff = NO;
                break;
            }
        }

        if(bSensorIsOff)
        {
            DLog(@"- Gyroscope Svc: {value ignored}");
        }
        else
        {
            self.gyroscopeX = (nGyroX / 1.0) / (65536.0 / 500.0);
            self.gyroscopeY = (nGyroY / 1.0) / (65536.0 / 500.0);
            self.gyroscopeZ = (nGyroZ / 1.0) / (65536.0 / 500.0);
        }
    }
    else if([strArrivingChrstcUUID isEqualToString:kMAGNETO_DATA_CHRSTC])
    {
        // pull out accel X,Y, and Z and post to properties
        //
        // following built from:  http://processors.wiki.ti.com/index.php/SensorTag_User_Guide#Magnetometer
        //  [within Section entitled: "Magnetometer Sensor"]
        //
        const int kREQUIRED_DATA_LEN = 6;
        NSAssert([dat length] == kREQUIRED_DATA_LEN, @"Incorrect data length [(%d)!=%d]!", [dat length], kREQUIRED_DATA_LEN);

        uint8_t nValuesAr[kREQUIRED_DATA_LEN];
        [dat getBytes:&nValuesAr[0] length:kREQUIRED_DATA_LEN];

        int16_t nMagnetoX = [LEDPayloadUtils uint16ValueFromBytes:&nValuesAr[0]];
        int16_t nMagnetoY = [LEDPayloadUtils uint16ValueFromBytes:&nValuesAr[2]];
        int16_t nMagnetoZ = [LEDPayloadUtils uint16ValueFromBytes:&nValuesAr[4]];
        DLog(@"- Magneto X(0x%.4X), Y(0x%.4X), Z(0x%.4X)", nMagnetoX, nMagnetoY, nMagnetoZ);

        bool bSensorIsOff = YES;
        for (int nValueIdx=0; nValueIdx < kREQUIRED_DATA_LEN-1; nValueIdx++) {
            if(nValuesAr[nValueIdx] != 0)
            {
                bSensorIsOff = NO;
                break;
            }
        }

        if(bSensorIsOff)
        {
            DLog(@"- Magnetometer Svc: {value ignored}");
        }
        else
        {
            self.magnetometerX = (nMagnetoX * 1.0) / (65536.0 / 2000.0);
            self.magnetometerY = (nMagnetoY * 1.0) / (65536.0 / 2000.0);
            self.magnetometerZ = (nMagnetoZ * 1.0) / (65536.0 / 2000.0);
        }
    }
   else if([strArrivingChrstcUUID isEqualToString:kMAGNETO_PERI_CHRSTC])
    {
        // pull out period and post to property
        //
        // following built from:  http://processors.wiki.ti.com/index.php/SensorTag_User_Guide#Magnetometer
        //  [within Section entitled: "Magnetometer Sensor"]
        //
        const int kREQUIRED_DATA_LEN = 1;
        NSAssert([dat length] == kREQUIRED_DATA_LEN, @"Incorrect data length [(%d)!=%d]!", [dat length], kREQUIRED_DATA_LEN);

        uint8_t nValuesAr[kREQUIRED_DATA_LEN];
        [dat getBytes:&nValuesAr[0] length:kREQUIRED_DATA_LEN];

        DLog(@"- ignoring next value change");
        m_bIgnoreNextValueChange = YES;  // ignore ourself writing to this property
        self.magnetometerPeriod = nValuesAr[0];
    }
   else if([strArrivingChrstcUUID isEqualToString:kBARO_CALI_CHRSTC])
   {
       // pull out 8 Calibration Values
       //
       // following built from:  http://processors.wiki.ti.com/index.php/SensorTag_User_Guide#Magnetometer
       //  [within Section entitled: "Magnetometer Sensor"]
       //
       const int kREQUIRED_DATA_LEN = 16;
       NSAssert([dat length] == kREQUIRED_DATA_LEN, @"Incorrect data length [(%d)!=%d]!", [dat length], kREQUIRED_DATA_LEN);

       uint8_t nValuesAr[kREQUIRED_DATA_LEN];
       [dat getBytes:&nValuesAr[0] length:kREQUIRED_DATA_LEN];

       m_nC1 = [LEDPayloadUtils uint16ValueFromBytes:&nValuesAr[0]];
       m_nC2 = [LEDPayloadUtils uint16ValueFromBytes:&nValuesAr[2]];
       m_nC3 = [LEDPayloadUtils uint16ValueFromBytes:&nValuesAr[4]];
       m_nC4 = [LEDPayloadUtils uint16ValueFromBytes:&nValuesAr[6]];
       m_nC5 = [LEDPayloadUtils uint16ValueFromBytes:&nValuesAr[8]];
       m_nC6 = [LEDPayloadUtils uint16ValueFromBytes:&nValuesAr[10]];
       m_nC7 = [LEDPayloadUtils uint16ValueFromBytes:&nValuesAr[12]];
       m_nC8 = [LEDPayloadUtils uint16ValueFromBytes:&nValuesAr[14]];
       m_bHaveCalibrationData = YES;

       DLog(@"- loaded Calibration Coefficients");
   }
    else
    {
        DLog(@"*****  UNHANDLED arriving charicteristic: %@", strArrivingChrstcUUID);
    }

    // do we have a callBack registered for this characteristic
    LEDCharacteristicValueUpdatedBlock callBack = [self.dctCallbacks objectForKey:strArrivingChrstcUUID];
    if(callBack != nil)
    {
        DLog(@"- Invoking Callback for: %@", strArrivingChrstcUUID);
        
        // remove the callback so we don't use it next time...
        [self.dctCallbacks removeObjectForKey:strArrivingChrstcUUID];
        
        // handle callback form of notify (invoke the callback)
        callBack(strArrivingChrstcUUID);
    }
    else
    {
        DLog(@"- Posting Notification for: %@", strArrivingChrstcUUID);
        
        // handle notification center form of notify (post the notification)
        [[NSNotificationCenter defaultCenter] postNotificationName:kCHARACTERISTIC_VALUE_UPDATED object:strArrivingChrstcUUID];
    }
}

- (void)updateNotifyStateForCharacteristic:(NSNotification *)notification
{
    NSAssert([notification.object isKindOfClass:[ISPPeripheralTriadParameter class]], @"ERROR this is NOT a ISPPeripheralTriadParameter?!  What broke???");
    ISPPeripheralTriadParameter *infoObject = notification.object;
    DLog(@"- triad=[%@]", infoObject);
}

- (void)applicationWillTerminate:(NSNotification *)notification
{
    DLog(@"*** Now disconnect from panel")
    [self.btLEManager disconnectPeripheral:self.cbpTISensorTag];
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.

    // Unregister Observations
    //   for each Writeable PROPERTY
    for (NSString *writeablePropertyKey in self.arWritablePropertyKeys) {
        [self removeObserver: self  forKeyPath: writeablePropertyKey];
    }

    // unregister notification handlers
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kNOTIFICATION_ADD_BLE_DEVICE object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kNOTIFICATION_DEVICE_SERVICES_DISCOVERED object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kNOTIFICATION_DEVICE_CHARACTERISTICS_DISCOVERED object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kNOTIFICATION_DEVICE_DISCOVERED_CHARACTERISTIC_DESCRIPTORS object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kNOTIFICATION_DEVICE_UPDATED_CHARACTERISTIC_VALUE object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kNOTIFICATION_DEVICE_UPDATED_CHARACTERISTIC_NOTIF_STATE object:nil];
}

#pragma mark -  PROTOCOL <NSKeyValueObserving> Methods

-(void)observeValueForKeyPath:(NSString *)keyPath
                     ofObject:(id)object
                       change:(NSDictionary *)change
                      context:(void *)context
{
	NSObject *newValue = [change objectForKey:NSKeyValueChangeNewKey];
	DLog(@"** keypath=%@, value=%@", keyPath, newValue);    // here with PROPERTY value updates

	if(newValue != nil && !m_bIgnoreNextValueChange)
	{
        // NOTE: one of these if's for each Writeable PROPERTY
        if([keyPath isEqualToString:kKeypathTempEnable])
		{
            // build payload value
           Byte nValue = (self.tempEnable) ? 1: 0;
            NSData *dat = [NSData dataWithBytes:&nValue length:1];
            // write to characteristic of peripheral
            [self writeValue:dat forCharacteristicUUIDString:kIR_TEMP_CONF_CHRSTC];
		}
        else if([keyPath isEqualToString:kKeypathTempNotify])
		{
            // write Notify value to characteristic of peripheral
            [self setNotifyValue:self.isTempNotifying forCharacteristicUUIDString:kIR_TEMP_DATA_CHRSTC];
		}
        else if([keyPath isEqualToString:kKeypathHumidityEnable])
		{
            // build payload value
            Byte nValue = (self.isHumidityEnabled) ? 1: 0;
            NSData *dat = [NSData dataWithBytes:&nValue length:1];
            // write to characteristic of peripheral
            [self writeValue:dat forCharacteristicUUIDString:kHUMID_CONF_CHRSTC];
		}
        else if([keyPath isEqualToString:kKeypathHumidityNotify])
		{
            // write Notify value to characteristic of peripheral
            [self setNotifyValue:self.isHumidityNotifying forCharacteristicUUIDString:kHUMID_DATA_CHRSTC];
		}
        else if([keyPath isEqualToString:kKeypathBarometerEnable])
		{
            // build payload value
            Byte nValue = (self.isBarometerEnabled) ? 1: 0;
            NSData *dat = [NSData dataWithBytes:&nValue length:1];
            // write to characteristic of peripheral
           [self writeValue:dat forCharacteristicUUIDString:kBARO_CONF_CHRSTC];
		}
        else if([keyPath isEqualToString:kKeypathBarometerNotify])
		{
            // write Notify value to characteristic of peripheral
            [self setNotifyValue:self.isBarometerNotifying forCharacteristicUUIDString:kBARO_DATA_CHRSTC];
		}
        else if([keyPath isEqualToString:kKeypathBarometerCalibrate])
		{
            // build payload value
            Byte nValue = (self.isBarometerCalibrated) ? 0x02: 0x00;
            NSData *dat = [NSData dataWithBytes:&nValue length:1];
            // write to characteristic of peripheral
            [self writeValue:dat forCharacteristicUUIDString:kBARO_CONF_CHRSTC];
		}
        else if([keyPath isEqualToString:kKeypathAccelerometerNotify])
		{
            // write Notify value to characteristic of peripheral
            [self setNotifyValue:self.isAccelerometerNotifying forCharacteristicUUIDString:kACCEL_DATA_CHRSTC];
		}
        else if([keyPath isEqualToString:kKeypathAccelerometerEnable])
		{
            // build payload value
            Byte nValue = (self.isAccelerometerEnabled) ? 1: 0;
            NSData *dat = [NSData dataWithBytes:&nValue length:1];
            // write to characteristic of peripheral
            [self writeValue:dat forCharacteristicUUIDString:kACCEL_CONF_CHRSTC];
		}
        else if([keyPath isEqualToString:kKeypathAccelerometerPeriod])
		{
            // build payload value
            Byte nValue = self.accelerometerPeriod;
            NSData *dat = [NSData dataWithBytes:&nValue length:1];
            // write to characteristic of peripheral
            [self writeValue:dat forCharacteristicUUIDString:kACCEL_PERI_CHRSTC];
		}
        else if([keyPath isEqualToString:kKeypathGyroscopeNotify])
		{
            // write Notify value to characteristic of peripheral
           [self setNotifyValue:self.isGyroscopeNotifying forCharacteristicUUIDString:kGYRO_DATA_CHRSTC];
		}
        else if([keyPath isEqualToString:kKeypathGyroscopeEnable])
		{
            // build payload value
            Byte nValue = (self.isGyroscopeEnabled) ? 1: 0;
            NSData *dat = [NSData dataWithBytes:&nValue length:1];
            // write to characteristic of peripheral
            [self writeValue:dat forCharacteristicUUIDString:kGYRO_CONF_CHRSTC];
		}
        else if([keyPath isEqualToString:kKeypathMagnetometerNotify])
		{
            // write Notify value to characteristic of peripheral
            [self setNotifyValue:self.isMagnetometerNotifying forCharacteristicUUIDString:kMAGNETO_DATA_CHRSTC];
		}
        else if([keyPath isEqualToString:kKeypathMagnetometerEnable])
		{
            // build payload value
            Byte nValue = (self.isMagnetometerEnabled) ? 1: 0;
            NSData *dat = [NSData dataWithBytes:&nValue length:1];
            // write to characteristic of peripheral
            [self writeValue:dat forCharacteristicUUIDString:kMAGNETO_CONF_CHRSTC];
		}
        else if([keyPath isEqualToString:kKeypathMagnetometerPeriod])
		{
            // build payload value
            Byte nValue = self.magnetometerPeriod;
            NSData *dat = [NSData dataWithBytes:&nValue length:1];
            // write to characteristic of peripheral
            [self writeValue:dat forCharacteristicUUIDString:kMAGNETO_PERI_CHRSTC];
		}
        else
        {
            // not this derived class, pass on to base
            [super observeValueForKeyPath:keyPath
                                 ofObject:object
                                   change:change
                                  context:context];
        }
	}
    if(m_bIgnoreNextValueChange)
    {
        DLog(@"- Ignored and clearing ignore");
        m_bIgnoreNextValueChange = NO;
    }
}

@end
