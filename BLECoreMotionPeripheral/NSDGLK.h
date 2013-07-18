//
//  nsdGLK.h
//  HelloGLBuffers
//
//  Created by voxels on 7/4/13.
//  Copyright (c) 2013 com.noisederived. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <GLKit/GLKit.h>
#import <CoreMotion/CoreMotion.h>
#import "NSDPeripheralModelController.h"


@interface NSDGLK : GLKViewController {
    
    GLKMatrix4 _coreMotionMatrix;

}

@property (strong, nonatomic) NSDPeripheralModelController *peripheralController;

@end
