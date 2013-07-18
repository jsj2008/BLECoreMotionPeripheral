//
//  NSDAppDelegate.h
//  BLECoreMotionPeripheral
//
//  Created by voxels on 7/17/13.
//  Copyright (c) 2013 com.noisederived. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreMotion/CoreMotion.h>
#import "NSDPeripheralModelController.h"

@interface NSDAppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;
@property (strong, nonatomic, readonly) CMMotionManager *sharedManager;
@property (strong, nonatomic ) NSDPeripheralModelController *peripheralController;


@end
