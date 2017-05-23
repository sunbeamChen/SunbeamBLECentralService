//
//  SBluetoothCentralManager.m
//  Pods
//
//  Created by sunbeam on 2017/4/20.
//
//

#import "SBluetoothCentralManager.h"
#import <CoreBluetooth/CoreBluetooth.h>
#import <SunbeamLogService/SunbeamLogService.h>

#define BLE_CENTRAL_MANAGER_ERROR @"com.error.ble.central.manager"

typedef enum : NSInteger {
    CENTRAL_MANAGER_HAS_NOT_INIT = 1000, // BCM has not init
    CENTRAL_MANAGER_INIT_FAILED = CENTRAL_MANAGER_HAS_NOT_INIT + 1, // BCM init failed
    BLUETOOTH_IS_POWER_OFF = CENTRAL_MANAGER_INIT_FAILED + 1, // BCM is power off
    BLUETOOTH_IS_SCANING = BLUETOOTH_IS_POWER_OFF + 1, // BCM is scaning
    CONNECT_PERIPHERAL_IS_NIL = BLUETOOTH_IS_SCANING + 1, // connect peripheral is nil
    CONNECT_PERIPHERAL_SERVICE_IS_NIL = CONNECT_PERIPHERAL_IS_NIL + 1, // connect peripheral service is nil
    CONNECT_PERIPHERAL_SERVICE_NOTIFY_CHARACTERISTIC_IS_NIL = CONNECT_PERIPHERAL_SERVICE_IS_NIL + 1, // connect peripheral service notify characteristic is nil
    CONNECT_PERIPHERAL_SERVICE_WRITE_CHARACTERISTIC_IS_NIL = CONNECT_PERIPHERAL_SERVICE_NOTIFY_CHARACTERISTIC_IS_NIL + 1, // connect peripheral service write characteristic is nil
    CONNECT_PERIPHERAL_FAILED = CONNECT_PERIPHERAL_SERVICE_WRITE_CHARACTERISTIC_IS_NIL + 1, // connect peripheral failed
    DISCONNECT_PERIPHERAL_FAILED = CONNECT_PERIPHERAL_FAILED + 1, // disconnect peripheral failed
} BCM_ERROR_ENUM;

@interface SBluetoothCentralManager() <CBCentralManagerDelegate, CBPeripheralDelegate>

// 0-not available,fatal error；1-not available,is discovering；2-available；
@property (nonatomic, assign) int BCMState;

@property (nonatomic, strong) BCMOpenListener BCMOpenListener;

@property (nonatomic, strong) BDFoundListener BDFoundListener;

@property (nonatomic, strong) BDCreateConnectResultListener BDCreateConnectResultListener;

@property (nonatomic, strong) BDDisconnectStateListener BDDisconnectStateListener;

@property (nonatomic, strong) BDServiceFoundListener BDServiceFoundListener;

@property (nonatomic, strong) BDCharacteristicFoundListener BDCharacteristicFoundListener;

@property (nonatomic, strong) BDNotifyCharacteristicEnableListener BDNotifyCharacteristicEnableListener;

@property (nonatomic, strong) BDCharacteristicValueListener BDCharacteristicValueListener;

@property (nonatomic, strong) BDWriteCharacteristicResponseListener BDWriteCharacteristicResponseListener;

@property (nonatomic, strong) BDRSSIValueReadListener BDRSSIValueReadListener;

// BD scan peripheral
// {"pid0":{"peripheral":Object,"name":"","state":"","advertisement":"","rssi":""},"pid1":{"peripheral":Object,"state":"","advertisement":"","rssi":""},...}
@property (nonatomic, strong) NSMutableDictionary* scanBDList;

// BD connected peripheral
// {"pid0":{"peripheral":Object,"name":"","services":{"sid0":{"service":Object,"isPrimary":"","characteristics":{"cid0":{"characteristic":Object,"type":"notify/read/write"}}}}}}
@property (nonatomic, strong) NSMutableDictionary* connectedBDPeripheralList;

// BD disconnect peripheral - manual
// {"pid0":Object,"pid1":Object,...}
@property (nonatomic, strong) NSMutableDictionary* disconnectBDPeripheralList;

// bluetooth central manager
@property (nonatomic, strong) CBCentralManager* bluetoothCentralManager;

@end

@implementation SBluetoothCentralManager

+ (SBluetoothCentralManager *)sharedSBluetoothCentralManager
{
    static SBluetoothCentralManager *sharedInstance = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init
{
    if (self = [super init]) {
        // 初始化操作
        [SLog initSLogService];
#ifdef DEBUG
        NSLog(@"\n======================\nsunbeam BLE central service(for multi-connection - https://github.com/sunbeamChen/SunbeamBLECentralService) version is %@\n======================", SUNBEAM_BLE_CENTRAL_SERVICE_MULTI_CONNECTION_VERSION);
#endif
    }
    return self;
}

- (void)openBCM:(BCMOpenListener)BCMOpenListener
{
    if (_bluetoothCentralManager) {
        [self logWarn:nil sid:nil cid:nil message:@"BCM已经开启"];
        BCMOpenListener(_BCMState, nil);
        return;
    }
    [self resetBCMListener];
    _BCMOpenListener = BCMOpenListener;
    dispatch_queue_t globalQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    _bluetoothCentralManager = [[CBCentralManager alloc] initWithDelegate:self queue:globalQueue];
    if (_bluetoothCentralManager == nil) {
        _BCMState = 0;
        [self logError:nil sid:nil cid:nil message:@"BCM开启失败"];
        BCMOpenListener(_BCMState, [NSError errorWithDomain:BLE_CENTRAL_MANAGER_ERROR code:CENTRAL_MANAGER_INIT_FAILED userInfo:@{NSLocalizedDescriptionKey:@"BCM init failed"}]);
        return;
    }
    _connectedBDPeripheralList = nil;
    _disconnectBDPeripheralList = nil;
    [self logDebug:nil sid:nil cid:nil message:@"BCM开启成功"];
}

- (void)closeBCM:(BCMCloseListener)BCMCloseListener
{
    _BCMState = 0;
    if (self.connectedBDPeripheralList.count > 0 && _bluetoothCentralManager != nil) {
        // {"pid0":{"peripheral":Object,"name":"","services":{"sid0":{"service":Object,"isPrimary":"","characteristics":{"cid0":{"characteristic":Object,"type":"notify/read/write"}}}}}}
        //NSLog(@"%@", self.connectedBDPeripheralList);
        for (NSString* pid in [self.connectedBDPeripheralList allKeys]) {
            [self logDebug:pid sid:nil cid:nil message:@"执行关闭BD连接"];
            [self.disconnectBDPeripheralList setObject:[[self.connectedBDPeripheralList objectForKey:pid] objectForKey:@"peripheral"] forKey:pid];
            [_bluetoothCentralManager cancelPeripheralConnection:[[self.connectedBDPeripheralList objectForKey:pid] objectForKey:@"peripheral"]];
        }
    }
    [self resetBCMListener];
    [self logDebug:nil sid:nil cid:nil message:@"BCM关闭成功"];
    BCMCloseListener(_BCMState, nil);
}

- (void) resetBCMListener
{
    _scanBDList = nil;
    _BDFoundListener = nil;
    _BDCreateConnectResultListener = nil;
    _BDServiceFoundListener = nil;
    _BDCharacteristicFoundListener = nil;
    _BDNotifyCharacteristicEnableListener = nil;
    _BDCharacteristicValueListener = nil;
    _BDWriteCharacteristicResponseListener = nil;
    _BDRSSIValueReadListener = nil;
}

- (void)getBCMState:(void (^)(int, NSError *))completion
{
    if (_bluetoothCentralManager == nil) {
        [self logWarn:nil sid:nil cid:nil message:@"BCM尚未开启"];
        completion(_BCMState, [NSError errorWithDomain:BLE_CENTRAL_MANAGER_ERROR code:CENTRAL_MANAGER_HAS_NOT_INIT userInfo:@{NSLocalizedDescriptionKey:@"BCM has not init"}]);
        return;
    }
    [self logDebug:nil sid:nil cid:nil message:@"获取BCM状态成功"];
    completion(_BCMState, nil);
}

- (void)startScanBD:(NSArray *)services completion:(void (^)(NSError *))completion BDFoundListener:(BDFoundListener) BDFoundListener
{
    _scanBDList = nil;
    if (_BCMState == 0) {
        [self logWarn:nil sid:nil cid:nil message:@"BCM蓝牙关闭"];
        completion([NSError errorWithDomain:BLE_CENTRAL_MANAGER_ERROR code:BLUETOOTH_IS_POWER_OFF userInfo:@{NSLocalizedDescriptionKey:@"BCM is power off"}]);
    } else if (_BCMState == 1) {
        [self logWarn:nil sid:nil cid:nil message:@"BCM正在扫描"];
        completion([NSError errorWithDomain:BLE_CENTRAL_MANAGER_ERROR code:BLUETOOTH_IS_SCANING userInfo:@{NSLocalizedDescriptionKey:@"BCM is scaning"}]);
    } else {
        NSMutableArray* serviceUUIDs = [[NSMutableArray alloc] init];
        if (services != nil) {
            for (NSString* serviceString in services) {
                [serviceUUIDs addObject:[CBUUID UUIDWithString:serviceString]];
            }
        }
        if (_bluetoothCentralManager == nil) {
            [self logWarn:nil sid:nil cid:nil message:@"BCM尚未开启"];
            completion([NSError errorWithDomain:BLE_CENTRAL_MANAGER_ERROR code:CENTRAL_MANAGER_HAS_NOT_INIT userInfo:@{NSLocalizedDescriptionKey:@"BCM has not init"}]);
        } else {
            _BCMState = 1;
            _BDFoundListener = BDFoundListener;
            [_bluetoothCentralManager scanForPeripheralsWithServices:[serviceUUIDs copy] options:nil];
            [self logDebug:nil sid:nil cid:nil message:@"BCM执行扫描"];
            completion(nil);
        }
    }
}

- (void)getAllScanBD:(void(^)(NSMutableArray* scanBDList, NSError* error)) completion
{
    if (_BCMState == 0) {
        [self logWarn:nil sid:nil cid:nil message:@"BCM蓝牙关闭"];
        completion(nil, [NSError errorWithDomain:BLE_CENTRAL_MANAGER_ERROR code:BLUETOOTH_IS_POWER_OFF userInfo:@{NSLocalizedDescriptionKey:@"BCM is power off"}]);
    } else if (_BCMState == 1) {
        [self logWarn:nil sid:nil cid:nil message:@"BCM正在扫描"];
        completion(nil, [NSError errorWithDomain:BLE_CENTRAL_MANAGER_ERROR code:BLUETOOTH_IS_SCANING userInfo:@{NSLocalizedDescriptionKey:@"BCM is scaning"}]);
    } else {
        // {"pid0":{"peripheral":Object,"name":"","state":"","advertisement":"","rssi":""},"pid1":{"peripheral":Object,"state":"","advertisement":"","rssi":""},...}
        NSMutableArray* scanBDArray = [[NSMutableArray alloc] init];
        for (NSString* pId in [self.scanBDList allKeys]) {
            NSDictionary* peripheral = [self.scanBDList objectForKey:pId];
            NSDictionary* formatPeripheral = @{@"pId":pId, @"name":[peripheral objectForKey:@"name"], @"state":[peripheral objectForKey:@"state"], @"advertisement":[peripheral objectForKey:@"advertisement"], @"rssi":[peripheral objectForKey:@"rssi"]};
            [scanBDArray addObject:formatPeripheral];
        }
        [self logDebug:nil sid:nil cid:nil message:@"获取所有扫描设备成功"];
        completion(scanBDArray, nil);
    }
}

- (void)getAllConnectedBD:(void(^)(NSMutableArray* connectedBDList, NSError* error)) completion
{
    if (_BCMState == 0) {
        [self logWarn:nil sid:nil cid:nil message:@"BCM蓝牙关闭"];
        completion(nil, [NSError errorWithDomain:BLE_CENTRAL_MANAGER_ERROR code:BLUETOOTH_IS_POWER_OFF userInfo:@{NSLocalizedDescriptionKey:@"BCM is power off"}]);
    } else if (_BCMState == 1) {
        [self logWarn:nil sid:nil cid:nil message:@"BCM正在扫描"];
        completion(nil, [NSError errorWithDomain:BLE_CENTRAL_MANAGER_ERROR code:BLUETOOTH_IS_SCANING userInfo:@{NSLocalizedDescriptionKey:@"BCM is scaning"}]);
    } else {
        // {"pid0":{"peripheral":Object,"name":"","services":{"sid0":{"service":Object,"isPrimary":"","characteristics":{"cid0":{"characteristic":Object,"type":"notify/read/write"}}}}}}
        NSMutableArray* connectedBDArray = [[NSMutableArray alloc] init];
        for (NSString* pId in [self.scanBDList allKeys]) {
            NSDictionary* peripheral = [self.scanBDList objectForKey:pId];
            NSDictionary* formatPeripheral = @{@"pId":pId, @"name":[peripheral objectForKey:@"name"]};
            [connectedBDArray addObject:formatPeripheral];
        }
        [self logDebug:nil sid:nil cid:nil message:@"获取所有连接设备成功"];
        completion(connectedBDArray, nil);
    }
}

- (void)stopScanBD:(void (^)(NSError *))completion
{
    if (_BCMState == 0) {
        [self logWarn:nil sid:nil cid:nil message:@"BCM蓝牙关闭"];
        completion([NSError errorWithDomain:@"com.error.ble.central.manager" code:BLUETOOTH_IS_POWER_OFF userInfo:@{NSLocalizedDescriptionKey:@"BCM is power off"}]);
    } else if (_BCMState == 1) {
        if (_bluetoothCentralManager) {
            [_bluetoothCentralManager stopScan];
            _BCMState = 2;
            [self logDebug:nil sid:nil cid:nil message:@"停止扫描成功"];
            completion(nil);
        } else {
            [self logWarn:nil sid:nil cid:nil message:@"BCM尚未开启"];
            completion([NSError errorWithDomain:@"com.error.ble.central.manager" code:CENTRAL_MANAGER_HAS_NOT_INIT userInfo:@{NSLocalizedDescriptionKey:@"BCM has not init"}]);
        }
    } else if (_BCMState == 2) {
        [self logWarn:nil sid:nil cid:nil message:@"BCM没有扫描正在执行"];
        SLogWarn(@"%@ | %@", BLE_CENTRAL_MANAGER_ERROR, @"BCM is not scaning");
        completion(nil);
    }
}

- (void)createBDConnection:(NSString *)pid BDCreateConnectResultListener:(BDCreateConnectResultListener)BDCreateConnectResultListener
{
    if (_BCMState == 0) {
        [self logWarn:pid sid:nil cid:nil message:@"BCM蓝牙关闭"];
        BDCreateConnectResultListener(pid, [NSError errorWithDomain:BLE_CENTRAL_MANAGER_ERROR code:BLUETOOTH_IS_POWER_OFF userInfo:@{NSLocalizedDescriptionKey:@"BCM is power off"}]);
    } else if (_BCMState == 1) {
        [self logWarn:pid sid:nil cid:nil message:@"BCM正在扫描"];
        BDCreateConnectResultListener(pid, [NSError errorWithDomain:BLE_CENTRAL_MANAGER_ERROR code:BLUETOOTH_IS_SCANING userInfo:@{NSLocalizedDescriptionKey:@"BCM is scaning"}]);
    } else {
        CBPeripheral* peripheral = [[self.scanBDList objectForKey:pid] objectForKey:@"peripheral"];
        if (peripheral == nil) {
            [self logWarn:pid sid:nil cid:nil message:@"扫描到的外设为空"];
            BDCreateConnectResultListener(pid, [NSError errorWithDomain:BLE_CENTRAL_MANAGER_ERROR code:CONNECT_PERIPHERAL_IS_NIL userInfo:@{NSLocalizedDescriptionKey:@"connect peripheral is nil"}]);
        } else {
            if (_bluetoothCentralManager == nil) {
                [self logWarn:pid sid:nil cid:nil message:@"BCM尚未开启"];
                BDCreateConnectResultListener(pid, [NSError errorWithDomain:BLE_CENTRAL_MANAGER_ERROR code:CENTRAL_MANAGER_HAS_NOT_INIT userInfo:@{NSLocalizedDescriptionKey:@"BCM has not init"}]);
            } else {
                _BDCreateConnectResultListener = BDCreateConnectResultListener;
                [self logDebug:pid sid:nil cid:nil message:@"执行设备连接"];
                [_bluetoothCentralManager connectPeripheral:peripheral options:nil];
            }
            
        }
    }
}

- (void)closeBDConnection:(NSString *)pid BDCloseConnectResultListener:(BDCloseConnectResultListener)BDCloseConnectResultListener
{
    if (_BCMState == 0) {
        [self logWarn:pid sid:nil cid:nil message:@"BCM蓝牙关闭"];
        BDCloseConnectResultListener(pid, [NSError errorWithDomain:BLE_CENTRAL_MANAGER_ERROR code:BLUETOOTH_IS_POWER_OFF userInfo:@{NSLocalizedDescriptionKey:@"BCM is power off"}]);
    } else if (_BCMState == 1) {
        [self logWarn:pid sid:nil cid:nil message:@"BCM正在扫描"];
        BDCloseConnectResultListener(pid, [NSError errorWithDomain:BLE_CENTRAL_MANAGER_ERROR code:BLUETOOTH_IS_SCANING userInfo:@{NSLocalizedDescriptionKey:@"BCM is scaning"}]);
    } else {
        CBPeripheral* peripheral = [[self.connectedBDPeripheralList objectForKey:pid] objectForKey:@"peripheral"];
        if (peripheral == nil) {
            [self logWarn:pid sid:nil cid:nil message:@"连接中的外设为空"];
            BDCloseConnectResultListener(pid, [NSError errorWithDomain:BLE_CENTRAL_MANAGER_ERROR code:CONNECT_PERIPHERAL_IS_NIL userInfo:@{NSLocalizedDescriptionKey:@"connect peripheral is nil"}]);
        } else {
            if (_bluetoothCentralManager == nil) {
                [self logWarn:pid sid:nil cid:nil message:@"BCM尚未开启"];
                BDCloseConnectResultListener(pid, [NSError errorWithDomain:BLE_CENTRAL_MANAGER_ERROR code:CENTRAL_MANAGER_HAS_NOT_INIT userInfo:@{NSLocalizedDescriptionKey:@"BCM has not init"}]);
            } else {
                [self logDebug:pid sid:nil cid:nil message:@"执行设备断开"];
                [self.disconnectBDPeripheralList setObject:peripheral forKey:pid];
                [_bluetoothCentralManager cancelPeripheralConnection:peripheral];
                BDCloseConnectResultListener(pid, nil);
            }
        }
    }
}

- (void)registBDDisconnectStateListener:(BDDisconnectStateListener)BDDisconnectStateListener
{
    _BDDisconnectStateListener = BDDisconnectStateListener;
}

- (void)discoverBDServices:(NSString *)pid BDServiceFoundListener:(BDServiceFoundListener)BDServiceFoundListener
{
    if (_BCMState == 0) {
        [self logWarn:pid sid:nil cid:nil message:@"BCM蓝牙关闭"];
        BDServiceFoundListener(pid, nil, [NSError errorWithDomain:BLE_CENTRAL_MANAGER_ERROR code:BLUETOOTH_IS_POWER_OFF userInfo:@{NSLocalizedDescriptionKey:@"BCM is power off"}]);
    } else if (_BCMState == 1) {
        [self logWarn:pid sid:nil cid:nil message:@"BCM正在扫描"];
        BDServiceFoundListener(pid, nil, [NSError errorWithDomain:BLE_CENTRAL_MANAGER_ERROR code:BLUETOOTH_IS_SCANING userInfo:@{NSLocalizedDescriptionKey:@"BCM is scaning"}]);
    } else {
        // {"pid0":{"peripheral":Object,"name":"","services":{"sid0":{"service":Object,"isPrimary":"","characteristics":{"cid0":{"characteristic":Object,"type":"notify/read/write"}}}}}}
        NSDictionary* peripheralDict = [self.connectedBDPeripheralList objectForKey:pid];
        if (peripheralDict == nil) {
            [self logWarn:pid sid:nil cid:nil message:@"连接中的外设为空"];
            BDServiceFoundListener(pid, nil, [NSError errorWithDomain:BLE_CENTRAL_MANAGER_ERROR code:CONNECT_PERIPHERAL_IS_NIL userInfo:@{NSLocalizedDescriptionKey:@"connect peripheral is nil"}]);
        } else {
            CBPeripheral* peripheral = [peripheralDict objectForKey:@"peripheral"];
            _BDServiceFoundListener = BDServiceFoundListener;
            [self logDebug:pid sid:nil cid:nil message:@"执行发现外设服务"];
            [peripheral discoverServices:nil];
        }
    }
}

- (void)discoverBDCharacteristics:(NSString *)pid sid:(NSString *)sid BDCharacteristicFoundListener:(BDCharacteristicFoundListener)BDCharacteristicFoundListener
{
    if (_BCMState == 0) {
        [self logWarn:pid sid:sid cid:nil message:@"BCM蓝牙关闭"];
        BDCharacteristicFoundListener(pid, sid, nil, [NSError errorWithDomain:BLE_CENTRAL_MANAGER_ERROR code:BLUETOOTH_IS_POWER_OFF userInfo:@{NSLocalizedDescriptionKey:@"BCM is power off"}]);
    } else if (_BCMState == 1) {
        [self logWarn:pid sid:sid cid:nil message:@"BCM正在扫描"];
        BDCharacteristicFoundListener(pid, sid, nil, [NSError errorWithDomain:BLE_CENTRAL_MANAGER_ERROR code:BLUETOOTH_IS_SCANING userInfo:@{NSLocalizedDescriptionKey:@"BCM is scaning"}]);
    } else {
        // {"pid0":{"peripheral":Object,"name":"","services":{"sid0":{"service":Object,"isPrimary":"","characteristics":{"cid0":{"characteristic":Object,"type":"notify/read/write"}}}}}}
        NSDictionary* peripheralDict = [self.connectedBDPeripheralList objectForKey:pid];
        if (peripheralDict) {
            CBPeripheral* peripheral = [peripheralDict objectForKey:@"peripheral"];
            NSDictionary* servicesDict = [peripheralDict objectForKey:@"services"];
            if (servicesDict) {
                NSDictionary* serviceDict = [servicesDict objectForKey:sid];
                if (serviceDict) {
                    CBService* service = [serviceDict objectForKey:@"service"];
                    _BDCharacteristicFoundListener = BDCharacteristicFoundListener;
                    [self logDebug:pid sid:sid cid:nil message:@"执行发现外设特征值"];
                    [peripheral discoverCharacteristics:nil forService:service];
                    return;
                }
            }
        }
        [self logWarn:pid sid:sid cid:nil message:@"连接中的外设服务为空"];
        BDCharacteristicFoundListener(pid, sid, nil, [NSError errorWithDomain:BLE_CENTRAL_MANAGER_ERROR code:CONNECT_PERIPHERAL_SERVICE_IS_NIL userInfo:@{NSLocalizedDescriptionKey:@"connect peripheral service is nil"}]);
    }
}

- (void)enableBDNotifyCharacteristic:(NSString *)pid sid:(NSString *)sid cid:(NSString *)cid subFlag:(BOOL)subFlag BDNotifyCharacteristicEnableListener:(BDNotifyCharacteristicEnableListener)BDNotifyCharacteristicEnableListener
{
    if (_BCMState == 0) {
        [self logWarn:pid sid:sid cid:cid message:@"BCM蓝牙关闭"];
        BDNotifyCharacteristicEnableListener(pid, sid, cid, [NSError errorWithDomain:BLE_CENTRAL_MANAGER_ERROR code:BLUETOOTH_IS_POWER_OFF userInfo:@{NSLocalizedDescriptionKey:@"BCM is power off"}]);
    } else if (_BCMState == 1) {
        [self logWarn:pid sid:sid cid:cid message:@"BCM正在扫描"];
        BDNotifyCharacteristicEnableListener(pid, sid, cid, [NSError errorWithDomain:BLE_CENTRAL_MANAGER_ERROR code:BLUETOOTH_IS_SCANING userInfo:@{NSLocalizedDescriptionKey:@"BCM is scaning"}]);
    } else {
        // {"pid0":{"peripheral":Object,"name":"","services":{"sid0":{"service":Object,"isPrimary":"","characteristics":{"cid0":{"characteristic":Object,"type":"notify/read/write"}}}}}}
        NSDictionary* peripheralDict = [self.connectedBDPeripheralList objectForKey:pid];
        if (peripheralDict) {
            CBPeripheral* peripheral = [peripheralDict objectForKey:@"peripheral"];
            NSDictionary* servicesDict = [peripheralDict objectForKey:@"services"];
            if (servicesDict) {
                NSDictionary* serviceDict = [servicesDict objectForKey:sid];
                if (serviceDict) {
                    NSDictionary* characteristicsDict = [serviceDict objectForKey:@"characteristics"];
                    if (characteristicsDict) {
                        NSDictionary* characteristicDict = [characteristicsDict objectForKey:cid];
                        if (characteristicDict) {
                            CBCharacteristic* characteristic = [characteristicDict objectForKey:@"characteristic"];
                            _BDNotifyCharacteristicEnableListener = BDNotifyCharacteristicEnableListener;
                            [self logDebug:pid sid:sid cid:cid message:@"执行订阅外设特征值"];
                            [peripheral setNotifyValue:subFlag forCharacteristic:characteristic];
                            return;
                        }
                    }
                }
            }
        }
        [self logWarn:pid sid:sid cid:cid message:@"连接中的外设特征值为空"];
        BDNotifyCharacteristicEnableListener(pid, sid, cid, [NSError errorWithDomain:BLE_CENTRAL_MANAGER_ERROR code:CONNECT_PERIPHERAL_SERVICE_NOTIFY_CHARACTERISTIC_IS_NIL userInfo:@{NSLocalizedDescriptionKey:@"connect peripheral service notify characteristic is nil"}]);
    }
}

- (void)registBDCharacteristicValueListener:(BDCharacteristicValueListener)BDCharacteristicValueListener
{
    _BDCharacteristicValueListener = BDCharacteristicValueListener;
}

- (void)writeValueToBD:(NSString *)pid sid:(NSString *)sid cid:(NSString *)cid value:(NSData *)value BDWriteCharacteristicResponseListener:(BDWriteCharacteristicResponseListener)BDWriteCharacteristicResponseListener
{
    if (_BCMState == 0) {
        [self logWarn:pid sid:sid cid:cid message:@"BCM蓝牙关闭"];
        BDWriteCharacteristicResponseListener(pid, sid, cid, [NSError errorWithDomain:BLE_CENTRAL_MANAGER_ERROR code:BLUETOOTH_IS_POWER_OFF userInfo:@{NSLocalizedDescriptionKey:@"BCM is power off"}]);
    } else if (_BCMState == 1) {
        [self logWarn:pid sid:sid cid:cid message:@"BCM正在扫描"];
        BDWriteCharacteristicResponseListener(pid, sid, cid, [NSError errorWithDomain:BLE_CENTRAL_MANAGER_ERROR code:BLUETOOTH_IS_SCANING userInfo:@{NSLocalizedDescriptionKey:@"BCM is scaning"}]);
    } else {
        // {"pid0":{"peripheral":Object,"name":"","services":{"sid0":{"service":Object,"isPrimary":"","characteristics":{"cid0":{"characteristic":Object,"type":"notify/read/write"}}}}}}
        NSDictionary* peripheralDict = [self.connectedBDPeripheralList objectForKey:pid];
        if (peripheralDict) {
            CBPeripheral* peripheral = [peripheralDict objectForKey:@"peripheral"];
            NSDictionary* servicesDict = [peripheralDict objectForKey:@"services"];
            if (servicesDict) {
                NSDictionary* serviceDict = [servicesDict objectForKey:sid];
                if (serviceDict) {
                    NSDictionary* characteristicsDict = [serviceDict objectForKey:@"characteristics"];
                    if (characteristicsDict) {
                        NSDictionary* characteristicDict = [characteristicsDict objectForKey:cid];
                        if (characteristicDict) {
                            CBCharacteristic* characteristic = [characteristicDict objectForKey:@"characteristic"];
                            _BDWriteCharacteristicResponseListener = BDWriteCharacteristicResponseListener;
                            [self logDebug:pid sid:sid cid:cid message:@"执行向设备写入数据"];
                            [peripheral writeValue:value forCharacteristic:characteristic type:CBCharacteristicWriteWithResponse];
                            return;
                        }
                    }
                }
            }
        }
        [self logWarn:pid sid:sid cid:cid message:@"连接中的外设特征值为空"];
        BDWriteCharacteristicResponseListener(pid, sid, cid, [NSError errorWithDomain:BLE_CENTRAL_MANAGER_ERROR code:CONNECT_PERIPHERAL_SERVICE_WRITE_CHARACTERISTIC_IS_NIL userInfo:@{NSLocalizedDescriptionKey:@"connect peripheral service write characteristic is nil"}]);
    }
}

- (void)readBDRSSIValue:(NSString *)pid BDRSSIValueReadListener:(BDRSSIValueReadListener)BDRSSIValueReadListener
{
    if (_BCMState == 0) {
        [self logWarn:pid sid:nil cid:nil message:@"BCM蓝牙关闭"];
        BDRSSIValueReadListener(pid, nil, [NSError errorWithDomain:BLE_CENTRAL_MANAGER_ERROR code:BLUETOOTH_IS_POWER_OFF userInfo:@{NSLocalizedDescriptionKey:@"BCM is power off"}]);
    } else if (_BCMState == 1) {
        [self logWarn:pid sid:nil cid:nil message:@"BCM正在扫描"];
        BDRSSIValueReadListener(pid, nil, [NSError errorWithDomain:BLE_CENTRAL_MANAGER_ERROR code:BLUETOOTH_IS_SCANING userInfo:@{NSLocalizedDescriptionKey:@"BCM is scaning"}]);
    } else {
        // {"pid0":{"peripheral":Object,"name":"","services":{"sid0":{"service":Object,"isPrimary":"","characteristics":{"cid0":{"characteristic":Object,"type":"notify/read/write"}}}}}}
        NSDictionary* peripheralDict = [self.connectedBDPeripheralList objectForKey:pid];
        if (peripheralDict) {
            CBPeripheral* peripheral = [peripheralDict objectForKey:@"peripheral"];
            _BDRSSIValueReadListener = BDRSSIValueReadListener;
            [self logDebug:pid sid:nil cid:nil message:@"执行读取设备RSSI"];
            [peripheral readRSSI];
            return;
        }
        [self logWarn:pid sid:nil cid:nil message:@"连接中的外设为空"];
        BDRSSIValueReadListener(pid, nil, [NSError errorWithDomain:BLE_CENTRAL_MANAGER_ERROR code:CONNECT_PERIPHERAL_IS_NIL userInfo:@{NSLocalizedDescriptionKey:@"connect peripheral is nil"}]);
    }
}

#pragma mark - central manager delegate
/*!
 *  @method centralManagerDidUpdateState:
 *
 *  @param central  The central manager whose state has changed.
 *
 *  @discussion     Invoked whenever the central manager's state has been updated. Commands should only be issued when the state is
 *                  <code>CBCentralManagerStatePoweredOn</code>. A state below <code>CBCentralManagerStatePoweredOn</code>
 *                  implies that scanning has stopped and any connected peripherals have been disconnected. If the state moves below
 *                  <code>CBCentralManagerStatePoweredOff</code>, all <code>CBPeripheral</code> objects obtained from this central
 *                  manager become invalid and must be retrieved or discovered again.
 *
 *  @see            state
 *
 */
- (void)centralManagerDidUpdateState:(CBCentralManager *)central
{
    // 蓝牙状态改变回调
    switch (central.state) {
        case CBCentralManagerStatePoweredOn:
        {
            _BCMState = 2;
            [self logDebug:nil sid:nil cid:nil message:@"蓝牙适配器状态改变:开启"];
            if (_BCMOpenListener) {
                _BCMOpenListener(_BCMState, nil);
                _BCMOpenListener = nil;
            }
            break;
        }
            
        case CBCentralManagerStatePoweredOff:
        case CBCentralManagerStateResetting:
        case CBCentralManagerStateUnauthorized:
        case CBCentralManagerStateUnsupported:
        case CBCentralManagerStateUnknown:
        default:
        {
            _BCMState = 0;
            [self logDebug:nil sid:nil cid:nil message:@"蓝牙适配器状态改变:关闭"];
            break;
        }
    }
}

/*!
 *  @method centralManager:willRestoreState:
 *
 *  @param central      The central manager providing this information.
 *  @param dict			A dictionary containing information about <i>central</i> that was preserved by the system at the time the app was terminated.
 *
 *  @discussion			For apps that opt-in to state preservation and restoration, this is the first method invoked when your app is relaunched into
 *						the background to complete some Bluetooth-related task. Use this method to synchronize your app's state with the state of the
 *						Bluetooth system.
 *
 *  @seealso            CBCentralManagerRestoredStatePeripheralsKey;
 *  @seealso            CBCentralManagerRestoredStateScanServicesKey;
 *  @seealso            CBCentralManagerRestoredStateScanOptionsKey;
 *
 */
//- (void)centralManager:(CBCentralManager *)central willRestoreState:(NSDictionary<NSString *, id> *)dict
//{
//    // 蓝牙中心管理器恢复时操作
//    
//}

/*!
 *  @method centralManager:didDiscoverPeripheral:advertisementData:RSSI:
 *
 *  @param central              The central manager providing this update.
 *  @param peripheral           A <code>CBPeripheral</code> object.
 *  @param advertisementData    A dictionary containing any advertisement and scan response data.
 *  @param RSSI                 The current RSSI of <i>peripheral</i>, in dBm. A value of <code>127</code> is reserved and indicates the RSSI
 *								was not available.
 *
 *  @discussion                 This method is invoked while scanning, upon the discovery of <i>peripheral</i> by <i>central</i>. A discovered peripheral must
 *                              be retained in order to use it; otherwise, it is assumed to not be of interest and will be cleaned up by the central manager. For
 *                              a list of <i>advertisementData</i> keys, see {@link CBAdvertisementDataLocalNameKey} and other similar constants.
 *
 *  @seealso                    CBAdvertisementData.h
 *
 */
- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary<NSString *, id> *)advertisementData RSSI:(NSNumber *)RSSI
{
    // 扫描外设，发现外设回调
    // {"pid0":{"peripheral":Object,"name":"","state":"","advertisement":"","rssi":""},"pid1":{"peripheral":Object,"state":"","advertisement":"","rssi":""},...}
    // state：0-断开；2-连接中；
    if (peripheral == nil || peripheral.name == nil || advertisementData == nil || RSSI == nil) {
        return;
    }
    [self logDebug:peripheral.identifier.UUIDString sid:nil cid:nil message:@"发现外设"];
    NSDictionary* peripheralObject = @{@"peripheral":peripheral, @"name":peripheral.name, @"state":@(peripheral.state), @"advertisement":advertisementData, @"rssi":RSSI};
    [self.scanBDList setObject:peripheralObject forKey:peripheral.identifier.UUIDString];
    if (_BDFoundListener) {
        _BDFoundListener(peripheral.identifier.UUIDString, peripheral.name, peripheral.state, advertisementData, RSSI);
    } else {
        [self logWarn:peripheral.identifier.UUIDString sid:nil cid:nil message:@"BDFoundListener为空"];
    }
}

/*!
 *  @method centralManager:didConnectPeripheral:
 *
 *  @param central      The central manager providing this information.
 *  @param peripheral   The <code>CBPeripheral</code> that has connected.
 *
 *  @discussion         This method is invoked when a connection initiated by {@link connectPeripheral:options:} has succeeded.
 *
 */
- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral
{
    // 蓝牙连接成功时回调
    if (_BDCreateConnectResultListener) {
        // {"pid0":{"peripheral":Object,"name":"","services":{"sid0":{"service":Object,"isPrimary":"","characteristics":{"cid0":{"characteristic":Object,"type":"notify/read/write"}}}}}}
        NSDictionary* peripheralDict = @{@"peripheral":peripheral,@"name":peripheral.name};
        [self.connectedBDPeripheralList setObject:peripheralDict forKey:peripheral.identifier.UUIDString];
        peripheral.delegate = self;
        [self logDebug:peripheral.identifier.UUIDString sid:nil cid:nil message:@"BD连接成功"];
        _BDCreateConnectResultListener(peripheral.identifier.UUIDString, nil);
    } else {
        [self logWarn:peripheral.identifier.UUIDString sid:nil cid:nil message:@"BDCreateConnectResultListener为空"];
    }
}

/*!
 *  @method centralManager:didFailToConnectPeripheral:error:
 *
 *  @param central      The central manager providing this information.
 *  @param peripheral   The <code>CBPeripheral</code> that has failed to connect.
 *  @param error        The cause of the failure.
 *
 *  @discussion         This method is invoked when a connection initiated by {@link connectPeripheral:options:} has failed to complete. As connection attempts do not
 *                      timeout, the failure of a connection is atypical and usually indicative of a transient issue.
 *
 */
- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(nullable NSError *)error
{
    // 蓝牙连接失败时回调
    if (_BDCreateConnectResultListener) {
        [self logDebug:peripheral.identifier.UUIDString sid:nil cid:nil message:@"BD连接失败"];
        _BDCreateConnectResultListener(peripheral.identifier.UUIDString, [NSError errorWithDomain:BLE_CENTRAL_MANAGER_ERROR code:CONNECT_PERIPHERAL_FAILED userInfo:@{NSLocalizedDescriptionKey:@"connect peripheral failed"}]);
    } else {
        [self logWarn:peripheral.identifier.UUIDString sid:nil cid:nil message:@"BDCreateConnectResultListener为空"];
    }
}

/*!
 *  @method centralManager:didDisconnectPeripheral:error:
 *
 *  @param central      The central manager providing this information.
 *  @param peripheral   The <code>CBPeripheral</code> that has disconnected.
 *  @param error        If an error occurred, the cause of the failure.
 *
 *  @discussion         This method is invoked upon the disconnection of a peripheral that was connected by {@link connectPeripheral:options:}. If the disconnection
 *                      was not initiated by {@link cancelPeripheralConnection}, the cause will be detailed in the <i>error</i> parameter. Once this method has been
 *                      called, no more methods will be invoked on <i>peripheral</i>'s <code>CBPeripheralDelegate</code>.
 *
 */
- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(nullable NSError *)error
{
    // 蓝牙连接断开时回调
    // {"pid0":{"peripheral":Object,"name":"","services":{"sid0":{"service":Object,"isPrimary":"","characteristics":{"cid0":{"characteristic":Object,"type":"notify/read/write"}}}}}}
    NSDictionary* peripheralDict = [self.connectedBDPeripheralList objectForKey:peripheral.identifier.UUIDString];
    if (peripheralDict == nil) {
        [self logWarn:peripheral.identifier.UUIDString sid:nil cid:nil message:@"断开BD在已连接BD列表中不存在"];
        if (_BDDisconnectStateListener) {
            if ([self.disconnectBDPeripheralList objectForKey:peripheral.identifier.UUIDString] != nil) {
                [self logDebug:peripheral.identifier.UUIDString sid:nil cid:nil message:@"BD连接主动断开"];
                [self.disconnectBDPeripheralList removeObjectForKey:peripheral.identifier.UUIDString];
                return;
            }
            [self logDebug:peripheral.identifier.UUIDString sid:nil cid:nil message:@"BD连接异常断开"];
            _BDDisconnectStateListener(peripheral.identifier.UUIDString, nil);
        } else {
            [self logWarn:peripheral.identifier.UUIDString sid:nil cid:nil message:@"BDDisconnectStateListener为空"];
        }
    } else {
        if (_BDDisconnectStateListener) {
            if ([self.disconnectBDPeripheralList objectForKey:peripheral.identifier.UUIDString] != nil) {
                [self logDebug:peripheral.identifier.UUIDString sid:nil cid:nil message:@"BD连接主动断开"];
                [self.disconnectBDPeripheralList removeObjectForKey:peripheral.identifier.UUIDString];
                return;
            }
            [self logDebug:peripheral.identifier.UUIDString sid:nil cid:nil message:@"BD连接异常断开"];
            _BDDisconnectStateListener(peripheral.identifier.UUIDString, nil);
        } else {
            [self logWarn:peripheral.identifier.UUIDString sid:nil cid:nil message:@"BDDisconnectStateListener为空"];
        }
    }
    [self.disconnectBDPeripheralList removeObjectForKey:peripheral.identifier.UUIDString];
    [self.connectedBDPeripheralList removeObjectForKey:peripheral.identifier.UUIDString];
}

#pragma mark - peripheral delegate
/*!
 *  @method peripheralDidUpdateName:
 *
 *  @param peripheral	The peripheral providing this update.
 *
 *  @discussion			This method is invoked when the @link name @/link of <i>peripheral</i> changes.
 */
- (void)peripheralDidUpdateName:(CBPeripheral *)peripheral NS_AVAILABLE(NA, 6_0)
{
    // 蓝牙连接成功，外设name发生改变时回调
    
}

/*!
 *  @method peripheral:didModifyServices:
 *
 *  @param peripheral			The peripheral providing this update.
 *  @param invalidatedServices	The services that have been invalidated
 *
 *  @discussion			This method is invoked when the @link services @/link of <i>peripheral</i> have been changed.
 *						At this point, the designated <code>CBService</code> objects have been invalidated.
 *						Services can be re-discovered via @link discoverServices: @/link.
 */
- (void)peripheral:(CBPeripheral *)peripheral didModifyServices:(NSArray<CBService *> *)invalidatedServices NS_AVAILABLE(NA, 7_0)
{
    // 蓝牙连接成功，修改改设services时回调
    
}

/*!
 *  @method peripheralDidUpdateRSSI:error:
 *
 *  @param peripheral	The peripheral providing this update.
 *	@param error		If an error occurred, the cause of the failure.
 *
 *  @discussion			This method returns the result of a @link readRSSI: @/link call.
 *
 *  @deprecated			Use {@link peripheral:didReadRSSI:error:} instead.
 */
- (void)peripheralDidUpdateRSSI:(CBPeripheral *)peripheral error:(nullable NSError *)error NS_DEPRECATED(NA, NA, 5_0, 8_0)
{
    // 8.0以下系统版本，设备蓝牙连接成功，通过readRSSI:接口获取RSSI值回调
    
}

/*!
 *  @method peripheral:didReadRSSI:error:
 *
 *  @param peripheral	The peripheral providing this update.
 *  @param RSSI			The current RSSI of the link.
 *  @param error		If an error occurred, the cause of the failure.
 *
 *  @discussion			This method returns the result of a @link readRSSI: @/link call.
 */
- (void)peripheral:(CBPeripheral *)peripheral didReadRSSI:(NSNumber *)RSSI error:(nullable NSError *)error NS_AVAILABLE(NA, 8_0)
{
    // 8.0以上系统版本，设备蓝牙连接成功，通过readRSSI:接口获取RSSI回调
    if (_BDRSSIValueReadListener) {
        [self logDebug:peripheral.identifier.UUIDString sid:nil cid:nil message:@"获取RSSI成功"];
        _BDRSSIValueReadListener(peripheral.identifier.UUIDString, RSSI, nil);
    } else {
        [self logWarn:peripheral.identifier.UUIDString sid:nil cid:nil message:@"BDRSSIValueReadListener为空"];
    }
}

/*!
 *  @method peripheral:didDiscoverServices:
 *
 *  @param peripheral	The peripheral providing this information.
 *	@param error		If an error occurred, the cause of the failure.
 *
 *  @discussion			This method returns the result of a @link discoverServices: @/link call. If the service(s) were read successfully, they can be retrieved via
 *						<i>peripheral</i>'s @link services @/link property.
 *
 */
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(nullable NSError *)error
{
    // 设备蓝牙连接成功，通过discoverServices:接口获取外设services回调
    // {"pid0":{"peripheral":Object,"name":"","services":{"sid0":{"service":Object,"isPrimary":"","characteristics":{"cid0":{"characteristic":Object,"type":"notify/read/write"}}}}}}
    NSDictionary* peripheralDict = [self.connectedBDPeripheralList objectForKey:peripheral.identifier.UUIDString];
    if (peripheralDict) {
        NSMutableDictionary* pDict = [peripheralDict mutableCopy];
        NSMutableDictionary* servicesDict = [[NSMutableDictionary alloc] init];
        NSMutableArray* sidArray = [[NSMutableArray alloc] init];
        for (CBService* service in peripheral.services) {
            NSMutableDictionary* characteristicsDict = [[NSMutableDictionary alloc] init];
            [servicesDict setObject:@{@"service":service, @"isPrimary":@(service.isPrimary), @"characteristics":characteristicsDict} forKey:service.UUID.UUIDString];
            [sidArray addObject:service.UUID.UUIDString];
        }
        [pDict setObject:servicesDict forKey:@"services"];
        [self.connectedBDPeripheralList setObject:pDict forKey:peripheral.identifier.UUIDString];
        if (_BDServiceFoundListener) {
            [self logDebug:peripheral.identifier.UUIDString sid:nil cid:nil message:@"发现外设服务成功"];
            _BDServiceFoundListener(peripheral.identifier.UUIDString, sidArray, nil);
        } else {
            [self logWarn:peripheral.identifier.UUIDString sid:nil cid:nil message:@"BDServiceFoundListener为空"];
        }
    } else {
        [self logWarn:peripheral.identifier.UUIDString sid:nil cid:nil message:@"连接中外设为空"];
    }
}

/*!
 *  @method peripheral:didDiscoverIncludedServicesForService:error:
 *
 *  @param peripheral	The peripheral providing this information.
 *  @param service		The <code>CBService</code> object containing the included services.
 *	@param error		If an error occurred, the cause of the failure.
 *
 *  @discussion			This method returns the result of a @link discoverIncludedServices:forService: @/link call. If the included service(s) were read successfully,
 *						they can be retrieved via <i>service</i>'s <code>includedServices</code> property.
 */
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverIncludedServicesForService:(CBService *)service error:(nullable NSError *)error
{
    // 设备蓝牙连接成功，通过调用discoverIncludedServices:forService:接口获取外设included services回调
    
}

/*!
 *  @method peripheral:didDiscoverCharacteristicsForService:error:
 *
 *  @param peripheral	The peripheral providing this information.
 *  @param service		The <code>CBService</code> object containing the characteristic(s).
 *	@param error		If an error occurred, the cause of the failure.
 *
 *  @discussion			This method returns the result of a @link discoverCharacteristics:forService: @/link call. If the characteristic(s) were read successfully,
 *						they can be retrieved via <i>service</i>'s <code>characteristics</code> property.
 */
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(nullable NSError *)error
{
    // 设备蓝牙连接成功，通过调用discoverCharacteristics:forService:接口获取外设service characteristics回调
    // {"pid0":{"peripheral":Object,"name":"","services":{"sid0":{"service":Object,"isPrimary":"","characteristics":{"cid0":{"characteristic":Object,"type":"notify/read/write"}}}}}}
    NSDictionary* peripheralDict = [self.connectedBDPeripheralList objectForKey:peripheral.identifier.UUIDString];
    if (peripheralDict) {
        NSMutableDictionary* pDict = [peripheralDict mutableCopy];
        NSDictionary* servicesDict = [peripheralDict objectForKey:@"services"];
        if (servicesDict) {
            NSMutableDictionary* sDict = [servicesDict mutableCopy];
            NSDictionary* serviceDict = [servicesDict objectForKey:service.UUID.UUIDString];
            if (serviceDict) {
                NSMutableDictionary* ssDict = [serviceDict mutableCopy];
                NSMutableDictionary* characteristicsDict = [[NSMutableDictionary alloc] init];
                NSArray* characteristicArray = service.characteristics;
                NSMutableArray* cidArray = [[NSMutableArray alloc] init];
                for (CBCharacteristic* characteristic in characteristicArray) {
                    [characteristicsDict setObject:@{@"characteristic":characteristic,@"type":@(characteristic.properties)} forKey:characteristic.UUID.UUIDString];
                    [cidArray addObject:characteristic.UUID.UUIDString];
                }
                [ssDict setObject:characteristicsDict forKey:@"characteristics"];
                [sDict setObject:ssDict forKey:service.UUID.UUIDString];
                [pDict setObject:sDict forKey:@"services"];
                [self.connectedBDPeripheralList setObject:pDict forKey:peripheral.identifier.UUIDString];
                if (_BDCharacteristicFoundListener) {
                    [self logDebug:peripheral.identifier.UUIDString sid:service.UUID.UUIDString cid:nil message:@"发现外设特征值成功"];
                    _BDCharacteristicFoundListener(peripheral.identifier.UUIDString, service.UUID.UUIDString, cidArray, nil);
                } else {
                    [self logWarn:peripheral.identifier.UUIDString sid:nil cid:nil message:@"BDCharacteristicFoundListener为空"];
                }
            } else {
                [self logWarn:peripheral.identifier.UUIDString sid:nil cid:nil message:@"连接中指定外设服务为空"];
            }
        } else {
            [self logWarn:peripheral.identifier.UUIDString sid:nil cid:nil message:@"连接中外设服务列表为空"];
        }
    } else {
        [self logWarn:peripheral.identifier.UUIDString sid:nil cid:nil message:@"连接中外设为空"];
    }
}

/*!
 *  @method peripheral:didUpdateValueForCharacteristic:error:
 *
 *  @param peripheral		The peripheral providing this information.
 *  @param characteristic	A <code>CBCharacteristic</code> object.
 *	@param error			If an error occurred, the cause of the failure.
 *
 *  @discussion				This method is invoked after a @link readValueForCharacteristic: @/link call, or upon receipt of a notification/indication.
 */
- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(nullable NSError *)error
{
    // 设备蓝牙连接成功，通过调用readValueForCharacteristic:接口获取外设read characteristic value回调或者notification/indication characteristic发送的数据
    if (_BDCharacteristicValueListener) {
        // {"pid0":{"peripheral":Object,"name":"","services":{"sid0":{"service":Object,"isPrimary":"","characteristics":{"cid0":{"characteristic":Object,"type":"notify/read/write"}}}}}}
        NSString* serviceId = nil;
        NSDictionary* pDict = [self.connectedBDPeripheralList objectForKey:peripheral.identifier.UUIDString];
        if (pDict) {
            NSDictionary* servicesDict = [pDict objectForKey:@"services"];
            for (NSString* sid in [servicesDict allKeys]) {
                NSDictionary* ssDict = [servicesDict objectForKey:sid];
                if (ssDict) {
                    NSDictionary* characteristicsDict = [ssDict objectForKey:@"characteristics"];
                    if (characteristicsDict) {
                        NSArray* cidArray = [characteristicsDict allKeys];
                        if ([cidArray containsObject:characteristic.UUID.UUIDString]) {
                            serviceId = sid;
                            break;
                        }
                    }
                }
            }
            [self logDebug:peripheral.identifier.UUIDString sid:serviceId cid:characteristic.UUID.UUIDString message:@"收到外设发送数据"];
            _BDCharacteristicValueListener(peripheral.identifier.UUIDString, serviceId, characteristic.UUID.UUIDString, characteristic.value, nil);
        } else {
            [self logWarn:peripheral.identifier.UUIDString sid:nil cid:characteristic.UUID.UUIDString message:@"连接中外设为空"];
        }
    } else {
        [self logWarn:peripheral.identifier.UUIDString sid:nil cid:characteristic.UUID.UUIDString message:@"BDCharacteristicValueListener为空"];
    }
}

/*!
 *  @method peripheral:didWriteValueForCharacteristic:error:
 *
 *  @param peripheral		The peripheral providing this information.
 *  @param characteristic	A <code>CBCharacteristic</code> object.
 *	@param error			If an error occurred, the cause of the failure.
 *
 *  @discussion				This method returns the result of a {@link writeValue:forCharacteristic:type:} call, when the <code>CBCharacteristicWriteWithResponse</code> type is used.
 */
- (void)peripheral:(CBPeripheral *)peripheral didWriteValueForCharacteristic:(CBCharacteristic *)characteristic error:(nullable NSError *)error
{
    // 设备蓝牙连接成功，通过调用writeValue:forCharacteristic:type:并且type为CBCharacteristicWriteWithResponse时回调，标识向设备发送数据成功
    if (_BDWriteCharacteristicResponseListener) {
        // {"pid0":{"peripheral":Object,"name":"","services":{"sid0":{"service":Object,"isPrimary":"","characteristics":{"cid0":{"characteristic":Object,"type":"notify/read/write"}}}}}}
        NSString* serviceId = nil;
        NSDictionary* pDict = [self.connectedBDPeripheralList objectForKey:peripheral.identifier.UUIDString];
        if (pDict) {
            NSDictionary* servicesDict = [pDict objectForKey:@"services"];
            for (NSString* sid in [servicesDict allKeys]) {
                NSDictionary* ssDict = [servicesDict objectForKey:sid];
                if (ssDict) {
                    NSDictionary* characteristicsDict = [ssDict objectForKey:@"characteristics"];
                    if (characteristicsDict) {
                        NSArray* cidArray = [characteristicsDict allKeys];
                        if ([cidArray containsObject:characteristic.UUID.UUIDString]) {
                            serviceId = sid;
                            break;
                        }
                    }
                }
            }
            [self logDebug:peripheral.identifier.UUIDString sid:serviceId cid:characteristic.UUID.UUIDString message:@"向外设写入数据响应"];
            _BDWriteCharacteristicResponseListener(peripheral.identifier.UUIDString, serviceId, characteristic.UUID.UUIDString, nil);
        } else {
            [self logWarn:peripheral.identifier.UUIDString sid:nil cid:characteristic.UUID.UUIDString message:@"连接中外设为空"];
        }
    } else {
        [self logWarn:peripheral.identifier.UUIDString sid:nil cid:characteristic.UUID.UUIDString message:@"BDWriteCharacteristicResponseListener为空"];
    }
}

/*!
 *  @method peripheral:didUpdateNotificationStateForCharacteristic:error:
 *
 *  @param peripheral		The peripheral providing this information.
 *  @param characteristic	A <code>CBCharacteristic</code> object.
 *	@param error			If an error occurred, the cause of the failure.
 *
 *  @discussion				This method returns the result of a @link setNotifyValue:forCharacteristic: @/link call.
 */
- (void)peripheral:(CBPeripheral *)peripheral didUpdateNotificationStateForCharacteristic:(CBCharacteristic *)characteristic error:(nullable NSError *)error
{
    // 设备蓝牙连接成功，通过调用setNotifyValue:forCharacteristic:设置notify characteristic是否可用时回调
    if (_BDNotifyCharacteristicEnableListener) {
        // {"pid0":{"peripheral":Object,"name":"","services":{"sid0":{"service":Object,"isPrimary":"","characteristics":{"cid0":{"characteristic":Object,"type":"notify/read/write"}}}}}}
        NSString* serviceId = nil;
        NSDictionary* pDict = [self.connectedBDPeripheralList objectForKey:peripheral.identifier.UUIDString];
        if (pDict) {
            NSDictionary* servicesDict = [pDict objectForKey:@"services"];
            for (NSString* sid in [servicesDict allKeys]) {
                NSDictionary* ssDict = [servicesDict objectForKey:sid];
                if (ssDict) {
                    NSDictionary* characteristicsDict = [ssDict objectForKey:@"characteristics"];
                    if (characteristicsDict) {
                        NSArray* cidArray = [characteristicsDict allKeys];
                        if ([cidArray containsObject:characteristic.UUID.UUIDString]) {
                            serviceId = sid;
                            break;
                        }
                    }
                }
            }
            [self logDebug:peripheral.identifier.UUIDString sid:serviceId cid:characteristic.UUID.UUIDString message:@"订阅外设特征值响应"];
            _BDNotifyCharacteristicEnableListener(peripheral.identifier.UUIDString, serviceId, characteristic.UUID.UUIDString, nil);
        } else {
            [self logWarn:peripheral.identifier.UUIDString sid:nil cid:characteristic.UUID.UUIDString message:@"连接中外设为空"];
        }
    } else {
        [self logWarn:peripheral.identifier.UUIDString sid:nil cid:characteristic.UUID.UUIDString message:@"BDNotifyCharacteristicEnableListener为空"];
    }
}

/*!
 *  @method peripheral:didDiscoverDescriptorsForCharacteristic:error:
 *
 *  @param peripheral		The peripheral providing this information.
 *  @param characteristic	A <code>CBCharacteristic</code> object.
 *	@param error			If an error occurred, the cause of the failure.
 *
 *  @discussion				This method returns the result of a @link discoverDescriptorsForCharacteristic: @/link call. If the descriptors were read successfully,
 *							they can be retrieved via <i>characteristic</i>'s <code>descriptors</code> property.
 */
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverDescriptorsForCharacteristic:(CBCharacteristic *)characteristic error:(nullable NSError *)error
{
    // 设备蓝牙连接成功，通过调用discoverDescriptorsForCharacteristic:获取characteristic descriptors回调
    
}

/*!
 *  @method peripheral:didUpdateValueForDescriptor:error:
 *
 *  @param peripheral		The peripheral providing this information.
 *  @param descriptor		A <code>CBDescriptor</code> object.
 *	@param error			If an error occurred, the cause of the failure.
 *
 *  @discussion				This method returns the result of a @link readValueForDescriptor: @/link call.
 */
- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForDescriptor:(CBDescriptor *)descriptor error:(nullable NSError *)error
{
    // 设备蓝牙连接成功，通过调用readValueForDescriptor:获取descriptor value回调
    
}

/*!
 *  @method peripheral:didWriteValueForDescriptor:error:
 *
 *  @param peripheral		The peripheral providing this information.
 *  @param descriptor		A <code>CBDescriptor</code> object.
 *	@param error			If an error occurred, the cause of the failure.
 *
 *  @discussion				This method returns the result of a @link writeValue:forDescriptor: @/link call.
 */
- (void)peripheral:(CBPeripheral *)peripheral didWriteValueForDescriptor:(CBDescriptor *)descriptor error:(nullable NSError *)error
{
    // 设备蓝牙连接成功，通过调用writeValue:forDescriptor:时回调，表示向设备descriptor写入数据成功
    
}

#pragma mark - private method
- (NSMutableDictionary *)scanBDList
{
    if (_scanBDList == nil) {
        _scanBDList = [[NSMutableDictionary alloc] init];
    }
    
    return _scanBDList;
}

- (NSMutableDictionary *)connectedBDPeripheralList
{
    if (_connectedBDPeripheralList == nil) {
        _connectedBDPeripheralList = [[NSMutableDictionary alloc] init];
    }
    
    return _connectedBDPeripheralList;
}

- (NSMutableDictionary *)disconnectBDPeripheralList
{
    if (_disconnectBDPeripheralList == nil) {
        _disconnectBDPeripheralList = [[NSMutableDictionary alloc] init];
    }
    
    return _disconnectBDPeripheralList;
}

#pragma mark - log
- (void) logDebug:(NSString *)pid sid:(NSString *)sid cid:(NSString *)cid message:(NSString *)message
{
    SLogDebug(@"%@ | %d | %@ | %@ | %@ | %@", BLE_CENTRAL_MANAGER_ERROR, _BCMState, pid, sid, cid, message);
}

- (void) logWarn:(NSString *)pid sid:(NSString *)sid cid:(NSString *)cid message:(NSString *)message
{
    SLogWarn(@"%@ | %d | %@ | %@ | %@ | %@", BLE_CENTRAL_MANAGER_ERROR, _BCMState, pid, sid, cid, message);
}

- (void) logError:(NSString *)pid sid:(NSString *)sid cid:(NSString *)cid message:(NSString *)message
{
    SLogError(@"%@ | %d | %@ | %@ | %@ | %@", BLE_CENTRAL_MANAGER_ERROR, _BCMState, pid, sid, cid, message);
}

@end
