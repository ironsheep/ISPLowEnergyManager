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


#pragma mark CLASS LEPBluetoothManager - PRIVATE Interface

typedef enum _ePeripheralQueryState : NSInteger {
    PQS_NOT_SET,
    PQS_IDLE,
    PQS_EXPLORING_ALL_SERVICES,
    PQS_EXPLORING_SERVICES,
    PQS_EXPLORING_INCLUDED_SERVICES,
    PQS_EXPLORING_CHARACTERISTICS,
    PQS_EXPLORING_DESCRIPTORS
} ePeripheralQueryState;


@interface ISPLowEnergyManager () {
    BOOL    m_bPendingInit;
    NSUInteger m_nMaxServices;
    BOOL m_bIsDeviceScanEnabled;
    BOOL m_bIsDeviceScanActive;
    BOOL m_bIsServicesDiscoveryEnabled;
    CBManagerState m_cmsPreviousState;
 }


#pragma mark -- PRIVATE PROPERTIES

@property (strong, nonatomic) CBCentralManager  *cbcManager;
@property (strong, nonatomic) CBPeripheral      *cbpConnectedDevice;
@property (strong, nonatomic) NSMutableArray    *foundPeripherals;
@property (strong, nonatomic) NSMutableArray	*foundServices;
@property (strong, nonatomic) NSMutableArray	*foundCharacteristics;
@property (strong, nonatomic) NSMutableArray	*foundDescriptors;

@property (assign, nonatomic) ePeripheralQueryState	engineState;
@property (copy, nonatomic, readonly) NSString *engineStateString;

@property (strong, nonatomic) NSArray *searchServiceUUIDs;

@property (strong, nonatomic) NSTimer *scanTimer;

@property (strong, nonatomic) NSDictionary *dctCharactersticUUIDsbyServiceUUIDs;

@property (strong, nonatomic) NSDictionary *dctPendingOperationsByCharacteristicUUID;

@property (strong, nonatomic) NSDictionary *dctNeedServiceLoadsByServiceUUIDs;
@property (strong, nonatomic) NSDictionary *dctNeedCharacteristicLoadsByServiceUUIDs;
@property (strong, nonatomic) NSDictionary *dctNeedDescriptorLoadsByCharacteristicUUIDs;

#pragma mark -- PRIVATE (Utility) Methods

// perform all services full discovery
- (void)exploreConnectedPeripheral;
// perform specific-service full discovery
- (void)loadCharacteristicsObjectsForSvcUUID:(NSString *)serviceUUIDString;


// discover services of connected peripheral given specific list of UUID strings
- (void)loadServiceObjectsForSvcUUIDs:(NSArray *)uuids;

- (void)loadSavedDevices;
- (void)addSavedDevice:(CFUUIDRef)uuid;
- (void)removeSavedDevice:(CFUUIDRef)uuid;

- (void)clearDevices;

- (NSString *)descriptionOfError:(NSError *)error;

@end


#pragma mark - CLASS LEPBluetoothManager - Implemention

@implementation ISPLowEnergyManager {

}

@synthesize deviceScanEnable = m_bIsDeviceScanEnabled;    // force use of this instance variable
@synthesize servicesDiscoveryEnable = m_bIsServicesDiscoveryEnabled;    // force use of this instance variable

#pragma mark - CLASS METHODS

+ (id) sharedInstance
{
    static ISPLowEnergyManager	*this	= nil;

    if (!this) {
        DLog(@"");
        this = [[ISPLowEnergyManager alloc] init];
    }

    return this;
}

- (NSString *)engineStateString
{
    NSString *strStateName = @"???";
    switch (self.engineState)
    {
        case PQS_EXPLORING_ALL_SERVICES:
            strStateName = @"EXPLORING_ALL_SERVICES";
            break;

        case PQS_IDLE:
            strStateName = @"IDLE";
            break;

        case PQS_EXPLORING_CHARACTERISTICS:
            strStateName = @"EXPLORING_CHARACTERISTICS";
            break;

        case PQS_EXPLORING_DESCRIPTORS:
            strStateName = @"EXPLORING_DESCRIPTORS";
            break;

        case PQS_EXPLORING_INCLUDED_SERVICES:
            strStateName = @"EXPLORING_INCLUDED_SERVICES";
            break;

        case PQS_EXPLORING_SERVICES:
            strStateName = @"EXPLORING_SERVICES";
            break;

        case PQS_NOT_SET:
            strStateName = @"NOT_SET";
            break;

        default:
            strStateName = @"?unknown?";
            break;
    }
    return strStateName;
}

- (void)setEngineState:(ePeripheralQueryState)engineState
{
    NSString *strPriorValue = self.engineStateString;
    _engineState = engineState;
    DLog(@" *** Engine STATE: (%@ --> %@) ***", strPriorValue, self.engineStateString);
}

#pragma mark -- Instance Methods

const NSTimeInterval ktiDefaultDurationInSeconds = 1.0;
const NSUInteger knDefaultNumberOfDevicesToLocate = 1;  // connect with the first one by default


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

        m_bIsDeviceScanEnabled = NO;
        m_bIsServicesDiscoveryEnabled = NO;
        m_bIsDeviceScanActive = NO;

        self.engineState = PQS_IDLE;

        m_cmsPreviousState = kcmsNeverSetState;

        self.dctNeedServiceLoadsByServiceUUIDs = [NSDictionary dictionary];
        self.dctNeedCharacteristicLoadsByServiceUUIDs = [NSDictionary dictionary];
        self.dctNeedDescriptorLoadsByCharacteristicUUIDs = [NSDictionary dictionary];

        self.dctPendingOperationsByCharacteristicUUID = [NSDictionary dictionary];

        self.foundPeripherals = [NSMutableArray array];
        self.foundServices = [NSMutableArray array];
        self.foundCharacteristics = [NSMutableArray array];
        self.foundDescriptors = [NSMutableArray array];
    }
    return self;
}


- (void) dealloc
{
    DLog(@"- self=[%@]", self);

    // We are a singleton and as such, dealloc shouldn't be called.
    NSAssert(false, @"dealloc should NOT be called on singleton!!!");
}

- (NSArray *)peripherals
{
    return self.foundPeripherals;
}


#pragma mark --- PUBLIC PROPERTY Synthesis Overrides

- (void)setDeviceScanEnable:(BOOL)deviceScanEnable
{
    // record our enable state
    m_bIsDeviceScanEnabled = deviceScanEnable;

    // if we don't know structure of services then setup to do automatic detection
    //   (user passes known device structure as serviceCharacteristics public property)
    m_bIsServicesDiscoveryEnabled = (deviceScanEnable && self.serviceCharacteristics == nil) ? YES : NO;
#ifdef DEBUG
    NSString *strYN = (m_bIsDeviceScanEnabled) ? @"en" : @"DIS";
    NSString *strYNsvcs = (m_bIsServicesDiscoveryEnabled) ? @"en" : @"DIS";
#endif
    DLog(@"- device:%@abled, services:%@abled, ", strYN, strYNsvcs);

    if(m_bIsDeviceScanEnabled)
    {
        if(m_cmsPreviousState == CBManagerStatePoweredOn) {
            // we're powered-on, start looking for devices...
            DLog(@"*** Request SCAN")
            [self startScanningForUUIDString:self.searchUUID];
        }
    }
}


#pragma mark --- PUBLIC Instance Methods
#pragma mark ---- cbManager Methods ----

- (void) startScanningForUUIDString:(NSString *)uuidString
{
    NSAssert(m_bIsDeviceScanActive == NO, @"ERROR: Whoa! why is scan currently active?!!  Already scanning....????");

    m_bIsDeviceScanActive = YES;

    [self.foundPeripherals removeAllObjects];

    self.searchUUID = uuidString;

    [self.scanTimer invalidate];    // just to be safe!
    self.scanTimer = [NSTimer scheduledTimerWithTimeInterval:self.searchDurationInSeconds target:self selector:@selector(handleExpirationOfTimer:) userInfo:nil repeats:NO];

    NSDictionary *options = [NSDictionary dictionaryWithObject:[NSNumber numberWithBool:NO] forKey:CBCentralManagerScanOptionAllowDuplicatesKey];
    if(uuidString == nil)
    {
        DLog(@"- TX startScan for ALL DEVICES");
        [self.cbcManager scanForPeripheralsWithServices:[NSArray array] options:options];
    }
    else
    {
        DLog(@"- TX startScan for [0x%@] DEVICES", uuidString);
        NSArray	*uuidArray = [NSArray arrayWithObject:[CBUUID UUIDWithString:uuidString]];
        [self.cbcManager scanForPeripheralsWithServices:uuidArray options:options];
    }

    // NOW SCANNING UNTIL STOPPED!
    [[NSNotificationCenter defaultCenter] postNotificationName:kNOTIFICATION_DEVICE_SCAN_STARTED object:nil];
}

- (void) stopScanning
{
    if(m_bIsDeviceScanActive)
    {
        DLog(@"- TX stop scan!!!");
        [self.cbcManager stopScan];

        m_bIsDeviceScanActive = NO;
        // NOW STOPPING SCAN!
        [[NSNotificationCenter defaultCenter] postNotificationName:kNOTIFICATION_DEVICE_SCAN_STOPPED object:self.foundPeripherals];
    }
    else
    {
        DLog(@"- [CODE] ?? No scan to stop!! [never scanned?, or stopped already?]");
    }
}

- (void)rescanForPeripherals
{
    // initial scan failed. Start a new scan!
    DLog(@"");
    [self startScanningForUUIDString:self.searchUUID];
}

- (void) connectPeripheral:(CBPeripheral*)peripheral
{
    DLog(@"- ENTRY");

    if(self.cbpConnectedDevice != nil && ![self.cbpConnectedDevice isEqual:peripheral])
    {
        DLog(@"- attempting connect to 2nd device while still connected?!");
        NSAssert(self.cbpConnectedDevice == nil, @"ERROR [CODE] device is already connected!");
    }

    self.cbpConnectedDevice = peripheral;

    if(!self.cbpConnectedDevice.inConnectedState)
    {
        DLog(@"  -- remove services/characteristics, then re-get");
        [self.foundServices removeAllObjects];
        [self.foundCharacteristics removeAllObjects];
        [self.foundDescriptors removeAllObjects];

        self.cbpConnectedDevice.delegate = self; // we want to receive callbacks from this device!!

        DLog(@"  -- TX Device: %@", self.cbpConnectedDevice);

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
    if(peripheral.inConnectedState)
    {
        DLog(@"- TX/StateChg? Device: %@", peripheral);
        [self.cbcManager cancelPeripheralConnection:peripheral];
    }
    else
    {
        // not connected fake a disconnection so app can believe this happened...
        [[NSNotificationCenter defaultCenter] postNotificationName:kNOTIFICATION_DISCONNECT_BLE_DEVICE_SUCCESS object:peripheral];
    }
}

#pragma mark ---- Device cache methods ----

- (void)loadSavedDevices
{
    DLog(@"- ENTRY");
    NSArray	*storedDevicesAr = [[NSUserDefaults standardUserDefaults] arrayForKey:@"StoredDevices"];

    if (![storedDevicesAr isKindOfClass:[NSArray class]]) {
        DLog(@"  -- No stored array to load");
    }
    else
    {
        DLog(@"  -- Loaded [%@]", storedDevicesAr);
        for (id deviceUUIDString in storedDevicesAr) {

            if (![deviceUUIDString isKindOfClass:[NSString class]])
                continue;

            NSUUID *dvcUUID = [[NSUUID alloc] initWithUUIDString:deviceUUIDString];

            // FIXED IOS7->8 FIX
            DLog(@"- TX retrieve peripheral 0x%@", deviceUUIDString);
            [self.cbcManager retrievePeripheralsWithIdentifiers:[NSArray arrayWithObject:dvcUUID]];
        }
    }

    DLog(@"- EXIT");
}


- (void)addSavedDevice:(CFUUIDRef)uuid
{
    NSArray *storedDevicesAr = [[NSUserDefaults standardUserDefaults] arrayForKey:@"StoredDevices"];
    NSMutableArray *updatedDevicesAr = nil;
    CFStringRef uuidString = NULL;

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

#pragma mark ---- cbPeripheral Methods ----

- (void)exploreConnectedPeripheral
{
    DLog(@"- TX discover services:all(nil)");
    DLog(@"  -- svc discovery STARTED");

    self.searchServiceUUIDs = nil;;

    self.engineState = PQS_EXPLORING_ALL_SERVICES;

    [self.cbpConnectedDevice discoverServices:nil];
}

- (NSNumber *)rssiForPeripheral:(CBPeripheral*)peripheral
{
    NSNumber *nuLatestRSSI = peripheral.latestRSSI;
    DLog(@"- [%@]", nuLatestRSSI);
    return nuLatestRSSI;
}

- (NSNumber *)connectedPeripheralRssi
{
    return [self rssiForPeripheral:self.cbpConnectedDevice];
}

- (void)readValueForCharacteristicUUID:(NSString *)characteristicUUIDString
{
    DLog(@"- UUIDString=[0x%@]", characteristicUUIDString.uppercaseString);

    if(![self isLoadedCharacteristicObjectForUUID:characteristicUUIDString])
    {
        // schedule read for this characteristic once we have loaded characteristic for this device
        [self scheduleReadOfCharacteristicWithUUID:characteristicUUIDString];

        // request that the CBCharacteristic object be loaded... (we'll resume after it is)
        [self loadCharacteristicObjectForUUID:characteristicUUIDString];
    }
    else
    {
        // our Characteristics MUST already be present!
        CBCharacteristic *desiredChrstc = [self loadedCharacteristicObjectForUUID:characteristicUUIDString];
        if(desiredChrstc != nil)
        {
            DLog(@"- Characteristic=[%@]", desiredChrstc);
            [self.cbpConnectedDevice readValueForCharacteristic:desiredChrstc];
        }
        else
        {
            DLog(@"ERROR[CODE]: Characteristic [UUID=0x%@] not found!", characteristicUUIDString);
            // our Characteristics MUST already be present!
            NSAssert(false, @"[CODE] ERROR: Characteristic NOT found?!  Bad UUID?  Char's not read from device yet?");
        }
    }
}

- (void)setNotifyValue:(BOOL)bNotifyEnable forCharacteristicUUID:(NSString *)characteristicUUIDString
{
#ifdef DEBUG
    NSString *strNotifyEnable = (bNotifyEnable) ? @"ON" : @"Off";
#endif
    DLog(@"- Set Notify:[%@] for Characteristic=[0x%@]", strNotifyEnable, characteristicUUIDString.uppercaseString);

    if(![self isLoadedCharacteristicObjectForUUID:characteristicUUIDString])
    {
        // schedule notify-set for this characteristic once we have loaded characteristic for this device
        [self scheduleSetNotify:bNotifyEnable forCharacteristicUUID:characteristicUUIDString];

        // request that the CBCharacteristic object be loaded... (we'll resume after it is)
        [self loadCharacteristicObjectForUUID:characteristicUUIDString];
    }
    else
    {
        // our Characteristics MUST already be present!
        CBCharacteristic *desiredChrstc = [self loadedCharacteristicObjectForUUID:characteristicUUIDString];
        if(desiredChrstc != nil)
        {
            DLog(@"- Characteristic=[%@]", desiredChrstc);
            [self.cbpConnectedDevice setNotifyValue:bNotifyEnable forCharacteristic:desiredChrstc];
        }
        else
        {
            DLog(@"ERROR[CODE]: Characteristic [UUID=0x%@] not found!", characteristicUUIDString);
            // our Characteristics MUST already be present!
            NSAssert(false, @"[CODE] ERROR: Characteristic NOT found?!  Bad UUID?  Char's not read from device yet?");
        }
    }
}

- (void)writeValue:(NSData *)data forCharacteristicUUID:(NSString *)characteristicUUIDString type:(CBCharacteristicWriteType)type
{
    DLog(@"- Data=[%@], UUIDString=[%@]", data, characteristicUUIDString.uppercaseString);

    if(![self isLoadedCharacteristicObjectForUUID:characteristicUUIDString])
    {
        // schedule write for this characteristic once we have loaded characteristic for this device
        [self scheduleWriteOfData:data forCharacteristicUUID:characteristicUUIDString type:type];

        // request that the CBCharacteristic object be loaded... (we'll resume after it is)
        [self loadCharacteristicObjectForUUID:characteristicUUIDString];
    }
    else
    {
        // our Characteristics MUST already be present!
        CBCharacteristic *desiredChrstc = [self loadedCharacteristicObjectForUUID:characteristicUUIDString];
        if(desiredChrstc != nil)
        {
            DLog(@"- Characteristic=[%@]", desiredChrstc);
            [self.cbpConnectedDevice writeValue:data forCharacteristic:desiredChrstc type:CBCharacteristicWriteWithResponse];
        }
        else
        {
            DLog(@"ERROR[CODE]: Characteristic [UUID=0x%@] not found!", characteristicUUIDString);
            // our Characteristics MUST already be present!
            NSAssert(false, @"[CODE] ERROR: Characteristic NOT found?!  Bad UUID?  Char's not read from device yet?");
        }
    }
}


#pragma mark --- DELAYED Read/Write subsystem

// --------------------------------------------------------------------------------------------
//  this subsystem consists of a dictionary of arrays whose keys are characteristic UUIDs
//   each array for a given key consists of
//      an entry sequence list of single entry dictionaries
//      where each dictionary has key:{charUUID} value:NSData object (Write) or NSNULL object (read)
//

- (void)scheduleSetNotify:(BOOL)bNotifyEnable forCharacteristicUUID:(NSString *)UUIDString
{
    NSDictionary *dctNextEntry = @{ UUIDString: [NSNumber numberWithBool:bNotifyEnable] };
    NSMutableArray *pendingOperations = [[self.dctPendingOperationsByCharacteristicUUID objectForKey:UUIDString] mutableCopy];
    if(pendingOperations != nil)
    {
        // add to list
        [pendingOperations addObject:dctNextEntry];
    }
    else
    {
        // create NEW list
        pendingOperations = [NSMutableArray arrayWithObject:dctNextEntry];
    }
    NSMutableDictionary *tmpOperations = [self.dctPendingOperationsByCharacteristicUUID mutableCopy];
    [tmpOperations setObject:pendingOperations forKey:UUIDString];
    self.dctPendingOperationsByCharacteristicUUID = tmpOperations;
    DLog(@"- deferred NotifySet for UUID=0x%@, ops-q[%@]", UUIDString, self.dctPendingOperationsByCharacteristicUUID);
}

- (void)scheduleWriteOfData:(NSData *)data forCharacteristicUUID:(NSString *)UUIDString type:(CBCharacteristicWriteType)type
{
    NSDictionary *dctNextEntry = @{ UUIDString: data, @"WriteType": [NSNumber numberWithInt:type] };
    NSMutableArray *pendingOperations = [[self.dctPendingOperationsByCharacteristicUUID objectForKey:UUIDString] mutableCopy];
    if(pendingOperations != nil)
    {
        // add to list
        [pendingOperations addObject:dctNextEntry];
    }
    else
    {
        // create NEW list
        pendingOperations = [NSMutableArray arrayWithObject:dctNextEntry];
    }
    NSMutableDictionary *tmpOperations = [self.dctPendingOperationsByCharacteristicUUID mutableCopy];
    [tmpOperations setObject:pendingOperations forKey:UUIDString];
    self.dctPendingOperationsByCharacteristicUUID = tmpOperations;
    DLog(@"- deferred WRITE to UUID=0x%@, ops-q[%@]", UUIDString, self.dctPendingOperationsByCharacteristicUUID);
}

- (void)scheduleReadOfCharacteristicWithUUID:(NSString *)UUIDString
{
    NSDictionary *dctNextEntry = @{ UUIDString: [NSNull null] };
    NSMutableArray *pendingOperations = [[self.dctPendingOperationsByCharacteristicUUID objectForKey:UUIDString] mutableCopy];
    if(pendingOperations != nil)
    {
        // add to list
        [pendingOperations addObject:dctNextEntry];
    }
    else
    {
        // create NEW list
        pendingOperations = [NSMutableArray arrayWithObject:dctNextEntry];
    }
    NSMutableDictionary *tmpOperations = [self.dctPendingOperationsByCharacteristicUUID mutableCopy];
    [tmpOperations setObject:pendingOperations forKey:UUIDString];
    self.dctPendingOperationsByCharacteristicUUID = tmpOperations;
    DLog(@"- deferred READ from UUID=0x%@, ops-q[%@]", UUIDString, self.dctPendingOperationsByCharacteristicUUID);
}

- (BOOL)havePendingOperationsForCharacteristicUUID:(NSString *)UUIDString
{
    BOOL bFoundPendingOperationsStatus = NO;
    NSArray *pendingOperations = [self.dctPendingOperationsByCharacteristicUUID objectForKey:UUIDString];
    if(pendingOperations != nil)
    {
        bFoundPendingOperationsStatus = YES;
    }
    return bFoundPendingOperationsStatus;
}

- (void)processPendingOperationsForCharacteristicUUID:(NSString *)UUIDString
{
    if([self isLoadedCharacteristicObjectForUUID:UUIDString] && [self havePendingOperationsForCharacteristicUUID:UUIDString])
    {
        // grab the list of TODOs...
        NSArray *pendingOperations = [self.dctPendingOperationsByCharacteristicUUID objectForKey:UUIDString];
        DLog(@"- draining q for UUID=[0x%@], ops-q[%@]", UUIDString, pendingOperations);

        //  remove the pending operations, they're about to be done!
        NSMutableDictionary *tmpPendingOperations = [self.dctPendingOperationsByCharacteristicUUID mutableCopy];
        [tmpPendingOperations removeObjectForKey:UUIDString];
        self.dctPendingOperationsByCharacteristicUUID = tmpPendingOperations;

        // do the TODOs!
        for (NSDictionary *currOperation in pendingOperations) {
            NSNumber *nbrPossWriteType = [currOperation objectForKey:@"WriteType"];
            NSObject *objPossWriteNotifyData = [currOperation objectForKey:UUIDString];
            BOOL bIsWrite = (nbrPossWriteType == nil) ? NO : YES;
            BOOL bIsNotifySet = NO;
            if(!bIsWrite)
            {
                bIsNotifySet = ([objPossWriteNotifyData isEqual:[NSNull null]]) ? NO : YES;
            }
            if(bIsWrite)
            {
                DLog(@"- acting on WRITE to UUID=0x%@", UUIDString);
                // have deferred write, do it now...
                NSData *datWriteValue = (NSData *)objPossWriteNotifyData;
                [self writeValue:datWriteValue forCharacteristicUUID:UUIDString type:nbrPossWriteType.intValue];

            }
            else if(bIsNotifySet)
            {
                DLog(@"- acting on NotifySet for UUID=0x%@", UUIDString);
                // have deferred Notify-Set, do it now...
                NSNumber *nbrNotifyValue = (NSNumber *)objPossWriteNotifyData;
                [self setNotifyValue:nbrNotifyValue.boolValue forCharacteristicUUID:UUIDString];
            }
            else
            {
                DLog(@"- acting on READ from UUID=0x%@", UUIDString);
                // have deferred read, do it now....
                [self readValueForCharacteristicUUID:UUIDString];
            }
        }
    }
}

- (NSArray *)characteristicUUIDsForServiceUUID:(NSString *)serviceUUIDString
{
    NSArray *desiredCharacteristicUUIDs = nil;
    if(self.dctCharactersticUUIDsbyServiceUUIDs != nil)
    {
        desiredCharacteristicUUIDs = [self.dctCharactersticUUIDsbyServiceUUIDs objectForKey:serviceUUIDString];
    }
    else
    {
        NSMutableArray *tmpCharacteristicUUIDs = [NSMutableArray array];
        for (CBCharacteristic *currCharacteristic in self.foundCharacteristics) {
            if([currCharacteristic.service.UUID.UUIDString.uppercaseString isEqualToString:serviceUUIDString.uppercaseString])
            {
                [tmpCharacteristicUUIDs addObject:currCharacteristic.UUID.UUIDString];
            }
        }
        desiredCharacteristicUUIDs = tmpCharacteristicUUIDs;
    }
    NSAssert(desiredCharacteristicUUIDs != nil, @"ERROR [CODE] we should know this service!!!");
    return desiredCharacteristicUUIDs;
}

- (void)handleDeferredOpsForServiceUUID:(NSString *)serviceUUIDString
{
    DLog(@"- svcUUID=[0x%@]", serviceUUIDString);

    NSArray *tmpCharacteristicUUIDs = [self characteristicUUIDsForServiceUUID:serviceUUIDString];
    NSAssert(tmpCharacteristicUUIDs != nil, @"ERROR [CODE] we should know this service!!!");
    if(tmpCharacteristicUUIDs != nil)
    {
        for (NSString *currCharacteristicUUID in tmpCharacteristicUUIDs)
        {
            DLog(@"  -- characteristicUUID=[0x%@]", currCharacteristicUUID);
            [self processPendingOperationsForCharacteristicUUID:currCharacteristicUUID];
        }
    }
}

- (void)setEngineIdle
{
    self.engineState = PQS_IDLE;

    DLog(@"  -- IDLE!  service load Q=[%lu]", (unsigned long)self.dctNeedServiceLoadsByServiceUUIDs.count);
    DLog(@"  --        chrstc load Q=[%lu]", (unsigned long)self.dctNeedCharacteristicLoadsByServiceUUIDs.count);
    DLog(@"  --        dscrptr load Q=[%lu]", (unsigned long)self.dctNeedDescriptorLoadsByCharacteristicUUIDs.count);
    DLog(@"  --        pending ops-q=[%@]", self.dctPendingOperationsByCharacteristicUUID);
    [self checkPendingWork];
}

- (void)checkPendingWork
{
    DLog(@"");

    // if there are more services to explore, do them
    // else if there are more pending operations, do them!

    // if we have any left, do next...
    if(self.dctNeedServiceLoadsByServiceUUIDs.count > 0)
    {
        NSString *nextSvcUUID = [self.dctNeedServiceLoadsByServiceUUIDs.allKeys objectAtIndex:0];
        DLog(@"  -- loading next: svc UUID=[0x%@]", nextSvcUUID);
        [self loadServiceObjectsForSvcUUIDs:[NSArray arrayWithObject:nextSvcUUID]];
    }
    else if(self.dctNeedCharacteristicLoadsByServiceUUIDs.count > 0)
    {
        // then do next load...
        NSString *nextServiceUUID = [self.dctNeedCharacteristicLoadsByServiceUUIDs.allKeys objectAtIndex:0];
        DLog(@"  -- loading next: chrctrstc UUID=[0x%@]", nextServiceUUID);
        [self loadCharacteristicsObjectsForSvcUUID:nextServiceUUID];
    }
    else if(self.dctNeedDescriptorLoadsByCharacteristicUUIDs.count > 0)
    {
        // then do next load...
        NSString *nextCharacteristicUUID = [self.dctNeedDescriptorLoadsByCharacteristicUUIDs.allKeys objectAtIndex:0];
        DLog(@"  -- loading next: dscrptr UUID=[0x%@]", nextCharacteristicUUID);
        [self loadDescriptorObjectsForCharacteristicUUID:nextCharacteristicUUID];
    }
    else if(self.dctPendingOperationsByCharacteristicUUID.count > 0)
    {
        for (CBService *currKnownSvc in self.foundServices) {
            NSString *currSvcUUID = currKnownSvc.UUID.UUIDString;
            DLog(@"  -- checking for deferred work: svc UUID=[0x%@]", currSvcUUID);
            [self handleDeferredOpsForServiceUUID:currSvcUUID];
        }
    }
}

- (BOOL)isScheduledExplorationOfServiceUUID:(NSString *)UUIDString
{
    BOOL bFoundServiceBeingExplored = NO;
    NSObject *foundObject = [self.dctNeedServiceLoadsByServiceUUIDs objectForKey:UUIDString];
    if(foundObject != nil)
    {
        bFoundServiceBeingExplored = YES;
    }
    return bFoundServiceBeingExplored;
}

- (void)removeScheduledExplorationOfServiceUUID:(NSString *)serviceUUIDString
{
    NSObject *foundObject = [self.dctNeedServiceLoadsByServiceUUIDs objectForKey:serviceUUIDString];
    if(foundObject != nil)
    {
        DLog(@"- explored, REMOVE service UUID=[0x%@]", serviceUUIDString);
        NSMutableDictionary *tmpScheduledServiceExplorations = [self.dctNeedServiceLoadsByServiceUUIDs mutableCopy];
        [tmpScheduledServiceExplorations removeObjectForKey:serviceUUIDString];
        self.dctNeedServiceLoadsByServiceUUIDs = tmpScheduledServiceExplorations;
    }
    else
    {
        DLog(@"- ERROR failed to locate and remove explore need for svcUUID=[0x%@]", serviceUUIDString);
    }
}

- (void)removeScheduledExplorationOfServiceCharacteristicsUUID:(NSString *)serviceUUIDString
{
    NSObject *foundObject = [self.dctNeedCharacteristicLoadsByServiceUUIDs objectForKey:serviceUUIDString];
    if(foundObject != nil)
    {
        DLog(@"- chrstcs-loaded, REMOVE service UUID=[0x%@]", serviceUUIDString);
        NSMutableDictionary *tmpPendingCharacteristicLoads = [self.dctNeedCharacteristicLoadsByServiceUUIDs mutableCopy];
        [tmpPendingCharacteristicLoads removeObjectForKey:serviceUUIDString];
        self.dctNeedCharacteristicLoadsByServiceUUIDs = tmpPendingCharacteristicLoads;
    }
    else
    {
        DLog(@"- ERROR failed to locate and remove explore-chrstcs need for svcUUID=[0x%@]", serviceUUIDString);
    }
}

- (void)removeScheduledExplorationOfDescriptorsForCharacteristicUUID:(NSString *)characteristicUUIDString
{
    NSObject *foundObject = [self.dctNeedDescriptorLoadsByCharacteristicUUIDs objectForKey:characteristicUUIDString];
    if(foundObject != nil)
    {
        DLog(@"- dscrptrs-loaded, REMOVE chrstc UUID=[0x%@]", characteristicUUIDString);
        NSMutableDictionary *tmpPendingDescriptorLoads = self.dctNeedDescriptorLoadsByCharacteristicUUIDs.mutableCopy;
        [tmpPendingDescriptorLoads removeObjectForKey:characteristicUUIDString];
        self.dctNeedDescriptorLoadsByCharacteristicUUIDs = tmpPendingDescriptorLoads;
    }
    else
    {
        DLog(@"- ERROR failed to locate and remove explore-dscrptrs need for chrstcUUID=[0x%@]", characteristicUUIDString);
    }
}

- (void)scheduleExplorationOfServiceUUID:(NSString *)UUIDString
{
    NSAssert(![self isLoadedServiceObjectForUUID:UUIDString], @"ERROR[CODE] to get here our CBService object must not be present!");

    // if we haven't scheduled load of characteristics for this service, do so now!
    if(![self isScheduledExplorationOfServiceUUID:UUIDString])
    {
        // record the need....
        NSMutableDictionary *tmpScheduledServiceExplorations = self.dctNeedServiceLoadsByServiceUUIDs.mutableCopy;
        [tmpScheduledServiceExplorations setObject:[NSNull null] forKey:UUIDString];
        self.dctNeedServiceLoadsByServiceUUIDs = tmpScheduledServiceExplorations;
        DLog(@"- requesting service explore for UUID=0x%@", UUIDString);

        // now if we are not doing anything at the moment, actually do it (load the service object)
        if(self.engineState == PQS_IDLE)
        {
            DLog(@"  -- engine is IDLE, doing it now...!")
            [self loadServiceObjectsForSvcUUIDs:@[UUIDString]];
        }
        else
        {
            DLog(@"  -- engine is already BUSY!")
        }
    }
    else
    {
        DLog(@"- !! service already being explored for UUID=0x%@", UUIDString);
    }
}

#pragma mark --- CBService Methods

- (BOOL)isLoadedServiceObjectForUUID:(NSString *)svcUUIDString
{
    BOOL bFoundStatus = NO;
    for (CBService *currService in self.foundServices) {
        if([currService.UUID.UUIDString.uppercaseString isEqualToString:svcUUIDString.uppercaseString])
        {
            bFoundStatus = YES;
            break;  // have answer, abort search
        }
    }
    return bFoundStatus;
}

- (CBService *)loadedServiceObjectForUUID:(NSString *)svcUUIDString
{
    CBService *desiredService = nil;
    for (CBService *currService in self.foundServices) {
        if([currService.UUID.UUIDString.uppercaseString isEqualToString:svcUUIDString.uppercaseString])
        {
            desiredService = currService;
            break;  // outa here! we found it
        }
    }
    return desiredService;
}

- (void)loadServiceObjectsForSvcUUIDs:(NSArray *)uuids
{
    // discover services of connected peripheral given specific list of UUID strings
    //   but only if they are not already loaded...
    NSMutableArray *tmpUUIDs = [NSMutableArray arrayWithCapacity:uuids.count];
    for (NSString *currUUIDString in uuids) {
        if(![self isLoadedServiceObjectForUUID:currUUIDString]) {
            CBUUID *nextUUID = [CBUUID UUIDWithString:currUUIDString];
            [tmpUUIDs addObject:nextUUID];
        }
    }

    if(tmpUUIDs.count > 0)
    {
        self.searchServiceUUIDs = tmpUUIDs;
        DLog(@"  -- looking for [%@]", self.searchServiceUUIDs);

        self.engineState = PQS_EXPLORING_SERVICES;

        DLog(@"- TX discover services:specific[%@]", uuids);
        DLog(@"  -- svc discovery STARTED");
        [self.cbpConnectedDevice discoverServices:tmpUUIDs];
    }
}

- (void)loadServiceObjectsForIncludedSvcUUIDs:(NSArray *)searchUUIDs
{
    DLog(@"- TX discover included services:specific[%@]", searchUUIDs);
    self.engineState = PQS_EXPLORING_INCLUDED_SERVICES;

    for (NSString *currSvcWithIncludesUUIDString in self.servicesWithIncludes) {
        CBService *svcWithIncludes = [self loadedServiceObjectForUUID:currSvcWithIncludesUUIDString];
        if(svcWithIncludes != nil)
        {
            DLog(@"- TX discover included services for svc=[0x%@]", svcWithIncludes);
            [self.cbpConnectedDevice discoverIncludedServices:searchUUIDs forService:svcWithIncludes];
        }
        else
        {
            DLog(@"  -- WARNING can't do this yet... don't have enclosing service!!!");
            [self scheduleExplorationOfServiceUUID:currSvcWithIncludesUUIDString];
            [self setEngineIdle];
        }
    }
}

#pragma mark --- CBCharacteristic Methods

- (BOOL)isLoadedCharacteristicObjectForUUID:(NSString *)characteristicUUIDString
{
    BOOL bFoundStatus = NO;
    for (CBCharacteristic *currCharacteristic in self.foundCharacteristics) {
        if([currCharacteristic.UUID.UUIDString.uppercaseString isEqualToString:characteristicUUIDString.uppercaseString])
        {
            bFoundStatus = YES;
            break;  // have answer, abort search
        }
    }
    return bFoundStatus;
}

- (CBCharacteristic *)loadedCharacteristicObjectForUUID:(NSString *)characteristicUUIDString
{
    CBCharacteristic *charstcFound = nil;
    for (CBCharacteristic *currCharacteristic in self.foundCharacteristics) {
        if ([currCharacteristic.UUID.UUIDString.uppercaseString isEqualToString:characteristicUUIDString.uppercaseString]) {
            charstcFound = currCharacteristic;
            break;
        }
    }
    return charstcFound;
}

- (void)loadCharacteristicsObjectsForSvcUUID:(NSString *)serviceUUIDString
{
    CBService *desiredService = [self loadedServiceObjectForUUID:serviceUUIDString];
    // let's load characteristics objects for a loaded service
    DLog(@"- TX discover characteristics for: UUID=[0x%@]", desiredService.UUID.UUIDString);
    self.engineState = PQS_EXPLORING_CHARACTERISTICS;
    [self.cbpConnectedDevice discoverCharacteristics:nil forService:desiredService];
}

- (void)loadDescriptorObjectsForCharacteristicUUID:(NSString *)characteristicUUIDString
{
    CBCharacteristic *desiredCharacteristic = [self loadedCharacteristicObjectForUUID:characteristicUUIDString];
    // let's load descriptor objects for a loaded characteristic
    DLog(@"- TX discover desriptors for: UUID=[0x%@]", desiredCharacteristic.UUID.UUIDString);
    self.engineState = PQS_EXPLORING_DESCRIPTORS;
    [self.cbpConnectedDevice discoverDescriptorsForCharacteristic:desiredCharacteristic];
}

- (void)loadCharacteristicObjectForUUID:(NSString *)characteristicUUIDString
{
    static BOOL s_bIsFirstLoad = YES;
    if(s_bIsFirstLoad)
    {
        // we need to force these to be loaded early...
        for (NSString *currServiceUUIDString in self.servicesWithIncludes) {
            [self scheduleExplorationOfServiceUUID:currServiceUUIDString];
        }
        s_bIsFirstLoad = NO;    // never again...
    }

    // locate service containing this characteristic
    NSString *strServiceUUID = [self serviceUUIDforCharacteristicUUID:characteristicUUIDString];
    if(strServiceUUID != nil)
    {
        if(![self isLoadedServiceObjectForUUID:strServiceUUID])
        {
            // if we haven't scheduled load of characteristics for this service, do so now!
            [self scheduleExplorationOfServiceUUID:strServiceUUID];
        }
        else
        {
            // have service... do the ops!
            [self checkPendingWork];
        }
    }
    else
    {
        DLog(@"  -- device structure unknown, waiting for service/characteristics to arrive!!!");
    }
}

- (NSString *)serviceUUIDforCharacteristicUUID:(NSString *)characteristicUUIDString
{
    // if first time grab it from the external world...
    if(self.dctCharactersticUUIDsbyServiceUUIDs == nil)
    {
        self.dctCharactersticUUIDsbyServiceUUIDs = self.serviceCharacteristics;
    }
    // UNDONE need assert here in case user didn't tell us structure!!!!

    NSString *strDesiredServiceUUID = nil;
    for (NSString *currServiceUUID in self.dctCharactersticUUIDsbyServiceUUIDs.allKeys) {
        NSArray *serviceCharacteristicUUIDs = [self.dctCharactersticUUIDsbyServiceUUIDs objectForKey:currServiceUUID];
        for (NSString *currCharacteristicUUID in serviceCharacteristicUUIDs) {
            if([currCharacteristicUUID.uppercaseString isEqualToString:characteristicUUIDString.uppercaseString])
            {
                strDesiredServiceUUID = currServiceUUID;
                break;
            }
        }
        if(strDesiredServiceUUID != nil)
        {
            break;  // we have our answer, abort search!
        }
    }
    DLog(@"- returning svc UUID=0x%@ for characteristic UUID=0x%@", strDesiredServiceUUID, characteristicUUIDString);
//    if(strDesiredServiceUUID == nil)
//    {
//        NSAssert(strDesiredServiceUUID != nil, @"[CODE] why don't we know this characteristic UUID or service for it!");
//    }
    return strDesiredServiceUUID;
}

#pragma mark --- PRIVATE (Utility) Methods

-(NSString *)descriptionOfError:(NSError *)error
{
    NSString *strErrorInd = @"";
    if(error != nil)
    {
        strErrorInd = [NSString stringWithFormat:@"ERROR(%ld): %@", (long)error.code, [error localizedDescription]];
    }
    return strErrorInd;
}


#pragma mark - PROTOCOL <CBCentralManagerDelegate> Methods

const CBManagerState kcmsNeverSetState = (CBManagerState)-1;

- (void)centralManagerDidUpdateState:(CBCentralManager *)central
{

    // read once so we don't accidentally incorporate a state-change
    CBManagerState cmsNewState = [central state];

    switch (cmsNewState) {
        case CBManagerStatePoweredOff:
        {
            DLog(@">>>  CBManagerStatePoweredOff  <<<");
            [self clearDevices];

            /* Tell user to power ON BT for functionality, but not on first run - the Framework will alert in that instance. */
            if (m_cmsPreviousState != kcmsNeverSetState) {
                //[discoveryDelegate discoveryStatePoweredOff];
            }
            [[NSNotificationCenter defaultCenter] postNotificationName:kNOTIFICATION_RADIO_POWERED_OFF object:nil];
            break;
        }

        case CBManagerStateUnauthorized:
        {
            DLog(@">>>  CBManagerStateUnauthorized  <<<");
            /* Tell user the app is not allowed. */
            [[NSNotificationCenter defaultCenter] postNotificationName:kNOTIFICATION_BLE_NOT_AUTHORIZED object:nil];
            break;
        }

        case CBManagerStateUnknown:
        {
            DLog(@">>>  CBManagerStateUnknown  <<<");
            /* Bad news, let's wait for another event. */
            [[NSNotificationCenter defaultCenter] postNotificationName:kNOTIFICATION_RADIO_STATE_UNKNOWN object:nil];
            break;
        }
        case CBManagerStateUnsupported:
        {
            DLog(@">>>  CBManagerStateUnsupported  <<<");
            /* Bad news, let's wait for another event. */
            [[NSNotificationCenter defaultCenter] postNotificationName:kNOTIFICATION_RADIO_STATE_UNSUPPORTED object:nil];
            break;
        }

        case CBManagerStatePoweredOn:
        {
            DLog(@">>>  CBManagerStatePoweredOn  <<<");
            m_bPendingInit = NO;
            [self loadSavedDevices];

            // FIXED IOS7->8 FIX (but wait...)
            //[central retrieveConnectedPeripheralsWithServices:[NSArray arrayWithObject:[CBUUID UUIDWithString:self.searchUUID]]];

            if(m_bIsDeviceScanEnabled)
            {
                // we're powered-on, start looking for devices...
                DLog(@"*** Request SCAN")
                [self startScanningForUUIDString:self.searchUUID];
            }
            break;
        }

        case CBManagerStateResetting:
        {
            DLog(@">>>  CBManagerStateResetting  <<<");
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
    DLog(@"- RX NAME=[%@], UUID=[0x%@], RSSI=%ld, advert=[%@], periph=[%@]", peripheral.name, peripheral.UUIDString, (long)[RSSI integerValue], advertisementData, [peripheral description]);
    peripheral.latestRSSI = RSSI;

    BOOL bWantThisPeripheral = NO;
    if(self.searchDeviceName != nil)
    {
        if([peripheral.name.lowercaseString isEqualToString:self.searchDeviceName.lowercaseString])
        {
            bWantThisPeripheral = YES;
        }
    }
    else
    {
        bWantThisPeripheral = YES;
    }

    if (bWantThisPeripheral && ![self.foundPeripherals containsObject:peripheral]) {
        [self.foundPeripherals addObject:peripheral];
        DLog(@"-(INTRNL) add peripheral UUID=0x%@", peripheral.UUIDString);
        [[NSNotificationCenter defaultCenter] postNotificationName:kNOTIFICATION_ADD_BLE_DEVICE object:peripheral];
    }
}

- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral
{
    DLog(@"*** RX UUID=[0x%@]", peripheral.UUIDString);
    [[NSNotificationCenter defaultCenter] postNotificationName:kNOTIFICATION_CONNECT_BLE_DEVICE_SUCCESS object:peripheral];

    if(self.isServicesDiscoveryEnabled)
    {
        DLog(@"- * automatic service discovery enabled, exploring peripheral *");
        [self exploreConnectedPeripheral];
    }
    else
    {
        DLog(@"- connected but automatic service discovery NOT enabled, Checking for pending work!");
        [self setEngineIdle];
    }
}

- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    DLog(@"*** RX UUID=[0x%@] - Attempted connection to peripheral [%@] failed: ERROR(%ld) %@", peripheral.UUIDString, [peripheral name], (long)error.code, [error localizedDescription]);
    [[NSNotificationCenter defaultCenter] postNotificationName:kNOTIFICATION_CONNECT_BLE_DEVICE_FAILURE object:peripheral];

    self.cbpConnectedDevice = nil;
}

- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    if (error != nil) {
        DLog(@"*** RX UUID=[0x%@] with ERROR", peripheral.UUIDString);
        NSArray *disconnectFailureArray = [NSArray arrayWithObjects:error, peripheral, nil];
        [[NSNotificationCenter defaultCenter] postNotificationName:kNOTIFICATION_DISCONNECT_BLE_DEVICE_FAILURE object:disconnectFailureArray];

        //UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Disconnect Error", @"") message:error.localizedDescription delegate:self cancelButtonTitle:NSLocalizedString(@"OK",@"") otherButtonTitles: nil];
        CustomAlertView *alert = [[CustomAlertView alloc] initWithTitle:NSLocalizedString(@"Disconnect Error", @"") message:error.localizedDescription delegate:self cancelButtonTitle:NSLocalizedString(@"OK",@"") otherButtonTitles: nil];
        [alert show];
    }
    else
    {
        DLog(@"*** RX UUID=[0x%@] SUCCESS", peripheral.UUIDString);
        [[NSNotificationCenter defaultCenter] postNotificationName:kNOTIFICATION_DISCONNECT_BLE_DEVICE_SUCCESS object:peripheral];

        //UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Disconnected", @"") message:peripheral.name delegate:self cancelButtonTitle:NSLocalizedString(@"OK",@"") otherButtonTitles: nil];
        CustomAlertView *alert = [[CustomAlertView alloc] initWithTitle:NSLocalizedString(@"Disconnected", @"") message:peripheral.name delegate:self cancelButtonTitle:NSLocalizedString(@"OK",@"") otherButtonTitles: nil];
        [alert show];
    }
    self.cbpConnectedDevice = nil;

    DLog(@"*** Restart SCAN")
    [self startScanningForUUIDString:self.searchUUID];
}


#pragma mark - PROTOCOL <CBPeripheralDelegate> Methods

- (void)peripheralDidUpdateName:(CBPeripheral *)peripheral
{
    DLog(@"*** RX UUID=[0x%@]", peripheral.UUIDString);

    [[NSNotificationCenter defaultCenter] postNotificationName:kNOTIFICATION_DEVICE_UPDATED_NAME object:peripheral];
}

- (void)peripheralDidInvalidateServices:(CBPeripheral *)peripheral
{
    DLog(@"*** RX UUID=[0x%@]", peripheral.UUIDString);

    [[NSNotificationCenter defaultCenter] postNotificationName:kNOTIFICATION_DEVICE_INVALIDATED_SERVICES object:peripheral];
}

- (void)peripheralDidUpdateRSSI:(CBPeripheral *)peripheral error:(NSError *)error
{
#ifdef DEBUG
    NSString *strErrorInd = [self descriptionOfError:error];
#endif
    DLog(@"- RX UUID=0x%@ %@", peripheral.UUIDString, strErrorInd);

    ISPPeripheralTriadParameter *infoObject = [[ISPPeripheralTriadParameter alloc] initWithPeripheral:peripheral parameter:nil error:error];
    [[NSNotificationCenter defaultCenter] postNotificationName:kNOTIFICATION_DEVICE_UPDATED_RSSI object:infoObject];
    DLog(@"- EXIT");
}

- (void)peripheral:(CBPeripheral *)peripheral didReadRSSI:(NSNumber *)RSSI error:(NSError *)error
{
#ifdef DEBUG
    NSString *strErrorInd = [self descriptionOfError:error];
#endif
    DLog(@"- RX UUID=0x%@ %@", peripheral.UUIDString, strErrorInd);

    // save our latest RSSI then do notify
    peripheral.latestRSSI = RSSI;

    ISPPeripheralTriadParameter *infoObject = [[ISPPeripheralTriadParameter alloc] initWithPeripheral:peripheral parameter:nil error:error];
    [[NSNotificationCenter defaultCenter] postNotificationName:kNOTIFICATION_DEVICE_UPDATED_RSSI object:infoObject];
    DLog(@"- EXIT");

}

- (void)foundSearchSvcUUID:(NSString *)svcUUIDString
{
    NSMutableArray *tmpSvcUUIDsBeingDiscovered = [self.searchServiceUUIDs mutableCopy];
    BOOL bMadeChanges = NO;
    for (CBUUID *currUUID in self.searchServiceUUIDs) {
        if([currUUID.UUIDString.uppercaseString isEqualToString:svcUUIDString.uppercaseString])
        {
            DLog(@"- FOUND SVC UUID=[0x%@]", svcUUIDString);
            [tmpSvcUUIDsBeingDiscovered removeObject:currUUID];
            bMadeChanges = YES;
        }
    }
    if(bMadeChanges)
    {
        self.searchServiceUUIDs = tmpSvcUUIDsBeingDiscovered;
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error
{
    if(error != nil)
    {
#ifdef DEBUG
        NSString *strErrorInd = [self descriptionOfError:error];
#endif
        DLog(@"- RX ENTRY UUID=0x%@ %@", peripheral.UUIDString, strErrorInd);
    }
    else
    {
        DLog(@"- RX ENTRY UUID=0x%@ svcs=(%lu)%@", peripheral.UUIDString, (unsigned long)peripheral.services.count, peripheral.services);
    }

    ISPPeripheralTriadParameter *infoObject = [[ISPPeripheralTriadParameter alloc] initWithPeripheral:peripheral parameter:nil error:error];
    [[NSNotificationCenter defaultCenter] postNotificationName:kNOTIFICATION_DEVICE_DISCOVERED_SERVICES object:infoObject];

    if(peripheral.services.count > 0)
    {
        NSMutableDictionary *dctNewServices = [NSMutableDictionary dictionary];
        // build unique internal list of services found...
        for (CBService *newService in peripheral.services) {
            newService.containingService = nil; // mark as top level
            if (![self.foundServices containsObject:newService]) {
                [self.foundServices addObject:newService];
                DLog(@"-(INTRNL) add service #%lu [%@]", (unsigned long)self.foundServices.count, newService);
                [dctNewServices setObject:newService forKey:newService.UUID.UUIDString];
                [self foundSearchSvcUUID:newService.UUID.UUIDString];
            }

            [self removeScheduledExplorationOfServiceUUID:newService.UUID.UUIDString];
        }

        if(dctNewServices.count > 0)
        {
            // add any new services to our scheduled list of services for which to load characteristics
            NSMutableDictionary *tmpDctSvcsPendingCharacteristicLoad = [self.dctNeedCharacteristicLoadsByServiceUUIDs mutableCopy];
            BOOL bAddedNewServiceObject = NO;
            for (NSString *currServiceUUIDString in dctNewServices.allKeys) {
                CBService *currService = [dctNewServices objectForKey:currServiceUUIDString];
                NSObject *foundSvc = [self.dctNeedCharacteristicLoadsByServiceUUIDs objectForKey:currServiceUUIDString];
                if(foundSvc == nil)
                {
                    DLog(@"- ADD need to load characteristics for svc [0x%@]", currServiceUUIDString);
                    [tmpDctSvcsPendingCharacteristicLoad setObject:currService forKey:currServiceUUIDString];
                    bAddedNewServiceObject = YES;
                }
            }

            if(bAddedNewServiceObject)
            {
                self.dctNeedCharacteristicLoadsByServiceUUIDs = tmpDctSvcsPendingCharacteristicLoad;
            }
        }

        if(self.engineState == PQS_EXPLORING_ALL_SERVICES)
        {
            [[NSNotificationCenter defaultCenter] postNotificationName:kNOTIFICATION_DEVICE_SERVICES_DISCOVERED object:[NSDictionary dictionaryWithDictionary:dctNewServices]];
        }

        // if we haven't found all services
        if(self.searchServiceUUIDs != nil && self.searchServiceUUIDs.count > 0)
        {
            //    then we likely need to find an included service
            DLog(@"  -- (nml) still looking for [%@]", self.searchServiceUUIDs);
            // hrmf services not found.. they must be included... find them now...
            [self loadServiceObjectsForIncludedSvcUUIDs:self.searchServiceUUIDs];
        }
        else
        {
            // We have found all, figure out what's next to do...
            [self setEngineIdle];
        }
    }
    else
    {
        DLog(@"-(?HUH?) NO Services (count=0?) found for peripheral=%@", peripheral);
    }

    DLog(@"  -- svc discovery COMPLETE");
    DLog(@"- EXIT");
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverIncludedServicesForService:(CBService *)service error:(NSError *)error
{
#ifdef DEBUG
    NSString *strErrorInd = [self descriptionOfError:error];
#endif
    DLog(@"- RX ENTRY UUID=0x%@ %@", service.UUID.UUIDString, strErrorInd);

    ISPPeripheralTriadParameter *infoObject = [[ISPPeripheralTriadParameter alloc] initWithPeripheral:peripheral parameter:service error:error];
    [[NSNotificationCenter defaultCenter] postNotificationName:kNOTIFICATION_DEVICE_DISCOVERED_INCLUDED_SERVICES object:infoObject];

    NSMutableDictionary *dctNewServices = [NSMutableDictionary dictionary];
    if(service.includedServices.count > 0)
    {
        // build unique internal list of services found...
        for (CBService *newService in service.includedServices) {
            newService.containingService = service;
            if (![self.foundServices containsObject:newService]) {
                [self.foundServices addObject:newService];
                DLog(@"-(INTRNL) add [included]service #%lu UUID=0x%@", (unsigned long)self.foundServices.count, newService.UUID.UUIDString);
                [dctNewServices setObject:newService forKey:newService.UUID.UUIDString];
                [self foundSearchSvcUUID:newService.UUID.UUIDString];
                m_nMaxServices++;
            }
        }

        if(dctNewServices.count > 0)
        {
            NSMutableDictionary *tmpDctSvcsPendingCharacteristicLoad = [self.dctNeedCharacteristicLoadsByServiceUUIDs mutableCopy];
            BOOL bAddedNewServiceObject = NO;
            for (NSString *currServiceUUIDString in dctNewServices.allKeys) {
                CBService *currService = [dctNewServices objectForKey:currServiceUUIDString];
                NSObject *foundSvc = [self.dctNeedCharacteristicLoadsByServiceUUIDs objectForKey:currServiceUUIDString];
                if(foundSvc == nil)
                {
                    DLog(@"- ADD need to load characteristics for svc [0x%@]", currServiceUUIDString);
                    [tmpDctSvcsPendingCharacteristicLoad setObject:currService forKey:currServiceUUIDString];
                    bAddedNewServiceObject = YES;
                }
            }

            if(bAddedNewServiceObject)
            {
                self.dctNeedCharacteristicLoadsByServiceUUIDs = tmpDctSvcsPendingCharacteristicLoad;
            }
        }

        // if we haven't found all services... (bad!)
        if(self.searchServiceUUIDs != nil && self.searchServiceUUIDs.count > 0)
        {
            DLog(@"  -- (nml) still looking for [%@]", self.searchServiceUUIDs);
            // hrmf services not found.. what now!???
            NSAssert(false, @"ERROR[CODE?] why did we miss finding a service!!! - Not the device we thought we had?");
        }
        else
        {
            // We have found all services...
            //
            [self setEngineIdle];
        }
   }
    else
    {
        DLog(@"-(?HUH?) NO included Services (count=0?) found for peripheral=%@", peripheral);
        //DLog(@"  -- NO included Services...")
    }

    DLog(@"  -- (inc) still looking for [%@]", self.searchServiceUUIDs);
    //NSAssert(self.searchServiceUUIDs.count == 0, @"ERROR should have found all services!");

    DLog(@"- EXIT");
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error
{
#ifdef DEBUG
    NSString *strErrorInd = [self descriptionOfError:error];
#endif
    DLog(@"- RX ENTRY UUID=0x%@ %@", service.UUID.UUIDString, strErrorInd);

    ISPPeripheralTriadParameter *infoObject = [[ISPPeripheralTriadParameter alloc] initWithPeripheral:peripheral parameter:service error:error];
    [[NSNotificationCenter defaultCenter] postNotificationName:kNOTIFICATION_DEVICE_DISCOVERED_CHARACTERISTICS object:infoObject];

    // build unique internal list of services found...
    NSMutableDictionary *dctNewCharacteristics = [[NSMutableDictionary alloc] init];
    for (CBCharacteristic *newCharacteristic in service.characteristics) {
        if (![self.foundCharacteristics containsObject:newCharacteristic]) {
            [self.foundCharacteristics addObject:newCharacteristic];
            DLog(@"-(INTRNL) add characteristic #%lu UUID=0x%@", (unsigned long)self.foundCharacteristics.count, newCharacteristic.UUID.UUIDString);
            [dctNewCharacteristics setObject:newCharacteristic forKey:newCharacteristic.UUID.UUIDString];
        }
    }

    [self removeScheduledExplorationOfServiceCharacteristicsUUID:service.UUID.UUIDString];

    if(dctNewCharacteristics.count > 0)
    {
        // add any new services to our scheduled list of services for which to load characteristics
        NSMutableDictionary *tmpDctDescriptsPendingCharacteristicLoad = [self.dctNeedDescriptorLoadsByCharacteristicUUIDs mutableCopy];
        BOOL bAddedNewCharacteristicObject = NO;
        for (NSString *currCharacteristicUUIDString in dctNewCharacteristics.allKeys) {
            CBCharacteristic *currCharacteristic = [dctNewCharacteristics objectForKey:currCharacteristicUUIDString];
            NSObject *foundCharacteristic = [self.dctNeedDescriptorLoadsByCharacteristicUUIDs objectForKey:currCharacteristicUUIDString];
            if(foundCharacteristic == nil)
            {
                DLog(@"- ADD need to load descriptors for characteristic [0x%@]", currCharacteristicUUIDString);
                [tmpDctDescriptsPendingCharacteristicLoad setObject:currCharacteristic forKey:currCharacteristicUUIDString];
                bAddedNewCharacteristicObject = YES;
            }
        }

        if(bAddedNewCharacteristicObject)
        {
            self.dctNeedDescriptorLoadsByCharacteristicUUIDs = tmpDctDescriptsPendingCharacteristicLoad;
        }
    }

    // We have found all, figure out what's next to do...
    [self setEngineIdle];

    DLog(@"- EXIT");
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverDescriptorsForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
#ifdef DEBUG
    NSString *strErrorInd = [self descriptionOfError:error];
#endif
    DLog(@"- RX UUID=0x%@ %@", peripheral.UUIDString, strErrorInd);

    ISPPeripheralTriadParameter *infoObject = [[ISPPeripheralTriadParameter alloc] initWithPeripheral:peripheral parameter:characteristic error:error];
    [[NSNotificationCenter defaultCenter] postNotificationName:kNOTIFICATION_DEVICE_DISCOVERED_CHARACTERISTIC_DESCRIPTORS object:infoObject];

    // build unique internal list of services found...
    for (CBDescriptor *newDescriptor in characteristic.descriptors) {
        if (![self.foundDescriptors containsObject:newDescriptor]) {
            [self.foundDescriptors addObject:newDescriptor];
            DLog(@"-(INTRNL) add descriptor #%lu UUID=0x%@", (unsigned long)self.foundDescriptors.count, newDescriptor.UUID.UUIDString);
        }
    }

    [self removeScheduledExplorationOfDescriptorsForCharacteristicUUID:characteristic.UUID.UUIDString];

    NSMutableDictionary *dctDescriptors = [[NSMutableDictionary alloc] init];
    for (CBDescriptor *currDescriptor  in self.foundDescriptors) {
        [dctDescriptors setObject:currDescriptor forKey:currDescriptor.UUID.UUIDString];
    }

    // finished with all
    [[NSNotificationCenter defaultCenter] postNotificationName:kNOTIFICATION_DEVICE_CHARACTERISTIC_DESCRIPTORS_DISCOVERED object:[NSDictionary dictionaryWithDictionary:dctDescriptors]];

    // We have found all, figure out what's next to do...
    [self setEngineIdle];
    
    DLog(@"- EXIT");
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
#ifdef DEBUG
    NSString *strErrorInd = [self descriptionOfError:error];
#endif
    DLog(@"- RX UUID=0x%@ %@", characteristic.UUID.UUIDString, strErrorInd);

    ISPPeripheralTriadParameter *infoObject = [[ISPPeripheralTriadParameter alloc] initWithPeripheral:peripheral parameter:characteristic error:error];
    [[NSNotificationCenter defaultCenter] postNotificationName:kNOTIFICATION_DEVICE_UPDATED_CHARACTERISTIC_VALUE object:infoObject];
}

- (void)peripheral:(CBPeripheral *)peripheral didWriteValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
#ifdef DEBUG
    NSString *strErrorInd = [self descriptionOfError:error];
#endif
    DLog(@"- RX UUID=0x%@ %@", characteristic.UUID.UUIDString, strErrorInd);

    ISPPeripheralTriadParameter *infoObject = [[ISPPeripheralTriadParameter alloc] initWithPeripheral:peripheral parameter:characteristic error:error];
    [[NSNotificationCenter defaultCenter] postNotificationName:kNOTIFICATION_DEVICE_WROTE_CHARACTERISTIC_VALUE object:infoObject];
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateNotificationStateForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
#ifdef DEBUG
    NSString *strErrorInd = [self descriptionOfError:error];
#endif
    DLog(@"- RX UUID=0x%@ %@", peripheral.UUIDString, strErrorInd);

    ISPPeripheralTriadParameter *infoObject = [[ISPPeripheralTriadParameter alloc] initWithPeripheral:peripheral parameter:characteristic error:error];
    [[NSNotificationCenter defaultCenter] postNotificationName:kNOTIFICATION_DEVICE_UPDATED_CHARACTERISTIC_NOTIF_STATE object:infoObject];
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForDescriptor:(CBDescriptor *)descriptor error:(NSError *)error
{
#ifdef DEBUG
    NSString *strErrorInd = [self descriptionOfError:error];
#endif
    DLog(@"- RX UUID=0x%@ %@", peripheral.UUIDString, strErrorInd);

    ISPPeripheralTriadParameter *infoObject = [[ISPPeripheralTriadParameter alloc] initWithPeripheral:peripheral parameter:descriptor error:error];
    [[NSNotificationCenter defaultCenter] postNotificationName:kNOTIFICATION_DEVICE_UPDATED_DESCRIPTOR_VALUE object:infoObject];
}

- (void)peripheral:(CBPeripheral *)peripheral didWriteValueForDescriptor:(CBDescriptor *)descriptor error:(NSError *)error
{
#ifdef DEBUG
    NSString *strErrorInd = [self descriptionOfError:error];
#endif
    DLog(@"- RX UUID=0x%@ %@", peripheral.UUIDString, strErrorInd);

    ISPPeripheralTriadParameter *infoObject = [[ISPPeripheralTriadParameter alloc] initWithPeripheral:peripheral parameter:descriptor error:error];
    [[NSNotificationCenter defaultCenter] postNotificationName:kNOTIFICATION_DEVICE_WROTE_DESCRIPTOR_VALUE object:infoObject];
}

#pragma mark --> PROTOCOL <NSTimerDelegate> Methods

- (void)handleExpirationOfTimer:(NSTimer *)timer
{
    // our timer has ended, we are to be done with listening for devices to show up!
    DLog(@"- *** timer [%@]", timer);
    [self stopScanning];
}



@end
