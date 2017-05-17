//
//  SBluetoothCentralManager.h
//  Pods
//
//  Created by sunbeam on 2017/4/20.
//
//

#import <Foundation/Foundation.h>

#define SUNBEAM_BLE_CENTRAL_SERVICE_MULTI_CONNECTION_VERSION @"0.2.2"

/**
 read me
 BCM : Bluetooth Central Manager
 BD : Bluetooth Device
 pid : peripheral uuid
 sid : peripheral service uuid
 cid : peripheral service characteristic uuid
 */

/**
 BCM open listener

 state - bluetooth central manager state
 error
 */
typedef void(^BCMOpenListener)(int state, NSError* error);

/**
 BCM close listener
 
 state - bluetooth central manager state
 error
 */
typedef void(^BCMCloseListener)(int state, NSError* error);

/**
 bluetooth device found listener
 
 pid - peripheral uuid
 state - BD connection state (0-disconnected；1-connecting；2-connected；)
 advertisement - peripheral advertisement data
 RSSI - peripheral rssi value
 */
typedef void(^BDFoundListener)(NSString* pid, NSString* name, int state, NSDictionary* advertisement, NSNumber* rssi);

/**
 create bluetooth device connect result listener
 
 pid - peripheral id
 error
 */
typedef void(^BDCreateConnectResultListener)(NSString* pid, NSError* error);

/**
 close bluetooth device connect result listener
 
 pid - peripheral id
 error
 */
typedef void(^BDCloseConnectResultListener)(NSString* pid, NSError* error);

/**
 bluetooth device state disconnect listener
 
 pid - peripheral uuid
 error
 */
typedef void(^BDDisconnectStateListener)(NSString* pid, NSError* error);

/**
 bluetooth device sevice found listener
 
 pid - peripheral uuid
 services - peripheral services uuid ["sid0","sid1",...]
 error
 */
typedef void(^BDServiceFoundListener)(NSString* pid, NSArray* services, NSError* error);

/**
 bluetooth device characteristic found listener
 
 pid - peripheral uuid
 sid - peripheral service uuid
 characteristics - peripheral service characteristics uuid - ["cid0","cid1",...]
 error
 */
typedef void(^BDCharacteristicFoundListener)(NSString* pid, NSString* sid, NSArray* characteristics, NSError* error);

/**
 bluetooth device notify characteristic enable listener
 
 pid - peripheral uuid
 sid - peripheral service uuid
 cid - peripheral service characteristic uuid
 error
 */
typedef void(^BDNotifyCharacteristicEnableListener)(NSString* pid, NSString* sid, NSString* cid, NSError* error);

/**
 bluetooth device characteristic value listener
 
 pid - peripheral uuid
 sid - peripheral service uuid
 cid - peripheral service characteristic uuid
 error
 */
typedef void(^BDCharacteristicValueListener)(NSString* pid, NSString* sid, NSString* cid, NSData* value, NSError* error);

/**
 bluetooth device write characteristic response listener
 
 pid - peripheral uuid
 sid - peripheral service uuid
 cid - peripheral service characteristic uuid
 error
 */
typedef void(^BDWriteCharacteristicResponseListener)(NSString* pid, NSString* sid, NSString* cid, NSError* error);

/**
 bluetooth device rssi value read listener
 
 pid - peripheral uuid
 rssi - rssi value
 error
 */
typedef void(^BDRSSIValueReadListener)(NSString* pid, NSNumber* rssi, NSError* error);

@interface SBluetoothCentralManager : NSObject

/**
 singleton instance
 
 @return SBluetoothCentralManager
 */
+ (SBluetoothCentralManager *) sharedSBluetoothCentralManager;

/**
 初始化BCM

 @param logOn 是否打印日志
 @param BCMOpenListener 回调
 */
- (void) openBCM:(BOOL) logOn BCMOpenListener:(BCMOpenListener) BCMOpenListener;

/**
 销毁BCM（同时断开所有设备连接）

 @param BCMCloseListener 回调
 */
- (void) closeBCM:(BCMCloseListener) BCMCloseListener;

/**
 获取BCM状态

 @param completion 回调 
 state:0-not available,fatal error；1-not available,is discovering；2-available；
 */
- (void) getBCMState:(void(^)(int state, NSError* error)) completion;

/**
 扫描所有蓝牙外设

 @param services 扫描指定服务的外设
 @param completion 回调
 */
- (void) startScanBD:(NSArray *) services completion:(void(^)(NSError* error)) completion;

/**
 注册设备发现回调

 @param BDFoundListener 回调
 */
- (void) registBDFoundListener:(BDFoundListener) BDFoundListener;

/**
 获取所有扫描到的外设列表

 @param completion 回调
 scanBDList:扫描到的外设列表
 */
- (void) getAllScanBD:(void(^)(NSMutableArray* scanBDList, NSError* error)) completion;

/**
 获取所有已连接的外设列表

 @param completion 回调
 connectedBDList:连接中的外设列表
 */
- (void) getAllConnectedBD:(void(^)(NSMutableArray* connectedBDList, NSError* error)) completion;

/**
 停止扫描
 
 @param completion 回调
 */
- (void) stopScanBD:(void(^)(NSError* error)) completion;

/**
 连接指定外设

 @param pid 外设id
 @param BDCreateConnectResultListener 回调
 */
- (void) createBDConnection:(NSString *) pid BDCreateConnectResultListener:(BDCreateConnectResultListener) BDCreateConnectResultListener;

/**
 断开指定连接中外设

 @param pid 外设id
 @param BDCloseConnectResultListener 回调
 */
- (void) closeBDConnection:(NSString *) pid BDCloseConnectResultListener:(BDCloseConnectResultListener) BDCloseConnectResultListener;

/**
 注册外设连接异常断开状态回调

 @param BDDisconnectStateListener 回调
 */
- (void) registBDDisconnectStateListener:(BDDisconnectStateListener) BDDisconnectStateListener;

/**
 发现外设服务

 @param pid 外设id
 @param BDServiceFoundListener 外设服务发现回调(单次回调)
 */
- (void) discoverBDServices:(NSString *) pid BDServiceFoundListener:(BDServiceFoundListener) BDServiceFoundListener;

/**
 发现外设特征值

 @param pid 外设id
 @param sid 外设服务id
 @param BDCharacteristicFoundListener 外设特征值发现回调(多次回调)
 */
- (void) discoverBDCharacteristics:(NSString *) pid sid:(NSString *) sid BDCharacteristicFoundListener:(BDCharacteristicFoundListener) BDCharacteristicFoundListener;

/**
 订阅notify特征值

 @param pid 外设id
 @param sid 外设服务id
 @param cid 外设服务特征值id
 @param subFlag 订阅标记
 @param BDNotifyCharacteristicEnableListener 特征值订阅回调
 */
- (void) enableBDNotifyCharacteristic:(NSString *) pid sid:(NSString *) sid cid:(NSString *) cid subFlag:(BOOL) subFlag BDNotifyCharacteristicEnableListener:(BDNotifyCharacteristicEnableListener) BDNotifyCharacteristicEnableListener;

/**
 注册设备数据监听

 @param BDCharacteristicValueListener 数据回调
 */
- (void) registBDCharacteristicValueListener:(BDCharacteristicValueListener) BDCharacteristicValueListener;

/**
 写数据

 @param pid 外设id
 @param sid 外设服务id
 @param cid 外设写特征值id
 @param value 数据
 @param BDWriteCharacteristicResponseListener 写数据完毕回调
 */
- (void) writeValueToBD:(NSString *) pid sid:(NSString *) sid cid:(NSString *) cid value:(NSString *) value BDWriteCharacteristicResponseListener:(BDWriteCharacteristicResponseListener) BDWriteCharacteristicResponseListener;

/**
 读取连接外设rssi值

 @param pid 外设id
 @param BDRSSIValueReadListener 外设rssi值获取成功回调
 */
- (void) readBDRSSIValue:(NSString *) pid BDRSSIValueReadListener:(BDRSSIValueReadListener) BDRSSIValueReadListener;

@end
