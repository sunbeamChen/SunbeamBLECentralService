//
//  SunbeamBLECentralManager.m
//  Pods
//
//  Created by sunbeam on 16/9/21.
//
//

#import "SunbeamBLECentralManager.h"
#import "SunbeamBLECentralConstants.h"

#define SUNBEAM_BLE_CENTRAL_MANAGER_ERROR_DOMAIN @"com.sunbeam.ble.error.central"

@interface SunbeamBLECentralManager() <CBCentralManagerDelegate, CBPeripheralDelegate>

// 连接中的设备对象
@property (nonatomic, strong, readwrite) CBPeripheral* connectedPeripheral;

// 设备蓝牙功能是否开启
@property (nonatomic, assign, readwrite) BOOL isBluetoothEnabled;

// 扫描block
@property (nonatomic, strong) ScanPeripheralListBlock scanPeripheralListBlock;

// 蓝牙连接成功block
@property (nonatomic, strong) ConnectPeripheralSuccessBlock connectPeripheralSuccessBlock;

// 蓝牙连接失败block
@property (nonatomic, strong) ConnectPeripheralFailBlock connectPeripheralFailBlock;

// 蓝牙连接断开block
@property (nonatomic, strong) DisconnectPeripheralBlock disconnectPeripheralBlock;

// 发现蓝牙设备服务block
@property (nonatomic, strong) DiscoverPeripheralServiceListBlock discoverPeripheralServiceListBlock;

// 发现蓝牙设备特征值block
@property (nonatomic, strong) DiscoverPeripheralServiceCharacteristicListBlock discoverPeripheralServiceCharacteristicListBlock;

// 接收蓝牙设备发送的数据block
@property (nonatomic, strong) ReceivedConnectedPeripheralNotifyValueBlock receivedConnectedPeripheralNotifyValueBlock;

// 读取蓝牙设备RSSI值block
@property (nonatomic, strong) ReceivedConnectedPeripheralRSSIValueBlock receivedConnectedPeripheralRSSIValueBlock;

// 写入数据后block
@property (nonatomic, strong) SendDataResponseBlock sendDataResponseBlock;

#pragma mark - private var define

// 中心设备管理器
@property (nonatomic, strong) CBCentralManager* sunbeamBLECentralManager;

// 蓝牙连接是否由APP主动断开 YES:主动断开；NO:异常断开。
@property (nonatomic, assign) BOOL disconnectPeripheralManual;

// 主动断开蓝牙连接通知规则 YES:自定义规则；NO:默认规则。默认为NO
@property (nonatomic, assign) BOOL disconnectPeripheralWithCustomStrategyFlag;

// 主动断开蓝牙连接，自定义是否接收断开通知 YES:接收；NO:不接收。默认为NO
@property (nonatomic, assign) BOOL receiveDisconnectPeripheralNotifyFlag;

// APP内出错使用代码主动断开蓝牙连接
@property (nonatomic, assign) BOOL disconnectPeripheralInAPP;

@end

@implementation SunbeamBLECentralManager

/**
 单例
 
 @return SunbeamBLECentralManager
 */
+ (SunbeamBLECentralManager *) sharedSunbeamBLECentralManager
{
    static SunbeamBLECentralManager *sharedInstance = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

/**
 初始化中心设备管理对象(即初始化当前设备为蓝牙中心设备)
 */
- (void) initSunbeamBLECentralManagerWithQueue:(dispatch_queue_t) queue options:(NSDictionary<NSString *, id> *) options
{
    NSLog(@"sunbeam BLE central service version %@", SUNBEAM_BLE_CENTRAL_SERVICE_VERSION);
    self.isBluetoothEnabled = NO;
    self.disconnectPeripheralWithCustomStrategyFlag = NO;
    self.disconnectPeripheralManual = NO;
    self.receiveDisconnectPeripheralNotifyFlag = NO;
    self.disconnectPeripheralInAPP = NO;
    self.sunbeamBLECentralManager = [[CBCentralManager alloc] initWithDelegate:self queue:queue options:options];
}


/**
 中心管理器对象销毁
 */
- (void)dealloc
{
    self.scanPeripheralListBlock = nil;
    self.connectPeripheralSuccessBlock = nil;
    self.connectPeripheralFailBlock = nil;
    self.disconnectPeripheralBlock = nil;
    self.discoverPeripheralServiceListBlock = nil;
    self.discoverPeripheralServiceCharacteristicListBlock = nil;
    self.receivedConnectedPeripheralNotifyValueBlock = nil;
    self.receivedConnectedPeripheralRSSIValueBlock = nil;
}

/**
 1、扫描蓝牙外围设备
 
 @param services                扫描服务列表
 @param options                 扫描配置
 @param scanPeripheralListBlock 扫描回调
 */
- (void) scanPeripheralListWithServices:(NSArray *) services options:(NSDictionary *)options scanPeripheralListBlock:(ScanPeripheralListBlock) scanPeripheralListBlock
{
    NSAssert(scanPeripheralListBlock != nil, @"scan block should not be nil");
    
    self.scanPeripheralListBlock = scanPeripheralListBlock;
    if (services != nil && [services count] > 0) {
        NSMutableArray* serviceUUIDs = [[NSMutableArray alloc] init];
        for (NSString* serviceString in services) {
            [serviceUUIDs addObject:[CBUUID UUIDWithString:serviceString]];
        }
        [self.sunbeamBLECentralManager scanForPeripheralsWithServices:[serviceUUIDs copy] options:options];
    } else {
        [self.sunbeamBLECentralManager scanForPeripheralsWithServices:nil options:options];
    }
}

/**
 1.1、停止扫描
 */
- (void) stopScan
{
    [self.sunbeamBLECentralManager stopScan];
    self.scanPeripheralListBlock = nil;
}


/**
 2、连接指定外围设备对象
 
 @param peripheral                    外围设备对象
 @param options                       连接配置
 @param connectPeripheralSuccessBlock 连接成功回调
 @param connectPeripheralFailBlock    连接失败回调
 @param disconnectPeripheralBlock     连接成功后主动/异常断开回调
 */
- (void) connectPeripheral:(CBPeripheral *) peripheral options:(NSDictionary *)options connectPeripheralSuccessBlock:(ConnectPeripheralSuccessBlock) connectPeripheralSuccessBlock connectPeripheralFailBlock:(ConnectPeripheralFailBlock) connectPeripheralFailBlock disconnectPeripheralBlock:(DisconnectPeripheralBlock) disconnectPeripheralBlock
{
    NSAssert(connectPeripheralSuccessBlock != nil, @"connect peripheral success block should not be nil");
    
    NSAssert(connectPeripheralFailBlock != nil, @"connect peripheral fail block should not be nil");
    
    NSAssert(disconnectPeripheralBlock != nil, @"disconnect peripheral block should not be nil");
    
    if (peripheral == nil) {
        connectPeripheralFailBlock(nil, [NSError errorWithDomain:SUNBEAM_BLE_CENTRAL_MANAGER_ERROR_DOMAIN code:SBC_ERROR_CONNECT_PERIPHERAL_IS_NIL userInfo:@{NSLocalizedDescriptionKey:@"connect peripheral is nil"}]);
        return;
    }
    self.connectPeripheralSuccessBlock = connectPeripheralSuccessBlock;
    self.connectPeripheralFailBlock = connectPeripheralFailBlock;
    self.disconnectPeripheralBlock = disconnectPeripheralBlock;
    [self.sunbeamBLECentralManager connectPeripheral:peripheral options:options];
}

/**
 2.1、断开连接中的外围设备对象
 
 采用默认规则：
 主动断开时不接收蓝牙连接断开通知。
 异常断开时接收蓝牙连接断开通知。
 */
- (void) disconnectPeripheralWithDefaultStrategy
{
    self.disconnectPeripheralManual = YES;
    self.disconnectPeripheralWithCustomStrategyFlag = NO;
    self.receiveDisconnectPeripheralNotifyFlag = NO;
    if (self.connectedPeripheral) {
        [self.sunbeamBLECentralManager cancelPeripheralConnection:self.connectedPeripheral];
    }
    self.sunbeamBLEWriteCharacteristic = nil;
    self.sunbeamBLENotifyCharacteristic = nil;
    self.connectedPeripheral.delegate = nil;
    self.connectedPeripheral = nil;
}

/**
 2.1、断开连接中的外围设备对象
 
 采用自定义规则：
 根据receiveDisconnectPeripheralNotifyOrNot的值判断是否接收蓝牙连接断开回调。
 
 @param receiveDisconnectPeripheralNotifyOrNot 是否接收连接断开通知 YES:接收；NO:不接收。
 */
- (void) disconnectPeripheralWithCustomStrategy:(BOOL) receiveDisconnectPeripheralNotifyOrNot
{
    self.disconnectPeripheralManual = YES;
    self.disconnectPeripheralWithCustomStrategyFlag = YES;
    self.receiveDisconnectPeripheralNotifyFlag = receiveDisconnectPeripheralNotifyOrNot;
    if (self.connectedPeripheral) {
        [self.sunbeamBLECentralManager cancelPeripheralConnection:self.connectedPeripheral];
    } else {
        // 此时蓝牙已经断开连接，后续不会调用蓝牙断开回调，根据用户定义调用断开通知
        self.disconnectPeripheralManual = NO;
        self.disconnectPeripheralWithCustomStrategyFlag = NO;
        if (self.receiveDisconnectPeripheralNotifyFlag) {
            self.receiveDisconnectPeripheralNotifyFlag = NO;
            NSAssert(self.disconnectPeripheralBlock != nil, @"disconnect peripheral block should not be nil");
            
            self.disconnectPeripheralBlock(nil, [NSError errorWithDomain:SUNBEAM_BLE_CENTRAL_MANAGER_ERROR_DOMAIN code:SBC_ERROR_PERIPHERAL_DISCONNECT_EXCEPTION userInfo:@{NSLocalizedDescriptionKey:@"peripheral disconnect exception"}]);
        }
    }
    self.sunbeamBLEWriteCharacteristic = nil;
    self.sunbeamBLENotifyCharacteristic = nil;
    self.connectedPeripheral.delegate = nil;
    self.connectedPeripheral = nil;
}

/**
 3、发现外围设备服务列表
 
 @param services                           外围设备指定服务列表
 @param discoverPeripheralServiceListBlock 发现服务回调
 */
- (void) discoverPeripheralServiceList:(NSArray *) services discoverPeripheralServiceListBlock:(DiscoverPeripheralServiceListBlock) discoverPeripheralServiceListBlock
{
    NSAssert(discoverPeripheralServiceListBlock != nil, @"discover peripheral service list block should not be nil");
    
    if (![self checkConnectedPeripheralExistOrNot]) {
        return;
    }
    self.discoverPeripheralServiceListBlock = discoverPeripheralServiceListBlock;
    if (services == nil || [services count] <= 0) {
        services = nil;
    }
    [self.connectedPeripheral discoverServices:services];
}


/**
 4、发现外围设备服务特征值列表
 
 @param characteristics                                  特征值列表
 @param services                                         外围设备服务列表
 @param discoverPeripheralServiceCharacteristicListBlock 发现外围设备服务特征值回调
 @param receivedConnectedPeripheralNotifyValueBlock      设备发送过来的信息
 */
- (void) discoverPeripheralServiceCharacteristicList:(NSArray *)characteristics forService:(NSArray *)services discoverPeripheralServiceCharacteristicListBlock:(DiscoverPeripheralServiceCharacteristicListBlock) discoverPeripheralServiceCharacteristicListBlock receivedConnectedPeripheralNotifyValueBlock:(ReceivedConnectedPeripheralNotifyValueBlock) receivedConnectedPeripheralNotifyValueBlock
{
    NSAssert(discoverPeripheralServiceCharacteristicListBlock != nil, @"discover peripheral service characteristic list block should not be nil");
    
    NSAssert(receivedConnectedPeripheralNotifyValueBlock != nil, @"received connected peripheral notify value block should not be nil");
    
    NSAssert(services != nil && [services count] > 0, @" peripheral services should have at least one service when discover characteristic list");
    
    if (![self checkConnectedPeripheralExistOrNot]) {
        return;
    }
    self.discoverPeripheralServiceCharacteristicListBlock = discoverPeripheralServiceCharacteristicListBlock;
    self.receivedConnectedPeripheralNotifyValueBlock = receivedConnectedPeripheralNotifyValueBlock;
    if (characteristics == nil || [characteristics count] <= 0) {
        characteristics = nil;
    }
    for (CBService* service in services) {
        [self.connectedPeripheral discoverCharacteristics:characteristics forService:service];
    }
}


/**
 5、读取当前连接的外围设备RSSI值
 
 @param receivedConnectedPeripheralRSSIValueBlock 收到设备RSSI值回调
 */
- (void) readConnectedPeripheralRSSIValue:(ReceivedConnectedPeripheralRSSIValueBlock) receivedConnectedPeripheralRSSIValueBlock
{
    NSAssert(receivedConnectedPeripheralRSSIValueBlock != nil, @"received connected peripheral RSSI value block should not be nil");
    
    if (![self checkConnectedPeripheralExistOrNot]) {
        return;
    }
    self.receivedConnectedPeripheralRSSIValueBlock = receivedConnectedPeripheralRSSIValueBlock;
    [self.connectedPeripheral readRSSI];
}

/**
 向连接中的外围设备发送数据
 
 @param data 数据(每次最多20字节)
 */
- (void) sendDataToConnectedPeripheral:(NSData *) data responseOrNot:(BOOL) responseOrNot sendDataResponseBlock:(SendDataResponseBlock) sendDataResponseBlock
{
    if (![self checkConnectedPeripheralExistOrNot]) {
        return;
    }
    if (data == nil) {
        NSAssert(self.disconnectPeripheralBlock != nil, @"disconnect peripheral block should not be nil");
        
        self.disconnectPeripheralBlock(nil, [NSError errorWithDomain:SUNBEAM_BLE_CENTRAL_MANAGER_ERROR_DOMAIN code:SBC_ERROR_DATA_SEND_IS_NIL userInfo:@{NSLocalizedDescriptionKey:@"data send is nil"}]);
        self.disconnectPeripheralBlock = nil;
        [self disconnectPeripheralInAPPException];
        return;
    }
    if (self.sunbeamBLEWriteCharacteristic == nil) {
        NSAssert(self.disconnectPeripheralBlock != nil, @"disconnect peripheral block should not be nil");
        
        self.disconnectPeripheralBlock(nil, [NSError errorWithDomain:SUNBEAM_BLE_CENTRAL_MANAGER_ERROR_DOMAIN code:SBC_ERROR_PERIPHERAL_WRITE_CHARACTERISTIC_IS_NIL userInfo:@{NSLocalizedDescriptionKey:@"peripheral write characteristic is nil"}]);
        self.disconnectPeripheralBlock = nil;
        [self disconnectPeripheralInAPPException];
        return;
    }
    if (responseOrNot) {
        NSAssert(sendDataResponseBlock != nil, @"send data response block should not be nil when it set to be YES");
        
        self.sendDataResponseBlock = sendDataResponseBlock;
        [self.connectedPeripheral writeValue:data forCharacteristic:self.sunbeamBLEWriteCharacteristic type:CBCharacteristicWriteWithResponse];
    } else {
        [self.connectedPeripheral writeValue:data forCharacteristic:self.sunbeamBLEWriteCharacteristic type:CBCharacteristicWriteWithoutResponse];
    }
}

#pragma mark - private method
/**
 检查当前连接中的蓝牙外设是否为nil

 @return YES/NO
 */
- (BOOL) checkConnectedPeripheralExistOrNot
{
    if (self.connectedPeripheral == nil) {
        NSAssert(self.disconnectPeripheralBlock != nil, @"disconnect peripheral block should not be nil");
        
        self.disconnectPeripheralBlock(nil, [NSError errorWithDomain:SUNBEAM_BLE_CENTRAL_MANAGER_ERROR_DOMAIN code:SBC_ERROR_CONNECTED_PERIPHERAL_IS_NIL userInfo:@{NSLocalizedDescriptionKey:@"connected peripheral is nil"}]);
        self.disconnectPeripheralBlock = nil;
        [self disconnectPeripheralInAPPException];
        return NO;
    }
    
    return YES;
}


/**
 APP内使用代码断开当前蓝牙连接，在代码出现问题时
 */
- (void) disconnectPeripheralInAPPException
{
    self.disconnectPeripheralManual = NO;
    self.disconnectPeripheralInAPP = YES;
    if (self.connectedPeripheral) {
        [self.sunbeamBLECentralManager cancelPeripheralConnection:self.connectedPeripheral];
    }
    self.sunbeamBLEWriteCharacteristic = nil;
    self.sunbeamBLENotifyCharacteristic = nil;
    self.connectedPeripheral.delegate = nil;
    self.connectedPeripheral = nil;
}

#pragma mark - CBCentralManagerDelegate
- (void)centralManagerDidUpdateState:(CBCentralManager *)central
{
    switch (central.state) {
        case CBCentralManagerStatePoweredOn:
        {
            self.isBluetoothEnabled = YES;
            break;
        }
            
        case CBCentralManagerStatePoweredOff:
        case CBCentralManagerStateResetting:
        case CBCentralManagerStateUnauthorized:
        case CBCentralManagerStateUnsupported:
        case CBCentralManagerStateUnknown:
        default:
        {
            self.isBluetoothEnabled = NO;
            break;
        }
    }
}

- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary<NSString *, id> *)advertisementData RSSI:(NSNumber *)RSSI
{
    NSAssert(self.scanPeripheralListBlock != nil, @"scan block should not be nil");
    
    self.scanPeripheralListBlock(peripheral, advertisementData, RSSI);
}

- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral
{
    NSAssert(self.connectPeripheralSuccessBlock != nil, @"connect peripheral success block should not be nil");
    
    self.connectedPeripheral = peripheral;
    self.connectedPeripheral.delegate = self;
    self.connectPeripheralSuccessBlock(peripheral);
    self.connectPeripheralSuccessBlock = nil;
}

- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(nullable NSError *)error
{
    NSAssert(self.connectPeripheralFailBlock != nil, @"connect peripheral fail block should not be nil");
    
    self.connectPeripheralFailBlock(peripheral, [NSError errorWithDomain:SUNBEAM_BLE_CENTRAL_MANAGER_ERROR_DOMAIN code:SBC_ERROR_CONNECT_PERIPHERAL_FAILED userInfo:@{NSLocalizedDescriptionKey:@"connect peripheral failed"}]);
    self.connectPeripheralFailBlock = nil;
}

- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(nullable NSError *)error
{
    if (self.disconnectPeripheralManual) {
        // 主动断开蓝牙连接时需要根据用户断开策略进行后续处理
        self.disconnectPeripheralManual = NO;
        if (self.disconnectPeripheralWithCustomStrategyFlag) {
            // 主动断开，自定义规则
            self.disconnectPeripheralWithCustomStrategyFlag = NO;
            if (self.receiveDisconnectPeripheralNotifyFlag) {
                // 用户主动断开时希望接收断开回调
                self.receiveDisconnectPeripheralNotifyFlag = NO;
                NSAssert(self.disconnectPeripheralBlock != nil, @"disconnect peripheral block should not be nil");
                
                self.disconnectPeripheralBlock(peripheral, [NSError errorWithDomain:SUNBEAM_BLE_CENTRAL_MANAGER_ERROR_DOMAIN code:SBC_ERROR_PERIPHERAL_DISCONNECT_EXCEPTION userInfo:@{NSLocalizedDescriptionKey:@"peripheral disconnect exception"}]);
            }
        }
    } else {
        if (self.disconnectPeripheralInAPP) {
            // 代码内部断开蓝牙连接，此时回调已经完成
            self.disconnectPeripheralInAPP = NO;
        } else {
            // 蓝牙连接异常断开时，调用断开回调
            NSAssert(self.disconnectPeripheralBlock != nil, @"disconnect peripheral block should not be nil");
            
            self.disconnectPeripheralBlock(peripheral, [NSError errorWithDomain:SUNBEAM_BLE_CENTRAL_MANAGER_ERROR_DOMAIN code:SBC_ERROR_PERIPHERAL_DISCONNECT_EXCEPTION userInfo:@{NSLocalizedDescriptionKey:@"peripheral disconnect exception"}]);
            self.sunbeamBLEWriteCharacteristic = nil;
            self.sunbeamBLENotifyCharacteristic = nil;
            self.connectedPeripheral.delegate = nil;
            self.connectedPeripheral = nil;
        }
    }
    self.discoverPeripheralServiceListBlock = nil;
    self.discoverPeripheralServiceCharacteristicListBlock = nil;
    self.disconnectPeripheralBlock = nil;
    self.receivedConnectedPeripheralNotifyValueBlock = nil;
    self.receivedConnectedPeripheralRSSIValueBlock = nil;
}

#pragma mark - CBPeripheralDelegate
-(void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error
{
    NSAssert(self.discoverPeripheralServiceListBlock != nil, @"discover peripheral service list block should not be nil");
    
    if (error) {
        self.discoverPeripheralServiceListBlock(peripheral, [NSError errorWithDomain:SUNBEAM_BLE_CENTRAL_MANAGER_ERROR_DOMAIN code:SBC_ERROR_PERIPHERAL_SERVICE_DISCOVER_ERROR userInfo:@{NSLocalizedDescriptionKey:@"peripheral service discover error"}]);
    } else {
        self.discoverPeripheralServiceListBlock(peripheral, nil);
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(nullable NSError *)error
{
    NSAssert(self.discoverPeripheralServiceCharacteristicListBlock != nil, @"discover peripheral service characteristic list block should not be nil");
    
    if (error) {
        self.discoverPeripheralServiceCharacteristicListBlock(peripheral, service, [NSError errorWithDomain:SUNBEAM_BLE_CENTRAL_MANAGER_ERROR_DOMAIN code:SBC_ERROR_PERIPHERAL_SERVICE_CHARACTERISTIC_DISCOVER_ERROR userInfo:@{NSLocalizedDescriptionKey:@"peripheral service characteristic discover error"}]);
    } else {
        self.discoverPeripheralServiceCharacteristicListBlock(peripheral, service, nil);
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(nullable NSError *)error
{
    NSAssert(self.receivedConnectedPeripheralNotifyValueBlock != nil, @"received connected peripheral notify value block should not be nil");
    
    if (error) {
        self.receivedConnectedPeripheralNotifyValueBlock(peripheral, characteristic, [NSError errorWithDomain:SUNBEAM_BLE_CENTRAL_MANAGER_ERROR_DOMAIN code:SBC_ERROR_RECEIVED_CONNECTED_PERIPHERAL_NOTIFY_VALUE_BLOCK_IS_NIL userInfo:@{NSLocalizedDescriptionKey:@"received connected peripheral notify value block is nil"}]);
    } else {
        self.receivedConnectedPeripheralNotifyValueBlock(peripheral, characteristic, nil);
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didReadRSSI:(NSNumber *)RSSI error:(nullable NSError *)error
{
    NSAssert(self.receivedConnectedPeripheralRSSIValueBlock != nil, @"received connected peripheral RSSI value block should not be nil");
    
    if (error) {
        self.receivedConnectedPeripheralRSSIValueBlock(RSSI, [NSError errorWithDomain:SUNBEAM_BLE_CENTRAL_MANAGER_ERROR_DOMAIN code:SBC_ERROR_RECEIVED_CONNECTED_PERIPHERAL_RSSI_VALUE_BLOCK_IS_NIL userInfo:@{NSLocalizedDescriptionKey:@"received connected peripheral RSSI value block is nil"}]);
    } else {
        self.receivedConnectedPeripheralRSSIValueBlock(RSSI, nil);
    }
    self.receivedConnectedPeripheralRSSIValueBlock = nil;
}

- (void)peripheral:(CBPeripheral *)peripheral didWriteValueForCharacteristic:(CBCharacteristic *)characteristic error:(nullable NSError *)error
{
    if (self.sendDataResponseBlock) {
        if (error) {
            NSLog(@"实际写入数据后回调错误error为：%@", error);
            self.sendDataResponseBlock(characteristic, [NSError errorWithDomain:SUNBEAM_BLE_CENTRAL_MANAGER_ERROR_DOMAIN code:SBC_ERROR_WRITE_VALUE_TO_PERIPHERAL_ERROR userInfo:@{NSLocalizedDescriptionKey:@"write value to peripheral error"}]);
        } else {
            self.sendDataResponseBlock(characteristic, nil);
        }
    }
}

@end
