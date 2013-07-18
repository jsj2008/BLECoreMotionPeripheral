//
//  NSDPeripheralModelController.h
//  BLECoreMotionPeripheral
//
//  Created by voxels on 7/17/13.
//  Copyright (c) 2013 com.noisederived. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>

#import <GLKit/GLKit.h>

@interface NSDPeripheralModelController : NSObject
@property (strong, nonatomic) CBPeripheralManager *peripheralManager;
@property (strong, nonatomic) NSNumber *currentlySendingData;
@property (strong, nonatomic) NSData *rotationMatrixData;

- (void) viewWillDisappear;
- (void) viewDidAppear;
- (void) sendMatrixData;

@end
