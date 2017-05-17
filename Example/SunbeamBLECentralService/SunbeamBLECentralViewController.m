//
//  SunbeamBLECentralViewController.m
//  SunbeamBLECentralService
//
//  Created by sunbeamChen on 09/21/2016.
//  Copyright (c) 2016 sunbeamChen. All rights reserved.
//

#import "SunbeamBLECentralViewController.h"
#import <SunbeamBLECentralService/SunbeamBLECentralService.h>

#define SHERLOCK_SERVICE @"0000fee9-0000-1000-8000-00805f9b34fb"

@interface SunbeamBLECentralViewController ()

@end

@implementation SunbeamBLECentralViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    
    [[SBluetoothCentralManager sharedSBluetoothCentralManager] openBCM:^(int state, NSError *error) {
        [[SBluetoothCentralManager sharedSBluetoothCentralManager] registBDFoundListener:^(NSString *pid, NSString *name, int state, NSDictionary *advertisement, NSNumber *rssi) {
            if ([[advertisement objectForKey:@"kCBAdvDataLocalName"] isEqualToString:@"SherLock_056"]) {
                [[SBluetoothCentralManager sharedSBluetoothCentralManager] stopScanBD:^(NSError *error) {
                    [[SBluetoothCentralManager sharedSBluetoothCentralManager] createBDConnection:pid BDCreateConnectResultListener:^(NSString *pid, NSError *error) {
                        [[SBluetoothCentralManager sharedSBluetoothCentralManager] readBDRSSIValue:pid BDRSSIValueReadListener:^(NSString *pid, NSNumber *rssi, NSError *error) {
                            [[SBluetoothCentralManager sharedSBluetoothCentralManager] discoverBDServices:pid BDServiceFoundListener:^(NSString *pid, NSArray *services, NSError *error) {
                                if ([services containsObject:@"0000FEE9-0000-1000-8000-00805F9B34FB"]) {
                                    [[SBluetoothCentralManager sharedSBluetoothCentralManager] discoverBDCharacteristics:pid sid:@"0000FEE9-0000-1000-8000-00805F9B34FB" BDCharacteristicFoundListener:^(NSString *pid, NSString *sid, NSArray *characteristics, NSError *error) {
                                        if ([characteristics containsObject:@"D44BC439-ABFD-45A2-B575-925416129600"]) {
                                            // write特征值
                                            [[SBluetoothCentralManager sharedSBluetoothCentralManager] enableBDNotifyCharacteristic:pid sid:sid cid:@"D44BC439-ABFD-45A2-B575-925416129600" subFlag:YES BDNotifyCharacteristicEnableListener:^(NSString *pid, NSString *sid, NSString *cid, NSError *error) {
                                                if ([characteristics containsObject:@"D44BC439-ABFD-45A2-B575-925416129601"]) {
                                                    // notify特征值
                                                    [[SBluetoothCentralManager sharedSBluetoothCentralManager] enableBDNotifyCharacteristic:pid sid:sid cid:@"D44BC439-ABFD-45A2-B575-925416129601" subFlag:YES BDNotifyCharacteristicEnableListener:^(NSString *pid, NSString *sid, NSString *cid, NSError *error) {
                                                        
                                                    }];
                                                } else {
                                                    NSLog(@"未发现夏洛克服务notify特征值");
                                                }
                                            }];
                                        } else {
                                            NSLog(@"未发现夏洛克服务write特征值");
                                        }
                                    }];
                                } else {
                                    NSLog(@"未发现夏洛克服务");
                                }
                            }];
                        }];
                    }];
                }];
            }
        }];
        
        [[SBluetoothCentralManager sharedSBluetoothCentralManager] registBDDisconnectStateListener:^(NSString *pid, NSError *error) {
            [[SBluetoothCentralManager sharedSBluetoothCentralManager] closeBCM:^(int state, NSError *error) {
                
            }];
        }];
        
        [[SBluetoothCentralManager sharedSBluetoothCentralManager] registBDCharacteristicValueListener:^(NSString *pid, NSString *sid, NSString *cid, NSData *value, NSError *error) {
            [[SBluetoothCentralManager sharedSBluetoothCentralManager] closeBDConnection:pid BDCloseConnectResultListener:^(NSString *pid, NSError *error) {
                
            }];
        }];
        
        [[SBluetoothCentralManager sharedSBluetoothCentralManager] getBCMState:^(int state, NSError *error) {
            if (state == 2) {
                [[SBluetoothCentralManager sharedSBluetoothCentralManager] startScanBD:@[SHERLOCK_SERVICE] completion:^(NSError *error) {
                    
                }];
            }
        }];
    }];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
