//
//  ISPLowEnergyManager.m
//  ISPLowEnergyManager
//
//  Created by Stephen M Moraco on 08/22/14.
//  Copyright (c) 2014 Iron Sheep Productions, LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreBluetooth/CoreBluetooth.h>
#import "CBService+Methods.h"
#import "CBPeripheral+Methods.h"
#import "CBUUID+Methods.h"

#import "ISPLowEnergyManager.h"
#import "ISPNotificationConsts.h"
#import "ISPPeripheralTriadParameter.h"


#pragma mark CLASS ISPLowEnergyManager - PRIVATE Interface

@interface ISPLowEnergyManager () {
	BOOL    m_bPendingInit;
    NSInteger m_nMaxServices;
    BOOL m_bDiscoveringIncludedServices;
    NSInteger m_nNextServiceToCheck;
    BOOL m_bDiscoveringCharacteristics;
    NSInteger m_nNextServiceCharacteristicToCheck;
    BOOL m_bDiscoveringDescriptors;
    NSInteger m_nNextCharacteristicToCheck;
}


#pragma mark -- PRIVATE PROPERTIES

@property (strong, nonatomic) CBCentralManager  *cbcManager;
@property (strong, nonatomic) CBPeripheral      *cbpConnectedDevice;
@property (strong, nonatomic) NSMutableArray    *foundPeripherals;
@property (strong, nonatomic) NSMutableArray	*foundServices;
@property (strong, nonatomic) NSMutableArray	*foundIncludedServices;
@property (strong, nonatomic) NSMutableArray	*foundCharacteristics;
@property (strong, nonatomic) NSMutableDictionary	*dctFoundDescriptors;

#pragma mark -- PRIVATE (Utility) Methods

- (void)loadSavedDevices;
- (void)addSavedDevice:(CFUUIDRef)uuid;
- (void)removeSavedDevice:(CFUUIDRef)uuid;
- (void)clearDevices;
- (NSString *)descriptionOfError:(NSError *)error;
- (void)startScanningForIncludedServices;
- (void)continueScanForIncludedServices;

- (void)scanForServiceCharacteristics;
- (void)continueScanForServiceCharacteristics;

- (void)scanForCharacteristicDescriptors;
- (void)continueScanForCharacteristicDescriptors;

@end

#pragma mark - CLASS ISPLowEnergyManager - Implementation

@implementation ISPLowEnergyManager {

}

#pragma mark - CLASS METHODS

+ (id) sharedInstance
{
	static ISPLowEnergyManager	*s_lemSingleInstance = nil;

	if (s_lemSingleInstance == nil) {
        DLog(@"");
		s_lemSingleInstance = [[ISPLowEnergyManager alloc] init];
    }

	return s_lemSingleInstance;
}

+(NSString *)keyForDescriptor:(CBDescriptor *)descriptor ofCharacteristic:(CBCharacteristic *)characteristic
{
    NSString *strDescriptorKey = [NSString stringWithFormat:@"%@;%@",characteristic.UUID.str, descriptor.UUID.str];
    return strDescriptorKey;
}

+(void)UUIDsForDescriptorKey:(NSString *)descriptorKey characteristicKeyPortion:(NSString **)characteristicUUIDString descriptorKeyPortion:(NSString **)descriptorUUIDString
{
    NSArray *UUIDsFoundAr = [descriptorKey componentsSeparatedByString:@";"];
    NSAssert([UUIDsFoundAr count] == 2, @"ERROR Failed to split Descriptor Key string!?");
    *characteristicUUIDString = [NSString stringWithString:[UUIDsFoundAr objectAtIndex:0]];
    *characteristicUUIDString = [NSString stringWithString:[UUIDsFoundAr objectAtIndex:1]];
}

+(NSString *)characteristicUUIDStringForDescriptorKey:(NSString *)descriptorKey
{
    NSArray *UUIDsFoundAr = [descriptorKey componentsSeparatedByString:@";"];
    NSAssert([UUIDsFoundAr count] == 2, @"ERROR Failed to split Descriptor Key string!?");
    return [UUIDsFoundAr objectAtIndex:0];
}

+(NSString *)descriptorUUIDStringForDescriptorKey:(NSString *)descriptorKey
{
    NSArray *UUIDsFoundAr = [descriptorKey componentsSeparatedByString:@";"];
    NSAssert([UUIDsFoundAr count] == 2, @"ERROR Failed to split Descriptor Key string!?");
    return [UUIDsFoundAr objectAtIndex:1];
}


#pragma mark -- Instance Methods


- (id) init
{
    self = [super init];
    if (self) {
        DLog(@"");
		m_bPendingInit = YES;
        m_bDiscoveringIncludedServices = NO;
        m_bDiscoveringCharacteristics = NO;
        m_bDiscoveringDescriptors = NO;
		self.cbcManager = [[CBCentralManager alloc] initWithDelegate:self queue:dispatch_get_main_queue()];

		self.foundPeripherals = [[NSMutableArray alloc] init];
		self.foundServices = [[NSMutableArray alloc] init];
		self.foundIncludedServices = [[NSMutableArray alloc] init];
		self.foundCharacteristics = [[NSMutableArray alloc] init];
		self.dctFoundDescriptors = [NSMutableDictionary dictionary];
    }
    return self;
}


- (void) dealloc
{
    DLog(@"");

    // We are a singleton and as such, dealloc shouldn't be called.
    NSAssert(false, @"dealloc should NOT be called on singleton!!!");
}

#pragma mark --- Device cache methods

- (void)loadSavedDevices
{
    DLog(@"- ENTRY");
	NSArray	*storedDevices	= [[NSUserDefaults standardUserDefaults] arrayForKey:@"StoredDevices"];

	if (![storedDevices isKindOfClass:[NSArray class]]) {
        DLog(@"- No stored array to load");
        return;
    }

    for (id deviceUUIDString in storedDevices) {

        if (![deviceUUIDString isKindOfClass:[NSString class]])
            continue;

        CFUUIDRef uuid = CFUUIDCreateFromString(NULL, (CFStringRef)deviceUUIDString);
        if (!uuid)
            continue;

        [self.cbcManager retrievePeripherals:[NSArray arrayWithObject:(__bridge id)uuid]];
        CFRelease(uuid);
    }
    DLog(@"- EXIT");
}


- (void)addSavedDevice:(CFUUIDRef)uuid
{
	NSArray			*storedDevices	= [[NSUserDefaults standardUserDefaults] arrayForKey:@"StoredDevices"];
	NSMutableArray	*newDevices		= nil;
	CFStringRef		uuidString		= NULL;

    DLog(@"- ENTRY");

	if (![storedDevices isKindOfClass:[NSArray class]]) {
        DLog(@"Can't find/create an array to store the uuid");
        return;
    }

    newDevices = [NSMutableArray arrayWithArray:storedDevices];

    uuidString = CFUUIDCreateString(NULL, uuid);
    if (uuidString) {
        [newDevices addObject:(__bridge NSString*)uuidString];
        CFRelease(uuidString);
    }
    /* Store */
    [[NSUserDefaults standardUserDefaults] setObject:newDevices forKey:@"StoredDevices"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    DLog(@"- EXIT");
}


- (void)removeSavedDevice:(CFUUIDRef)uuid
{
	NSArray			*storedDevices	= [[NSUserDefaults standardUserDefaults] arrayForKey:@"StoredDevices"];
	NSMutableArray	*newDevices		= nil;
	CFStringRef		uuidString		= NULL;

    DLog(@"- ENTRY");
	if ([storedDevices isKindOfClass:[NSArray class]]) {
		newDevices = [NSMutableArray arrayWithArray:storedDevices];

		uuidString = CFUUIDCreateString(NULL, uuid);
		if (uuidString) {
			[newDevices removeObject:(__bridge NSString*)uuidString];
            CFRelease(uuidString);
        }
		/* Store */
		[[NSUserDefaults standardUserDefaults] setObject:newDevices forKey:@"StoredDevices"];
		[[NSUserDefaults standardUserDefaults] synchronize];
	}
    DLog(@"- EXIT");
}

- (void)clearDevices
{
    DLog(@"");
    [self.foundPeripherals removeAllObjects];

    [[NSNotificationCenter defaultCenter] postNotificationName:kNOTIFICATION_ALL_DEVICES_REMOVED object:nil];

    //    for (LeTemperatureAlarmService	*service in connectedServices) {
    //        [service reset];
    //    }
    //    [connectedServices removeAllObjects];
}


#pragma mark --- PUBLIC Instance Methods

- (void)startScanningForListOfUUIDs:(NSArray *)uuidList
{
    [self.foundPeripherals removeAllObjects];

    NSDictionary *options = [NSDictionary dictionaryWithObject:[NSNumber numberWithBool:NO] forKey:CBCentralManagerScanOptionAllowDuplicatesKey];
    if(uuidList == nil)
    {
        DLog(@"- startScan for ALL DEVICES");
        [self.cbcManager scanForPeripheralsWithServices:[NSArray array] options:options];
    }
    else
    {
        DLog(@"- startScan for [%@] DEVICEs", uuidList);
        [self.cbcManager scanForPeripheralsWithServices:uuidList options:options];
    }

    // NOW SCANNING UNTIL STOPPED!
    DLog(@"- NOTIFY: SCAN Started...");
    [[NSNotificationCenter defaultCenter] postNotificationName:kNOTIFICATION_DEVICE_SCAN_STARTED object:nil];
}

- (void) startScanningForUUIDString:(NSString *)uuidString
{
    self.searchUUID = uuidString;

    if(uuidString == nil)
    {
        DLog(@"- startScan for ALL DEVICES");
        [self startScanningForListOfUUIDs:nil];
    }
    else
    {
        DLog(@"- startScan for [%@] DEVICE", uuidString);
        NSArray	*uuidArray = [NSArray arrayWithObject:[CBUUID UUIDWithString:uuidString]];
        [self startScanningForListOfUUIDs:uuidArray];
    }
}

- (void) stopScanning
{
    DLog(@"");
    [self.cbcManager stopScan];
    // NOW STOPPING SCAN!
    DLog(@"- NOTIFY: SCAN Stopped...");
    [[NSNotificationCenter defaultCenter] postNotificationName:kNOTIFICATION_DEVICE_SCAN_STOPPED object:nil];
}

- (void) connectPeripheral:(CBPeripheral*)peripheral
{
    self.cbpConnectedDevice = peripheral;

    if(![self.cbpConnectedDevice isConnected])
    {
        [self.foundServices removeAllObjects];
        [self.foundIncludedServices removeAllObjects];
        [self.foundCharacteristics removeAllObjects];
        [self.dctFoundDescriptors removeAllObjects];
        self.cbpConnectedDevice.delegate = self; // we want to receive callbacks from this device!!

        DLog(@"- Connecting to Device: %@", self.cbpConnectedDevice);

        [self.cbcManager connectPeripheral:self.cbpConnectedDevice options:[NSDictionary dictionaryWithObject:[NSNumber numberWithBool:YES] forKey:CBConnectPeripheralOptionNotifyOnDisconnectionKey]];
    }
    else
    {
        DLog(@"- ERROR already connected to Device: %@", self.cbpConnectedDevice);
    }
}

- (void) disconnectPeripheral:(CBPeripheral*)peripheral
{
    DLog(@"- Device: %@", peripheral);
    if(peripheral.isConnected)
    {
        [self.cbcManager cancelPeripheralConnection:peripheral];
    }
    else
    {
        // not connected fake a disconnection so app can believe this happened...
        [[NSNotificationCenter defaultCenter] postNotificationName:kNOTIFICATION_DISCONNECT_BLE_DEVICE_SUCCESS object:peripheral];
    }
}

- (void)exploreConnectedPeripheralService:(CBService *)service
{
    // includes are already explored, let's find out rest...
    DLog(@"- discover characteristics for: %@", service.UUID.str);
    [self.cbpConnectedDevice discoverCharacteristics:nil forService:service];
}


#pragma mark --- PRIVATE (Utility) Methods

-(NSString *)descriptionOfError:(NSError *)error
{
    NSString *strErrorInd = @"";
    if(error != nil)
    {
        strErrorInd = [NSString stringWithFormat:@"ERROR: %@",[error localizedDescription]];
    }
    return strErrorInd;
}

- (void)startScanningForIncludedServices
{
    DLog(@"");
    m_bDiscoveringIncludedServices = YES;
    m_nNextServiceToCheck = 0;
    m_nMaxServices = [self.foundServices count];

    [self continueScanForIncludedServices];
}

- (void)continueScanForIncludedServices
{
    if(m_bDiscoveringIncludedServices)
    {
        DLog(@"- discover included services for svc #%d", m_nNextServiceToCheck);
        [self.cbpConnectedDevice discoverIncludedServices:nil forService:[self.foundServices objectAtIndex:m_nNextServiceToCheck++]];
        if(m_nNextServiceToCheck == m_nMaxServices)
        {
            DLog(@"- Preceeding is LAST Request!");
            m_bDiscoveringIncludedServices = NO;
        }
    }
    else
    {
        DLog(@"-[code??] no point, we are already done! ");
    }
}

- (void)scanForServiceCharacteristics
{
    DLog(@"");
    m_bDiscoveringCharacteristics = YES;
    m_nNextServiceCharacteristicToCheck = 0;
    m_nMaxServices = [self.foundIncludedServices count];

    [self continueScanForServiceCharacteristics];
}

- (void)continueScanForServiceCharacteristics
{
    if(m_bDiscoveringCharacteristics)
    {
        DLog(@"- discover characteristics for svc #%d", m_nNextServiceCharacteristicToCheck);
        [self.cbpConnectedDevice discoverCharacteristics:nil forService:[self.foundIncludedServices objectAtIndex:m_nNextServiceCharacteristicToCheck++]];
        if(m_nNextServiceCharacteristicToCheck == m_nMaxServices)
        {
            DLog(@"- Preceeding is LAST Request!");
            m_bDiscoveringCharacteristics = NO;
        }
    }
    else
    {
        DLog(@"-[code??] no point, we are already done! ");
    }
}

- (void)scanForCharacteristicDescriptors
{
    DLog(@"");
    m_bDiscoveringDescriptors = YES;
    m_nNextCharacteristicToCheck = 0;

    [self continueScanForCharacteristicDescriptors];
}

- (void)continueScanForCharacteristicDescriptors
{
    if(m_bDiscoveringDescriptors)
    {
        DLog(@"- discover descriptors for characteristic #%d", m_nNextCharacteristicToCheck);
        [self.cbpConnectedDevice discoverDescriptorsForCharacteristic:[self.foundCharacteristics objectAtIndex:m_nNextCharacteristicToCheck++]];
        if(m_nNextCharacteristicToCheck == [self.foundCharacteristics count])
        {
            DLog(@"- Preceeding is LAST Request!");
            m_bDiscoveringDescriptors = NO;
        }
    }
    else
    {
        DLog(@"-[code??] no point, we are already done! ");
    }
}


#pragma mark - PROTOCOL <CBCentralManagerDelegate> Methods

- (void)centralManagerDidUpdateState:(CBCentralManager *)central
{
    const CBCentralManagerState kcmsNeverSetState = (CBCentralManagerState)-1;

    static CBCentralManagerState s_cmsPreviousState = kcmsNeverSetState;

    // read once so we don't accidentally incorporate a state-change
    CBCentralManagerState cmsNewState = [central state];

	switch (cmsNewState) {
		case CBCentralManagerStatePoweredOff:
		{
            DLog(@">>>  CBCentralManagerStatePoweredOff  <<<");
            [self clearDevices];

			/* Tell user to power ON BT for functionality, but not on first run - the Framework will alert in that instance. */
            if (s_cmsPreviousState != kcmsNeverSetState) {
                //[discoveryDelegate discoveryStatePoweredOff];
            }
			break;
		}

		case CBCentralManagerStateUnauthorized:
		{
            DLog(@">>>  CBCentralManagerStateUnauthorized  <<<");
			/* Tell user the app is not allowed. */
			break;
		}

		case CBCentralManagerStateUnknown:
		{
            DLog(@">>>  CBCentralManagerStateUnknown  <<<");
			/* Bad news, let's wait for another event. */
			break;
		}
		case CBCentralManagerStateUnsupported:
		{
            DLog(@">>>  CBCentralManagerStateUnsupported  <<<");
			/* Bad news, let's wait for another event. */
			break;
		}

		case CBCentralManagerStatePoweredOn:
		{
            DLog(@">>>  CBCentralManagerStatePoweredOn  <<<");
			m_bPendingInit = NO;
			[self loadSavedDevices];
			[central retrieveConnectedPeripherals];

            // we're powered-on, start looking for devices...
            DLog(@"*** Request SCAN")
            [self startScanningForUUIDString:self.searchUUID];
			break;
		}

		case CBCentralManagerStateResetting:
		{
            DLog(@">>>  CBCentralManagerStateResetting  <<<");
			[self clearDevices];

			m_bPendingInit = YES;
			break;
		}
        default:
        {
            DLog(@">>>  ?? Huh ?? case not added? [%d]  <<<", cmsNewState);
        }
	}

    s_cmsPreviousState = cmsNewState;
}

- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI
{
    DLog(@"- NAME=[%@], UUID=[%@], RSSI=%d, advert=[%@], periph=[%@]", peripheral.name, peripheral.UUIDstr, [RSSI integerValue], advertisementData, [peripheral description]);
    peripheral.latestRSSI = RSSI;

    if (![self.foundPeripherals containsObject:peripheral]) {
		[self.foundPeripherals addObject:peripheral];
        DLog(@"-(INTRNL) add peripheral=%@", peripheral.UUIDstr);
        [[NSNotificationCenter defaultCenter] postNotificationName:kNOTIFICATION_ADD_BLE_DEVICE object:peripheral];
    }
}

- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral
{
    DLog(@"*** UUID=[%@]", peripheral.UUIDstr);
    [[NSNotificationCenter defaultCenter] postNotificationName:kNOTIFICATION_CONNECT_BLE_DEVICE_SUCCESS object:peripheral];

    DLog(@"- discover services");
    [peripheral discoverServices:nil];
}

- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    DLog(@"*** UUID=[%@] - Attempted connection to peripheral %@ failed: %@", peripheral.UUIDstr, [peripheral name], [error localizedDescription]);
    [[NSNotificationCenter defaultCenter] postNotificationName:kNOTIFICATION_CONNECT_BLE_DEVICE_FAILURE object:peripheral];
}

- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    if (error != nil) {
        DLog(@"*** UUID=[%@] with ERROR", peripheral.UUIDstr);
        NSArray *disconnectFailureArray = [NSArray arrayWithObjects:error, peripheral, nil];
        [[NSNotificationCenter defaultCenter] postNotificationName:kNOTIFICATION_DISCONNECT_BLE_DEVICE_FAILURE object:disconnectFailureArray];

        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Disconnect Error", @"") message:error.localizedDescription delegate:self cancelButtonTitle:NSLocalizedString(@"OK",@"") otherButtonTitles: nil];
        [alert show];
    }
    else {
        DLog(@"*** UUID=[%@] SUCCESS", peripheral.UUIDstr);
        [[NSNotificationCenter defaultCenter] postNotificationName:kNOTIFICATION_DISCONNECT_BLE_DEVICE_SUCCESS object:peripheral];

        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Disconnected", @"") message:peripheral.name delegate:self cancelButtonTitle:NSLocalizedString(@"OK",@"") otherButtonTitles: nil];
        [alert show];
    }
    DLog(@"*** Restart SCAN")
    [self startScanningForUUIDString:self.searchUUID];
}


#pragma mark - PROTOCOL <CBPeripheralDelegate> Methods

- (void)peripheralDidUpdateName:(CBPeripheral *)peripheral
{
    DLog(@"*** UUID=[%@]", peripheral.UUIDstr);

    [[NSNotificationCenter defaultCenter] postNotificationName:kNOTIFICATION_DEVICE_UPDATED_NAME object:peripheral];
}

- (void)peripheralDidInvalidateServices:(CBPeripheral *)peripheral
{
    DLog(@"*** UUID=[%@]", peripheral.UUIDstr);

    [[NSNotificationCenter defaultCenter] postNotificationName:kNOTIFICATION_DEVICE_INVALIDATED_SERVICES object:peripheral];
}

- (void)peripheralDidUpdateRSSI:(CBPeripheral *)peripheral error:(NSError *)error
{
#ifdef DEBUG
    NSString *strErrorInd = [self descriptionOfError:error];
#endif
    DLog(@"- UUID=%@ %@", peripheral.UUIDstr, strErrorInd);

    ISPPeripheralTriadParameter *infoObject = [[ISPPeripheralTriadParameter alloc] initWithPeripheral:peripheral parameter:nil error:error];
    [[NSNotificationCenter defaultCenter] postNotificationName:kNOTIFICATION_DEVICE_UPDATED_RSSI object:infoObject];
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error
{
#ifdef DEBUG
    NSString *strErrorInd = [self descriptionOfError:error];
#endif
    DLog(@"- UUID=%@ %@", peripheral.UUIDstr, strErrorInd);

    ISPPeripheralTriadParameter *infoObject = [[ISPPeripheralTriadParameter alloc] initWithPeripheral:peripheral parameter:nil error:error];
    [[NSNotificationCenter defaultCenter] postNotificationName:kNOTIFICATION_DEVICE_DISCOVERED_SERVICES object:infoObject];

    // build unique internal list of services found...
    for (CBService *newService in peripheral.services) {
        newService.containingService = nil; // mark as top level
        if (![self.foundServices containsObject:newService]) {
            [self.foundServices addObject:newService];
            DLog(@"-(INTRNL) add service=%@", newService.UUID.str);
        }
    }

    // now check each for included services as well!
    self.foundIncludedServices = [NSMutableArray arrayWithArray:self.foundServices];
    [self startScanningForIncludedServices];
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverIncludedServicesForService:(CBService *)service error:(NSError *)error
{
#ifdef DEBUG
    NSString *strErrorInd = [self descriptionOfError:error];
#endif
    DLog(@"- UUID=%@ %@", service.UUID.str, strErrorInd);

    ISPPeripheralTriadParameter *infoObject = [[ISPPeripheralTriadParameter alloc] initWithPeripheral:peripheral parameter:service error:error];
    [[NSNotificationCenter defaultCenter] postNotificationName:kNOTIFICATION_DEVICE_DISCOVERED_INCLUDED_SERVICES object:infoObject];

    BOOL bFoundNewService = NO;

    // build unique internal list of services found...
    for (CBService *newService in service.includedServices) {
        newService.containingService = service;
        if (![self.foundIncludedServices containsObject:newService]) {
            [self.foundIncludedServices addObject:newService];
            bFoundNewService = YES;
            DLog(@"-(INTRNL) add included-service=%@", newService.UUID.str);
        }
    }

    // now continue scan if scan in progress...
    if(m_bDiscoveringIncludedServices)
    {
        DLog(@" -- more to discover...");
        // not finished discovering all... do another...
        [self continueScanForIncludedServices];
    }
    else
    {
        if(bFoundNewService)
        {
            DLog(@"  >>>  rescan due to adds!   <<<");
            [self startScanningForIncludedServices];
        }
        else
        {
            // build dictionary of services found...
            NSMutableDictionary *dctServices = [[NSMutableDictionary alloc] init];
            for (CBService *currService in self.foundIncludedServices) {
                [dctServices setObject:currService forKey:currService.UUID.str];
            }

            // finished with all
            [[NSNotificationCenter defaultCenter] postNotificationName:kNOTIFICATION_DEVICE_SERVICES_DISCOVERED object:[NSDictionary dictionaryWithDictionary:dctServices]];

            // now prescan for characteristics, too
            [self scanForServiceCharacteristics];
        }
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error
{
#ifdef DEBUG
    NSString *strErrorInd = [self descriptionOfError:error];
#endif
    DLog(@"- UUID=%@ %@", service.UUID.str, strErrorInd);

    ISPPeripheralTriadParameter *infoObject = [[ISPPeripheralTriadParameter alloc] initWithPeripheral:peripheral parameter:service error:error];
    [[NSNotificationCenter defaultCenter] postNotificationName:kNOTIFICATION_DEVICE_DISCOVERED_CHARACTERISTICS object:infoObject];

    // build unique internal list of characteristics found...
    for (CBCharacteristic *newCharacteristic in service.characteristics) {
        if (![self.foundCharacteristics containsObject:newCharacteristic]) {
            [self.foundCharacteristics addObject:newCharacteristic];
            DLog(@"-(INTRNL) add characteristic=%@", newCharacteristic.UUID.str);
        }
    }

    // now continue scan if scan in progress...
    if(m_bDiscoveringCharacteristics)
    {
        // not finished discovering all... do another...
        [self continueScanForServiceCharacteristics];
    }
    else
    {
        // build dictionary of characteristics found...
        NSMutableDictionary *dctCharacteristics = [[NSMutableDictionary alloc] init];
        for (CBCharacteristic *currCharacteristic  in self.foundCharacteristics) {
            [dctCharacteristics setObject:currCharacteristic forKey:currCharacteristic.UUID.str];
        }

        // finished with all
        [[NSNotificationCenter defaultCenter] postNotificationName:kNOTIFICATION_DEVICE_CHARACTERISTICS_DISCOVERED object:[NSDictionary dictionaryWithDictionary:dctCharacteristics]];

        // now prescan for characteristic-Descriptors, too
        [self scanForCharacteristicDescriptors];
    }
}

-(void)logDescriptor:(CBDescriptor *)descriptor withKey:(NSString *)descriptorKey
{
    DLog(@"- %@ value=[%@] key:[%@]", descriptor, descriptor.value, descriptorKey);

    // info from CBUUID.h:
    /*!
     *  @const CBUUIDCharacteristicExtendedPropertiesString 0x2900
     *  @discussion The string representation of the UUID for the extended properties descriptor.
     *				The corresponding value for this descriptor is an <code>NSNumber</code> object.
     */


    /*!
     *  @const CBUUIDCharacteristicUserDescriptionString 0x2901
     *  @discussion The string representation of the UUID for the user description descriptor.
     *				The corresponding value for this descriptor is an <code>NSString</code> object.
     */

    /*!
     *  @const CBUUIDClientCharacteristicConfigurationString 0x2902
     *  @discussion The string representation of the UUID for the client configuration descriptor.
     *				The corresponding value for this descriptor is an <code>NSNumber</code> object.
     */

    /*!
     *  @const CBUUIDServerCharacteristicConfigurationString 0x2903
     *  @discussion The string representation of the UUID for the server configuration descriptor.
     *				The corresponding value for this descriptor is an <code>NSNumber</code> object.
     */

    /*!
     *  @const CBUUIDCharacteristicFormatString 0x2904
     *  @discussion The string representation of the UUID for the presentation format descriptor.
     *				The corresponding value for this descriptor is an <code>NSData</code> object.
     */


#ifdef DEBUG
    if([descriptor.UUID.str isEqualToString:CBUUIDCharacteristicExtendedPropertiesString]) {
        // 0x2900: 16-bit (NSNumber) value
        //  http://developer.bluetooth.org/gatt/descriptors/Pages/DescriptorViewer.aspx?u=org.bluetooth.descriptor.gatt.characteristic_extended_properties.xml
        NSNumber *nmFlagBits = descriptor.value;
        if(nmFlagBits != nil)
        {
            NSAssert([nmFlagBits isKindOfClass:[NSNumber class]], @"ERROR not NSNumber value object?!!");
            uint16_t flagBits = [nmFlagBits  shortValue];
            DLog(@"- flag 0x%4X", flagBits);
        }
        else
        {
            DLog(@"- flag [(null)?]");
        }
    }
    else if([descriptor.UUID.str isEqualToString:CBUUIDCharacteristicUserDescriptionString]) {
        // 0x2901: utf8s (NSString) value
        //  http://developer.bluetooth.org/gatt/descriptors/Pages/DescriptorViewer.aspx?u=org.bluetooth.descriptor.gatt.characteristic_user_description.xml
        NSString *strDescription = descriptor.value;
        if(strDescription != nil)
        {
            NSAssert([strDescription isKindOfClass:[NSString class]], @"ERROR not NSString value object?!!");
            DLog(@"- string[%@]", strDescription);
        }
        else
        {
            DLog(@"- string[(null)]");
        }
    }
    else if([descriptor.UUID.str isEqualToString:CBUUIDClientCharacteristicConfigurationString]) {
        // 0x2902: 16-bit (NSNumber) value
        //  http://developer.bluetooth.org/gatt/descriptors/Pages/DescriptorViewer.aspx?u=org.bluetooth.descriptor.gatt.client_characteristic_configuration.xml
        NSNumber *nmFlagBits = descriptor.value;
        if(nmFlagBits != nil)
        {
            NSAssert([nmFlagBits isKindOfClass:[NSNumber class]], @"ERROR not NSNumber value object?!!");
            uint16_t nFlagBits = [nmFlagBits  shortValue];
            DLog(@"- flag 0x%4X", nFlagBits);
        }
        else
        {
            DLog(@"- flag [(null)?]");
        }
    }
    else if([descriptor.UUID.str isEqualToString:CBUUIDServerCharacteristicConfigurationString]) {
        // 0x2903: 16-bit (NSNumber) value [1 flag bit (lsbit): value 0,1]
        //  http://developer.bluetooth.org/gatt/descriptors/Pages/DescriptorViewer.aspx?u=org.bluetooth.descriptor.gatt.server_characteristic_configuration.xml
        if(descriptor.value != nil)
        {
            NSAssert([descriptor.value isKindOfClass:[NSNumber class]], @"ERROR not NSNumber value object?!!");
            NSNumber *nmFlagBits = descriptor.value;
            uint16_t nFlagBits = [nmFlagBits  shortValue];
            DLog(@"- flag 0x%4X", nFlagBits);
        }
        else
        {
            DLog(@"- flag [(null)?]");
        }
    }
    else if([descriptor.UUID.str isEqualToString:CBUUIDCharacteristicFormatString]) {
        // 0x2904: 16-bit (NSData) value
        //  http://developer.bluetooth.org/gatt/descriptors/Pages/DescriptorViewer.aspx?u=org.bluetooth.descriptor.gatt.characteristic_presentation_format.xml
        if(descriptor.value != nil)
        {
            NSAssert([descriptor.value isKindOfClass:[NSData class]], @"ERROR not NSData value object?!!");
            //NSData *daValues = descriptor.value;
            // NOTE: this is a field set: uint8 [value 1-27], int8, uint16, uint8 [value 0,1] and uint16
        }
        else
        {
            DLog(@"- flag [(null)?]");
        }
    }
#endif
}


- (void)peripheral:(CBPeripheral *)peripheral didDiscoverDescriptorsForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
#ifdef DEBUG
    NSString *strErrorInd = [self descriptionOfError:error];
#endif
    DLog(@"- UUID=%@ %@", characteristic.UUID.str, strErrorInd);

    ISPPeripheralTriadParameter *infoObject = [[ISPPeripheralTriadParameter alloc] initWithPeripheral:peripheral parameter:characteristic error:error];
    [[NSNotificationCenter defaultCenter] postNotificationName:kNOTIFICATION_DEVICE_DISCOVERED_CHARACTERISTIC_DESCRIPTORS object:infoObject];

    // build unique internal dictionary of characteristic-descriptors found...
    for (CBDescriptor *newDescriptor in characteristic.descriptors) {
        NSString *strDescriptorKey = [ISPLowEnergyManager keyForDescriptor:newDescriptor ofCharacteristic:characteristic];
        [self logDescriptor:newDescriptor withKey:strDescriptorKey];
        if(newDescriptor.value != NULL)
        {
            if ([self.dctFoundDescriptors objectForKey:strDescriptorKey] == nil) {
                [self.dctFoundDescriptors setObject:newDescriptor forKey:strDescriptorKey];
                DLog(@"-(INTRNL) add descriptor=%@", strDescriptorKey);
            }
        }
    }

    // now continue scan if scan in progress...
    if(m_bDiscoveringDescriptors)
    {
        // not finished discovering all... do another...
        [self continueScanForCharacteristicDescriptors];
    }
    else
    {
        // finished with all
        [[NSNotificationCenter defaultCenter] postNotificationName:kNOTIFICATION_DEVICE_DESCRIPTORS_DISCOVERED object:[NSDictionary dictionaryWithDictionary:self.dctFoundDescriptors]];
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
#ifdef DEBUG
    NSString *strErrorInd = [self descriptionOfError:error];
#endif
    DLog(@"- UUID=%@ %@", characteristic.UUID.str, strErrorInd);

    ISPPeripheralTriadParameter *infoObject = [[ISPPeripheralTriadParameter alloc] initWithPeripheral:peripheral parameter:characteristic error:error];
    [[NSNotificationCenter defaultCenter] postNotificationName:kNOTIFICATION_DEVICE_UPDATED_CHARACTERISTIC_VALUE object:infoObject];
}

- (void)peripheral:(CBPeripheral *)peripheral didWriteValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
#ifdef DEBUG
    NSString *strErrorInd = [self descriptionOfError:error];
#endif
    DLog(@"- UUID=%@ %@", characteristic.UUID.str, strErrorInd);

    ISPPeripheralTriadParameter *infoObject = [[ISPPeripheralTriadParameter alloc] initWithPeripheral:peripheral parameter:characteristic error:error];
    [[NSNotificationCenter defaultCenter] postNotificationName:kNOTIFICATION_DEVICE_WROTE_CHARACTERISTIC_VALUE object:infoObject];
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateNotificationStateForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
#ifdef DEBUG
    NSString *strErrorInd = [self descriptionOfError:error];
#endif
    DLog(@"- UUID=%@ %@", characteristic.UUID.str, strErrorInd);

    ISPPeripheralTriadParameter *infoObject = [[ISPPeripheralTriadParameter alloc] initWithPeripheral:peripheral parameter:characteristic error:error];
    [[NSNotificationCenter defaultCenter] postNotificationName:kNOTIFICATION_DEVICE_UPDATED_CHARACTERISTIC_NOTIF_STATE object:infoObject];
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForDescriptor:(CBDescriptor *)descriptor error:(NSError *)error
{
#ifdef DEBUG
    NSString *strErrorInd = [self descriptionOfError:error];
#endif
    DLog(@"- UUID=%@ %@", descriptor.UUID.str, strErrorInd);

    ISPPeripheralTriadParameter *infoObject = [[ISPPeripheralTriadParameter alloc] initWithPeripheral:peripheral parameter:descriptor error:error];
    [[NSNotificationCenter defaultCenter] postNotificationName:kNOTIFICATION_DEVICE_UPDATED_DESCRIPTOR_VALUE object:infoObject];
}

- (void)peripheral:(CBPeripheral *)peripheral didWriteValueForDescriptor:(CBDescriptor *)descriptor error:(NSError *)error
{
#ifdef DEBUG
    NSString *strErrorInd = [self descriptionOfError:error];
#endif
    DLog(@"- UUID=%@ %@", descriptor.UUID.str, strErrorInd);
    
    ISPPeripheralTriadParameter *infoObject = [[ISPPeripheralTriadParameter alloc] initWithPeripheral:peripheral parameter:descriptor error:error];
    [[NSNotificationCenter defaultCenter] postNotificationName:kNOTIFICATION_DEVICE_WROTE_DESCRIPTOR_VALUE object:infoObject];
}


@end
