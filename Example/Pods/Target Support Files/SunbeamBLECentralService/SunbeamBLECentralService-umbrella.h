#ifdef __OBJC__
#import <UIKit/UIKit.h>
#else
#ifndef FOUNDATION_EXPORT
#if defined(__cplusplus)
#define FOUNDATION_EXPORT extern "C"
#else
#define FOUNDATION_EXPORT extern
#endif
#endif
#endif

#import "SBluetoothCentralManager.h"
#import "SunbeamBLECentralManager.h"
#import "SunbeamBLECentralService.h"

FOUNDATION_EXPORT double SunbeamBLECentralServiceVersionNumber;
FOUNDATION_EXPORT const unsigned char SunbeamBLECentralServiceVersionString[];

