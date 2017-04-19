//
//  SunbeamBLECentralManager.h
//  Pods
//
//  Created by sunbeam on 16/9/21.
//
//

#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>

#define SUNBEAM_BLE_CENTRAL_SERVICE_VERSION @"0.1.16"

// 扫描蓝牙设备
typedef void(^ScanPeripheralListBlock)(CBPeripheral* peripheral, NSDictionary* advertisement, NSNumber* RSSI);

// 蓝牙连接成功
typedef void(^ConnectPeripheralSuccessBlock)(CBPeripheral* peripheral);

// 蓝牙连接失败
typedef void(^ConnectPeripheralFailBlock)(CBPeripheral* peripheral, NSError* error);

// 蓝牙连接断开
typedef void(^DisconnectPeripheralBlock)(CBPeripheral* peripheral);

// 发现蓝牙设备服务
typedef void(^DiscoverPeripheralServiceListBlock)(CBPeripheral* peripheral, NSError* error);

// 发现蓝牙设备特征值
typedef void(^DiscoverPeripheralServiceCharacteristicListBlock)(CBPeripheral* peripheral, CBService* service, NSError* error);

// 接收蓝牙设备发送的数据
typedef void(^ReceivedConnectedPeripheralNotifyValueBlock)(CBPeripheral* peripheral, CBCharacteristic* characteristic, NSError* error);

// 读取蓝牙设备RSSI值后收到回调
typedef void(^ReceivedConnectedPeripheralRSSIValueBlock)(NSNumber* RSSI, NSError* error);

// 向设备写数据后回调
typedef void(^SendDataResponseBlock)(NSError* error);

// 蓝牙功能开启关闭通知
typedef void(^BluetoothStateChanged)(BOOL isOn);

@interface SunbeamBLECentralManager : NSObject

// 设备蓝牙功能是否开启
@property (nonatomic, assign, readonly) BOOL isBluetoothEnabled;

// 连接中的设备对象
@property (nonatomic, strong, readonly) CBPeripheral* connectedPeripheral;

// 写特征
@property (nonatomic, strong) CBCharacteristic* sunbeamBLEWriteCharacteristic;

// 通知特征
@property (nonatomic, strong) CBCharacteristic* sunbeamBLENotifyCharacteristic;

/**
 单例

 @return SunbeamBLECentralManager
 */
+ (SunbeamBLECentralManager *) sharedSunbeamBLECentralManager;

/**
 初始化中心设备管理对象(即初始化当前设备为蓝牙中心设备)
 */
- (void) initSunbeamBLECentralManagerWithQueue:(dispatch_queue_t)queue options:(NSDictionary<NSString *, id> *) options;

/**
 开始监听蓝牙状态

 @param bluetoothStateChanged 蓝牙状态改变回调
 */
- (void) startListenBluetoothState:(BluetoothStateChanged) bluetoothStateChanged;

/**
 1、扫描蓝牙外围设备

 @param services                扫描服务列表
 @param options                 扫描配置
 @param scanPeripheralListBlock 扫描回调
 */
- (void) scanPeripheralListWithServices:(NSArray *) services options:(NSDictionary *)options scanPeripheralListBlock:(ScanPeripheralListBlock) scanPeripheralListBlock;

/**
 1.1、停止扫描
 */
- (void) stopScan;

/**
 2、连接指定外围设备对象

 @param peripheral                    外围设备对象
 @param options                       连接配置
 @param connectPeripheralSuccessBlock 连接成功回调
 @param connectPeripheralFailBlock    连接失败回调
 @param disconnectPeripheralBlock     连接成功后主动/异常断开回调
 */
- (void) connectPeripheral:(CBPeripheral *) peripheral options:(NSDictionary *)options connectPeripheralSuccessBlock:(ConnectPeripheralSuccessBlock) connectPeripheralSuccessBlock connectPeripheralFailBlock:(ConnectPeripheralFailBlock) connectPeripheralFailBlock disconnectPeripheralBlock:(DisconnectPeripheralBlock) disconnectPeripheralBlock;

/**
 2.1、断开连接中的外围设备对象
 
 采用默认规则：
 主动断开时不接收蓝牙连接断开通知。
 异常断开时接收蓝牙连接断开通知。
 */
- (void) disconnectPeripheralWithDefaultStrategy;

/**
 2.1、断开连接中的外围设备对象
 
 采用自定义规则：
 主动断开时，根据receiveDisconnectPeripheralNotifyOrNot的值判断是否接收蓝牙连接断开回调。
 异常断开时接收蓝牙连接断开通知。

 @param receiveDisconnectPeripheralNotifyOrNot 是否接收连接断开通知 YES:接收；NO:不接收。
 */
- (void) disconnectPeripheralWithCustomStrategy:(BOOL) receiveDisconnectPeripheralNotifyOrNot;

/**
 3、发现外围设备服务列表

 @param services                           外围设备服务列表
 @param discoverPeripheralServiceListBlock 发现服务回调
 */
- (void) discoverPeripheralServiceList:(NSArray *) services discoverPeripheralServiceListBlock:(DiscoverPeripheralServiceListBlock) discoverPeripheralServiceListBlock;

/**
 4、发现外围设备服务特征值列表

 @param characteristics                                  特征值列表
 @param services                                         外围设备服务列表
 @param discoverPeripheralServiceCharacteristicListBlock 发现外围设备服务特征值回调
 @param receivedConnectedPeripheralNotifyValueBlock      设备发送过来的信息
 */
- (void) discoverPeripheralServiceCharacteristicList:(NSArray *)characteristics forService:(NSArray *)services discoverPeripheralServiceCharacteristicListBlock:(DiscoverPeripheralServiceCharacteristicListBlock) discoverPeripheralServiceCharacteristicListBlock receivedConnectedPeripheralNotifyValueBlock:(ReceivedConnectedPeripheralNotifyValueBlock) receivedConnectedPeripheralNotifyValueBlock;

/**
 5、读取当前连接的外围设备RSSI值

 @param receivedConnectedPeripheralRSSIValueBlock 收到设备RSSI值回调
 */
- (void) readConnectedPeripheralRSSIValue:(ReceivedConnectedPeripheralRSSIValueBlock) receivedConnectedPeripheralRSSIValueBlock;

/**
 向连接中的外围设备发送数据

 @param data 数据
 */
- (void) sendDataToConnectedPeripheral:(NSMutableArray<NSData *> *) data sendCompletion:(SendDataResponseBlock) sendCompletion;

@end
