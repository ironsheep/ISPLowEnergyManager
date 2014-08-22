//
//  CBCharacteristic+MyCharacteristics.m
//  ISPLowEnergyManager
//
//  Created by Stephen M Moraco on 03/17/13.
//  Copyright (c) 2013 Iron Sheep Productions, LLC. All rights reserved.
//

#import <ISPLowEnergyManager/CBUUID+Methods.h>

#import "CBCharacteristic+MyCharacteristics.h"
#import "LEDGattConsts.h"

@implementation CBCharacteristic (MyCharacteristics)

-(NSString *)friendlyName
{
    static NSDictionary *s_dctCharacteristicNames = nil;

    if(s_dctCharacteristicNames == nil) {
        s_dctCharacteristicNames = [NSDictionary dictionaryWithObjects:
                             [NSArray arrayWithObjects:
                              // GAP SVC
                              @"Device Name  <2A00>",
                              @"Appearance  <2A01>",
                              @"Periph Priv  <2A02>",
                              @"Reconn Addr  <2A03>",
                              @"Periph Conn Parm  <2A04>",
                              // GATT SVC
                              @"Svc Changed  <2A05>",
                              // DVC INFO SVC
                              @"System ID  <2A23>",
                              @"Model Number  <2A24>",
                              @"Serial Number  <2A25>",
                              @"Firmware Revision  <2A26>",
                              @"Hardware Revision  <2A27>",
                              @"Software Revision  <2A28>",
                              @"Manufacturer Name  <2A29>",
                              @"11709 Cert Data  <2A2A>",
                              //@"PNP ID Data  <2A2A>",
                              // IR TEMPERATURE SVC
                              @"Temperature Data  <F000--AA01>",
                              @"Temperature Config <F000--AA02>",
                              // ACCELEROMETER SVC
                              @"Accelerometer Data  <F000--AA11>",
                              @"Accelerometer Config <F000--AA12>",
                              @"Accelerometer Period <F000--AA13>",
                              // HUMIDITY SVC
                              @"Humidity Data  <F000--AA21>",
                              @"Humidity Config <F000--AA22>",
                              // MAGNETOMETER SVC
                              @"Magnetometer Data  <F000--AA31>",
                              @"Magnetometer Config <F000--AA32>",
                              @"Magnetometer Period <F000--AA33>",
                              // BAROMETER SVC
                              @"Barometer Data  <F000--AA41>",
                              @"Barometer Config <F000--AA42>",
                              @"Barometer Calibr <F000--AA43>",
                              // GYROSCOPE SVC
                              @"Gyroscope Data  <F000--AA51>",
                              @"Gyroscope Config <F000--AA52>",
                              // SK KEYPRESSED SVC
                              @"Key-pressed Data  <FFE1>",
                              // TEST SVC
                              @"TEST Data  <F000--AA61>",
                              @"TEST Config <F000--AA62>",
                              nil]
                                                        forKeys:
                             [NSArray arrayWithObjects:
                              // GAP SVC
                              kDEVICE_NAME_CHRSTC,
                              kAPPEARANCE_CHRSTC,
                              kPERI_PRIVACY_FLAG_CHRSTC,
                              kRECONNECT_ADDR_CHRSTC,
                              kPER_CONN_PARAM_CHRSTC,
                              // GATT SVC
                              kSVC_CHANGED_CHRSTC,
                              // DVC INFO SVC
                              kSYSTEM_ID_CHRSTC,
                              kMODEL_NUMBER_CHRSTC,
                              kSERIAL_NUMBER_CHRSTC,
                              kFIRMWARE_REVISION_CHRSTC,
                              kHARDWARE_REVISION_CHRSTC,
                              kSOFTWARE_REVISION_CHRSTC,
                              kMANUFACTURER_NAME_CHRSTC,
                              k11073_CERT_DATA_CHRSTC,
                              kPNPID_DATA_CHRSTC,
                              // IR TEMPERATURE SVC
                              kIR_TEMP_DATA_CHRSTC,
                              kIR_TEMP_CONF_CHRSTC,
                              // ACCELEROMETER SVC
                              kACCEL_DATA_CHRSTC,
                              kACCEL_CONF_CHRSTC,
                              kACCEL_PERI_CHRSTC,
                              // HUMIDITY SVC
                              kHUMID_DATA_CHRSTC,
                              kHUMID_CONF_CHRSTC,
                              // MAGNETOMETER SVC
                              kMAGNETO_DATA_CHRSTC,
                              kMAGNETO_CONF_CHRSTC,
                              kMAGNETO_PERI_CHRSTC,
                              // BAROMETER SVC
                              kBARO_DATA_CHRSTC,
                              kBARO_CONF_CHRSTC,
                              kBARO_CALI_CHRSTC,
                              // GYROSCOPE SVC
                              kGYRO_DATA_CHRSTC,
                              kGYRO_CONF_CHRSTC,
                              // SK_KEYPRESSED SVC
                              kKEYPRESSED_CHRSTC,
                              // TEST SVC
                              kTEST_DATA_CHRSTC,
                              kTEST_CONF_CHRSTC,
                              nil]
                             ];
    }
    NSString *strFriendlyName = [s_dctCharacteristicNames valueForKey:self.UUID.str];
    if(strFriendlyName == nil)
    {
        strFriendlyName = self.UUID.str;
    }
    return strFriendlyName;
}

@end
