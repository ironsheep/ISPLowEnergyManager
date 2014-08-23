//
//  ISPLowEnergyManager.m
//  ISPLowEnergyManager
//
//  Created by Stephen M Moraco on 03/12/13.
//  Copyright (c) 2013 Iron Sheep Productions, LLC. All rights reserved.
//

#import "ISPLowEnergyManager.h"
#import "CBPeripheral+Methods.h"
#import "CBService+Methods.h"
#import "ISPPeripheralTriadParameter.h"
#import "CustomAlertView.h"
#import "ISPNotificationConsts.h"


#pragma mark CLASS ISPLowEnergyManager - PRIVATE Interface

@interface ISPLowEnergyManager () {
    
}


#pragma mark --> PRIVATE PROPERTIES

@property (strong, nonatomic) CBCentralManager  *cbcManager;
@property (strong, nonatomic) CBPeripheral      *cbpConnectedDevice;
@property (strong, nonatomic) NSMutableArray    *foundPeripherals;
@property (strong, nonatomic) NSMutableArray	*foundServices;
@property (strong, nonatomic) NSMutableArray	*foundCharacteristics;
@property (strong, nonatomic) NSMutableArray	*foundDescriptors;
@property (strong, nonatomic) NSTimer *scanTimer;


//#pragma mark --> PRIVATE Interface-builder Outlet Properties

//#pragma mark --> PRIVATE Interface-builder Action Methods

#pragma mark --> PRIVATE (Utility) Methods

- (void)loadSavedDevices;
- (void)addSavedDevice:(CFUUIDRef)uuid;
- (void)removeSavedDevice:(CFUUIDRef)uuid;

- (void)clearDevices;

- (NSString *)descriptionOfError:(NSError *)error;

- (void)startScanningForIncludedServicesWithCount:(NSInteger)count;
- (void)continueScanForIncludedServices;

- (void)scanForServiceCharacteristics;
- (void)continueScanForServiceCharacteristics;

@end


#pragma mark - CLASS ISPLowEnergyManager - Implemention

@implementation ISPLowEnergyManager {
	BOOL    m_bPendingInit;
    NSUInteger m_nMaxServices;
    BOOL m_bDiscoveringIncludedServices;
    NSUInteger m_nNextServiceToCheck;
    BOOL m_bDiscoveringCharacteristics;
    NSUInteger m_nNextServiceCharacteristicsToCheck;
    BOOL m_bIsScanningEnabled;
    CBCentralManagerState m_cmsPreviousState;
}

#pragma mark --> PUBLIC Property Synthesis Overrides

- (NSArray *)peripherals
{
    return self.foundPeripherals;
}


//#pragma mark --> PRIVATE Property Synthesis Overrides

#pragma mark --> CLASS (Static) Methods

+ (id) sharedInstance
{
	static ISPLowEnergyManager	*this	= nil;

	if (!this) {
        DLog(@"");
		this = [[ISPLowEnergyManager alloc] init];
    }

	return this;
}


//#pragma mark --> PUBLIC Property Overrides

#pragma mark --> PUBLIC Instance Methods

const NSTimeInterval ktiDefaultDurationInSeconds = 1.0;
const NSUInteger knDefaultNumberOfDevicesToLocate = 1;


- (id) init
{
    self = [super init];
    if (self) {
        DLog(@"- self=[%@]", self);
		m_bPendingInit = YES;
		self.cbcManager = [[CBCentralManager alloc] initWithDelegate:self queue:dispatch_get_main_queue()];

        self.searchUUID = nil;   // locate any devices you can hear
        self.numberOfDevicesToLocate = knDefaultNumberOfDevicesToLocate;
        self.searchDurationInSeconds = ktiDefaultDurationInSeconds;

        m_bIsScanningEnabled = NO;

        m_cmsPreviousState = kcmsNeverSetState;

		self.foundPeripherals = [[NSMutableArray alloc] init];
		self.foundServices = [[NSMutableArray alloc] init];
		self.foundCharacteristics = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void) dealloc
{
    DLog(@"- self=[%@]", self);

    // We are a singleton and as such, dealloc shouldn't be called.
    NSAssert(false, @"dealloc should NOT be called on singleton!!!");
}


- (void)enableScanningWhenReady
{
    m_bIsScanningEnabled = YES;
    if(m_cmsPreviousState == CBCentralManagerStatePoweredOn) {
        // we're powered-on, start looking for devices...
        DLog(@"*** Request SCAN")
        [self startScanningForUUIDString:self.searchUUID];
    }
}

- (void) startScanningForUUIDString:(NSString *)uuidString
{
    [self clearDevices]; // with notification!
    
    self.searchUUID = uuidString;

    [self.scanTimer invalidate];    // just to be safe!
	self.scanTimer = [NSTimer scheduledTimerWithTimeInterval:self.searchDurationInSeconds target:self selector:@selector(handleExpirationOfTimer:) userInfo:nil repeats:NO];

    NSDictionary *options = [NSDictionary dictionaryWithObject:[NSNumber numberWithBool:NO] forKey:CBCentralManagerScanOptionAllowDuplicatesKey];
    if(uuidString == nil)
    {
        DLog(@"- startScan for ALL DEVICES");
        [self.cbcManager scanForPeripheralsWithServices:[NSArray array] options:options];
    }
    else
    {
        DLog(@"- startScan for [%@] DEVICES", uuidString);
        NSArray	*uuidArray = [NSArray arrayWithObject:[CBUUID UUIDWithString:uuidString]];
        [self.cbcManager scanForPeripheralsWithServices:uuidArray options:options];
    }

    // NOW SCANNING UNTIL STOPPED!
    [[NSNotificationCenter defaultCenter] postNotificationName:kNOTIFICATION_DEVICE_SCAN_STARTED object:nil];
}

- (void) stopScanning
{
    DLog(@"");
    [self.cbcManager stopScan];
    // NOW STOPPING SCAN!
    [[NSNotificationCenter defaultCenter] postNotificationName:kNOTIFICATION_DEVICE_SCAN_STOPPED object:self.foundPeripherals];
}

- (void) connectPeripheral:(CBPeripheral*)peripheral
{
    DLog(@"- ENTRY");
    self.cbpConnectedDevice = peripheral;

    if(![self.cbpConnectedDevice isConnected])
    {
        DLog(@"  -- remove services/characteristics, then re-get");
        [self.foundServices removeAllObjects];
        [self.foundCharacteristics removeAllObjects];
        self.cbpConnectedDevice.delegate = self; // we want to receive callbacks from this device!!
        
        DLog(@"  -- Device: %@", self.cbpConnectedDevice);
        
        [self.cbcManager connectPeripheral:self.cbpConnectedDevice options:[NSDictionary dictionaryWithObject:[NSNumber numberWithBool:YES] forKey:CBConnectPeripheralOptionNotifyOnDisconnectionKey]];
    }
    else
    {
        DLog(@"  -- ERROR already connected to Device: %@", self.cbpConnectedDevice);
    }
    DLog(@"- EXIT");
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

- (NSNumber *)rssiForPeripheral:(CBPeripheral*)peripheral
{
    NSNumber *nuLatestRSSI = nil;
    if(peripheral.RSSI == nil)
    {
        nuLatestRSSI = peripheral.latestRSSI;
    }
    else
    {
        nuLatestRSSI = peripheral.RSSI;
    }
    DLog(@"- [%@]", nuLatestRSSI);
    return nuLatestRSSI;
}

#pragma mark --> PRIVATE (Utility) Methods

-(NSString *)descriptionOfError:(NSError *)error
{
    NSString *strErrorInd = @"";
    if(error != nil)
    {
        strErrorInd = [NSString stringWithFormat:@"ERROR(%d): %@", error.code, [error localizedDescription]];
    }
    return strErrorInd;
}

- (void)startScanningForIncludedServicesWithCount:(NSInteger)count
{
    DLog(@"- count=%d", count);
    m_nMaxServices = count;
    m_bDiscoveringIncludedServices = YES;
    m_nNextServiceToCheck = 0;

    [self continueScanForIncludedServices];
}

- (void)continueScanForIncludedServices
{
    DLog(@"- ENTRY");
    if(m_bDiscoveringIncludedServices)
    {
        if(self.foundServices != nil && self.foundServices.count > 0)
        {
            CBService *svcNext = [self.foundServices objectAtIndex:m_nNextServiceToCheck++];
            DLog(@"- discover included services for svc #%lu of %d: [%@]", (unsigned long)m_nNextServiceToCheck, self.foundServices.count, svcNext);
            [self.cbpConnectedDevice discoverIncludedServices:nil forService:svcNext];
            DLog(@"  -- is last?");
            if(m_nNextServiceToCheck == m_nMaxServices)
            {
                DLog(@"- Preceeding is LAST Request!");
                m_bDiscoveringIncludedServices = NO;
            }
        }
        else
        {
            DLog(@"- ?? No Services ??");
        }
    }
    DLog(@"- EXIT");
}

- (void)scanForServiceCharacteristics
{
    DLog(@"");
    m_bDiscoveringCharacteristics = YES;
    m_nNextServiceCharacteristicsToCheck = 0;

    [self continueScanForServiceCharacteristics];
}

- (void)continueScanForServiceCharacteristics
{
    if(m_bDiscoveringCharacteristics)
    {
        DLog(@"- discover characteristics for svc #%lu", (unsigned long)m_nNextServiceCharacteristicsToCheck);
        [self.cbpConnectedDevice discoverCharacteristics:nil forService:[self.foundServices objectAtIndex:m_nNextServiceCharacteristicsToCheck++]];
        if(m_nNextServiceCharacteristicsToCheck == m_nMaxServices)
        {
            DLog(@"- Preceeding is LAST Request!");
            m_bDiscoveringCharacteristics = NO;
        }
    }
}

#pragma mark ---> (Device cache methods)

- (void)loadSavedDevices
{
    DLog(@"- ENTRY");
	NSArray	*storedDevicesAr	= [[NSUserDefaults standardUserDefaults] arrayForKey:@"StoredDevices"];

	if (![storedDevicesAr isKindOfClass:[NSArray class]]) {
        DLog(@"  -- No stored array to load");
    }
    else
    {
        DLog(@"  -- Loaded [%@]", storedDevicesAr);
        for (id deviceUUIDString in storedDevicesAr) {

            if (![deviceUUIDString isKindOfClass:[NSString class]])
                continue;

            CFUUIDRef uuid = CFUUIDCreateFromString(NULL, (CFStringRef)deviceUUIDString);
            if (!uuid)
                continue;

            [self.cbcManager retrievePeripherals:[NSArray arrayWithObject:(__bridge id)uuid]];
            CFRelease(uuid);
        }
    }

    DLog(@"- EXIT");
}


- (void)addSavedDevice:(CFUUIDRef)uuid
{
	NSArray			*storedDevicesAr	= [[NSUserDefaults standardUserDefaults] arrayForKey:@"StoredDevices"];
	NSMutableArray	*updatedDevicesAr	= nil;
	CFStringRef		uuidString		= NULL;

    DLog(@"- ENTRY");

	if (![storedDevicesAr isKindOfClass:[NSArray class]]) {
        DLog(@"  -- Can't find/create an array to store the uuid");
    }
    else
    {
        updatedDevicesAr = [NSMutableArray arrayWithArray:storedDevicesAr];

        uuidString = CFUUIDCreateString(NULL, uuid);
        if (uuidString) {
            [updatedDevicesAr addObject:(__bridge NSString*)uuidString];
            CFRelease(uuidString);
        }
        /* Store */
        DLog(@"  -- stored device list [%@]", updatedDevicesAr);
        [[NSUserDefaults standardUserDefaults] setObject:updatedDevicesAr forKey:@"StoredDevices"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }

    DLog(@"- EXIT");
}


- (void)removeSavedDevice:(CFUUIDRef)uuid
{
	NSArray			*storedDevicesAr	= [[NSUserDefaults standardUserDefaults] arrayForKey:@"StoredDevices"];
	NSMutableArray	*updatedDevicesAr		= nil;
	CFStringRef		uuidString		= NULL;

    DLog(@"- ENTRY");
	if (![storedDevicesAr isKindOfClass:[NSArray class]]) {
        DLog(@"  -- Can't find/create an array to store the uuid");
    }
    else
    {
		updatedDevicesAr = [NSMutableArray arrayWithArray:storedDevicesAr];

		uuidString = CFUUIDCreateString(NULL, uuid);
		if (uuidString) {
			[updatedDevicesAr removeObject:(__bridge NSString*)uuidString];
            CFRelease(uuidString);
        }
		/* Store */
        DLog(@"  -- rewrite updated device list [%@]", updatedDevicesAr);
		[[NSUserDefaults standardUserDefaults] setObject:updatedDevicesAr forKey:@"StoredDevices"];
		[[NSUserDefaults standardUserDefaults] synchronize];
	}
    DLog(@"- EXIT");
}

- (void)clearDevices
{
    DLog(@"");
    [self.foundPeripherals removeAllObjects];

    [[NSNotificationCenter defaultCenter] postNotificationName:kNOTIFICATION_ALL_DEVICES_REMOVED object:nil];
}


#pragma mark - PROTOCOL <CBCentralManagerDelegate> Methods

const CBCentralManagerState kcmsNeverSetState = (CBCentralManagerState)-1;

- (void)centralManagerDidUpdateState:(CBCentralManager *)central
{

    // read once so we don't accidentally incorporate a state-change
    CBCentralManagerState cmsNewState = [central state];
    
	switch (cmsNewState) {
		case CBCentralManagerStatePoweredOff:
		{
            DLog(@">>>  CBCentralManagerStatePoweredOff  <<<");
           [self clearDevices];

			/* Tell user to power ON BT for functionality, but not on first run - the Framework will alert in that instance. */
            if (m_cmsPreviousState != kcmsNeverSetState) {
                //[discoveryDelegate discoveryStatePoweredOff];
            }
            [[NSNotificationCenter defaultCenter] postNotificationName:kNOTIFICATION_RADIO_POWERED_OFF object:nil];
			break;
		}

		case CBCentralManagerStateUnauthorized:
		{
            DLog(@">>>  CBCentralManagerStateUnauthorized  <<<");
			/* Tell user the app is not allowed. */
            [[NSNotificationCenter defaultCenter] postNotificationName:kNOTIFICATION_BLE_NOT_AUTHORIZED object:nil];
			break;
		}

		case CBCentralManagerStateUnknown:
		{
            DLog(@">>>  CBCentralManagerStateUnknown  <<<");
			/* Bad news, let's wait for another event. */
            [[NSNotificationCenter defaultCenter] postNotificationName:kNOTIFICATION_RADIO_STATE_UNKNOWN object:nil];
			break;
		}
		case CBCentralManagerStateUnsupported:
		{
            DLog(@">>>  CBCentralManagerStateUnsupported  <<<");
			/* Bad news, let's wait for another event. */
            [[NSNotificationCenter defaultCenter] postNotificationName:kNOTIFICATION_RADIO_STATE_UNSUPPORTED object:nil];
			break;
		}

		case CBCentralManagerStatePoweredOn:
		{
            DLog(@">>>  CBCentralManagerStatePoweredOn  <<<");
			m_bPendingInit = NO;
			[self loadSavedDevices];
			[central retrieveConnectedPeripherals];

            if(m_bIsScanningEnabled)
            {
                // we're powered-on, start looking for devices...
                DLog(@"*** Request SCAN")
                [self startScanningForUUIDString:self.searchUUID];
            }
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
            DLog(@">>>  ?? Huh ?? case not added? [%d]  <<<", (int)cmsNewState);
        }
	}

    m_cmsPreviousState = cmsNewState;
}

- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI
{
    DLog(@"- NAME=[%@], UUID=[%@], RSSI=%ld, advert=[%@], periph=[%@]", peripheral.name, peripheral.UUIDstr, (long)[RSSI integerValue], advertisementData, [peripheral description]);
    peripheral.latestRSSI = RSSI;

    if([peripheral.name hasPrefix:@"TI BLE"])
    {
        if (![self.foundPeripherals containsObject:peripheral]) {
            [self.foundPeripherals addObject:peripheral];
            DLog(@"-(INTRNL) add peripheral=%@", peripheral.UUIDstr);
            [[NSNotificationCenter defaultCenter] postNotificationName:kNOTIFICATION_ADD_BLE_DEVICE object:peripheral];
        }
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
    DLog(@"*** UUID=[%@] - Attempted connection to peripheral %@ failed: ERROR(%d) %@", peripheral.UUIDstr, [peripheral name], error.code, [error localizedDescription]);
    [[NSNotificationCenter defaultCenter] postNotificationName:kNOTIFICATION_CONNECT_BLE_DEVICE_FAILURE object:peripheral];
}

- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    if (error != nil) {
        DLog(@"*** UUID=[%@] with ERROR", peripheral.UUIDstr);
        NSArray *disconnectFailureArray = [NSArray arrayWithObjects:error, peripheral, nil];
        [[NSNotificationCenter defaultCenter] postNotificationName:kNOTIFICATION_DISCONNECT_BLE_DEVICE_FAILURE object:disconnectFailureArray];

        //UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Disconnect Error", @"") message:error.localizedDescription delegate:self cancelButtonTitle:NSLocalizedString(@"OK",@"") otherButtonTitles: nil];
        CustomAlertView *alert = [[CustomAlertView alloc] initWithTitle:NSLocalizedString(@"Disconnect Error", @"") message:error.localizedDescription delegate:self cancelButtonTitle:NSLocalizedString(@"OK",@"") otherButtonTitles: nil];
        [alert show];
    }
    else {
        DLog(@"*** UUID=[%@] SUCCESS", peripheral.UUIDstr);
        [[NSNotificationCenter defaultCenter] postNotificationName:kNOTIFICATION_DISCONNECT_BLE_DEVICE_SUCCESS object:peripheral];

        //UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Disconnected", @"") message:peripheral.name delegate:self cancelButtonTitle:NSLocalizedString(@"OK",@"") otherButtonTitles: nil];
        CustomAlertView *alert = [[CustomAlertView alloc] initWithTitle:NSLocalizedString(@"Disconnected", @"") message:peripheral.name delegate:self cancelButtonTitle:NSLocalizedString(@"OK",@"") otherButtonTitles: nil];
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
    DLog(@"- EXIT");
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error
{
#ifdef DEBUG
    NSString *strErrorInd = [self descriptionOfError:error];
#endif
    DLog(@"- ENTRY UUID=%@ %@", peripheral.UUIDstr, strErrorInd);

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
    [self startScanningForIncludedServicesWithCount:[peripheral.services count]];
    DLog(@"- EXIT");
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverIncludedServicesForService:(CBService *)service error:(NSError *)error
{
#ifdef DEBUG
    NSString *strErrorInd = [self descriptionOfError:error];
#endif
    DLog(@"- ENTRY UUID=%@ %@", service.UUID.str, strErrorInd);

    ISPPeripheralTriadParameter *infoObject = [[ISPPeripheralTriadParameter alloc] initWithPeripheral:peripheral parameter:service error:error];
    [[NSNotificationCenter defaultCenter] postNotificationName:kNOTIFICATION_DEVICE_DISCOVERED_INCLUDED_SERVICES object:infoObject];

    BOOL bFoundNewService = NO;

    // build unique internal list of services found...
    for (CBService *newService in service.includedServices) {
        newService.containingService = service;
        if (![self.foundServices containsObject:newService]) {
            [self.foundServices addObject:newService];
            bFoundNewService = YES;
            DLog(@"-(INTRNL) add included-service=%@", newService.UUID.str);
            m_nMaxServices++;
        }
    }

    // now continue scan if scan in progress...
    if(m_bDiscoveringIncludedServices)
    {
        DLog(@"  -- do more...");
        // not finished discovering all... do another...
        [self continueScanForIncludedServices];
    }
    else
    {
        if(bFoundNewService)
        {
            DLog(@"  >>>  rescan due to adds!   <<<");
            [self startScanningForIncludedServicesWithCount:[self.foundServices count]];
        }
        else
        {
            NSMutableDictionary *dctServices = [[NSMutableDictionary alloc] init];
            for (CBService *currService in self.foundServices) {
                [dctServices setObject:currService forKey:currService.UUID.str];
            }
            
            // finished with all
            [[NSNotificationCenter defaultCenter] postNotificationName:kNOTIFICATION_DEVICE_SERVICES_DISCOVERED object:[NSDictionary dictionaryWithDictionary:dctServices]];

            // now prescan for characteristics, too
            [self scanForServiceCharacteristics];
        }
    }
    DLog(@"- EXIT");
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error
{
#ifdef DEBUG
    NSString *strErrorInd = [self descriptionOfError:error];
#endif
    DLog(@"- ENTRY UUID=%@ %@", service.UUID.str, strErrorInd);

    ISPPeripheralTriadParameter *infoObject = [[ISPPeripheralTriadParameter alloc] initWithPeripheral:peripheral parameter:service error:error];
    [[NSNotificationCenter defaultCenter] postNotificationName:kNOTIFICATION_DEVICE_DISCOVERED_CHARACTERISTICS object:infoObject];

    // build unique internal list of services found...
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
        NSMutableDictionary *dctCharacteristics = [[NSMutableDictionary alloc] init];
        for (CBCharacteristic *currCharacteristic  in self.foundCharacteristics) {
            [dctCharacteristics setObject:currCharacteristic forKey:currCharacteristic.UUID.str];
        }

        // finished with all
        [[NSNotificationCenter defaultCenter] postNotificationName:kNOTIFICATION_DEVICE_CHARACTERISTICS_DISCOVERED object:[NSDictionary dictionaryWithDictionary:dctCharacteristics]];
    }
    DLog(@"- EXIT");
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
    DLog(@"- UUID=%@ %@", peripheral.UUIDstr, strErrorInd);

    ISPPeripheralTriadParameter *infoObject = [[ISPPeripheralTriadParameter alloc] initWithPeripheral:peripheral parameter:characteristic error:error];
    [[NSNotificationCenter defaultCenter] postNotificationName:kNOTIFICATION_DEVICE_UPDATED_CHARACTERISTIC_NOTIF_STATE object:infoObject];
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverDescriptorsForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
#ifdef DEBUG
    NSString *strErrorInd = [self descriptionOfError:error];
#endif
    DLog(@"- UUID=%@ %@", peripheral.UUIDstr, strErrorInd);

    ISPPeripheralTriadParameter *infoObject = [[ISPPeripheralTriadParameter alloc] initWithPeripheral:peripheral parameter:characteristic error:error];
    [[NSNotificationCenter defaultCenter] postNotificationName:kNOTIFICATION_DEVICE_DISCOVERED_CHARACTERISTIC_DESCRIPTORS object:infoObject];
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForDescriptor:(CBDescriptor *)descriptor error:(NSError *)error
{
#ifdef DEBUG
    NSString *strErrorInd = [self descriptionOfError:error];
#endif
    DLog(@"- UUID=%@ %@", peripheral.UUIDstr, strErrorInd);

    ISPPeripheralTriadParameter *infoObject = [[ISPPeripheralTriadParameter alloc] initWithPeripheral:peripheral parameter:descriptor error:error];
    [[NSNotificationCenter defaultCenter] postNotificationName:kNOTIFICATION_DEVICE_UPDATED_DESCRIPTOR_VALUE object:infoObject];
}

- (void)peripheral:(CBPeripheral *)peripheral didWriteValueForDescriptor:(CBDescriptor *)descriptor error:(NSError *)error
{
#ifdef DEBUG
    NSString *strErrorInd = [self descriptionOfError:error];
#endif
    DLog(@"- UUID=%@ %@", peripheral.UUIDstr, strErrorInd);

    ISPPeripheralTriadParameter *infoObject = [[ISPPeripheralTriadParameter alloc] initWithPeripheral:peripheral parameter:descriptor error:error];
    [[NSNotificationCenter defaultCenter] postNotificationName:kNOTIFICATION_DEVICE_WROTE_DESCRIPTOR_VALUE object:infoObject];
}

#pragma mark --> PROTOCOL <NSTimerDelegate> Methods

- (void)handleExpirationOfTimer:(NSTimer *)timer
{
    // our timer has ended, we are to be done with listening for devices to show up!
    DLog(@"- timer [%@]", timer);
    [self stopScanning];
}



@end
