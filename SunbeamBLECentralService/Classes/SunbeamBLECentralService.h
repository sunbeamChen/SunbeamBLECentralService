//
//  SunbeamBLECentralService.h
//  Pods
//
//  Created by sunbeam on 16/9/21.
//
//
#import <Foundation/Foundation.h>

FOUNDATION_EXPORT double SunbeamBLECentralServiceVersionNumber;
FOUNDATION_EXPORT const unsigned char SunbeamBLECentralServiceVersionString[];

// 蓝牙中心设备管理器，提供扫描、连接、回调等一系列方法操作
// 支持多连接
#import "SBluetoothCentralManager.h"

// 支持单个连接
#import "SunbeamBLECentralManager.h"
