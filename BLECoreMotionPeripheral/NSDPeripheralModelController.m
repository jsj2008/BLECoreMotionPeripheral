//
//  NSDPeripheralModelController.m
//  BLECoreMotionPeripheral
//
//  Created by voxels on 7/17/13.
//  Copyright (c) 2013 com.noisederived. All rights reserved.
//

#import "NSDPeripheralModelController.h"
#import "CoreMotionService.h"

@interface NSDPeripheralModelController () <CBPeripheralManagerDelegate>
{
    BOOL readyToUpdate;
}
@property (strong, nonatomic) CBMutableCharacteristic *matrixCharacteristic;
@property (strong, nonatomic) NSData *matrixToSend;
@property (nonatomic, readwrite) NSInteger sendDataIndex;



@end


#define NOTIFY_MTU 20


@implementation NSDPeripheralModelController
@synthesize peripheralManager = _peripheralManager;
@synthesize matrixCharacteristic = _matrixCharacteristic;
@synthesize matrixToSend = _matrixToSend;
@synthesize rotationMatrixData = _rotationMatrixData;

- (id) init
{
    if( self = [super init])
    {
        NSLog( @"INIT peripheral manager");
        self.peripheralManager = [[CBPeripheralManager alloc] initWithDelegate:self queue:nil];
        readyToUpdate = YES;
    }
    
    return self;
}


- (void) viewWillDisappear
{    
    [self.peripheralManager stopAdvertising];
}



- (void) viewDidAppear
{
    NSLog( @"Beginning Advertisement" );
    
    [self.peripheralManager startAdvertising:@{ CBAdvertisementDataLocalNameKey : @"Core Bluetooth Motion Periph" }];
    
    NSLog( @"Advertising is %d", self.peripheralManager.isAdvertising);
}


- (void) peripheralManagerDidUpdateState:(CBPeripheralManager *)peripheral
{
    if( peripheral.state != CBPeripheralManagerStatePoweredOn ){
        NSLog( @"Peripheral manager is not powered on.");
        return;
    }
    
    // We're in CBPeripheralManagerStatePoweredOn state...
    NSLog(@"self.peripheralManager powered on.");
    
    self.matrixCharacteristic = [[CBMutableCharacteristic alloc] initWithType:[CBUUID UUIDWithString:COREMOTION_CHARACTERISTIC_ROTATIONMATRIX_UUID] properties:CBCharacteristicPropertyNotify value:nil permissions:CBAttributePermissionsReadable];
    
    
    // Then the service
    CBMutableService *transferService = [[CBMutableService alloc] initWithType:[CBUUID UUIDWithString:COREMOTION_SERVICE_UUID] primary:YES];
    
    // Add the characteristic to the service
    transferService.characteristics = @[self.matrixCharacteristic];
    
    // And add it to the peripheral manager
    [self.peripheralManager addService:transferService];
    NSLog(@"Added rotation matrix service");
}


/** Catch when someone subscribes to our characteristic, then start sending them data
 */
- (void)peripheralManager:(CBPeripheralManager *)peripheral central:(CBCentral *)central didSubscribeToCharacteristic:(CBCharacteristic *)characteristic
{
    NSLog(@"Central subscribed to characteristic");

    // Get the data
    self.matrixToSend = self.rotationMatrixData;
    
//    self.matrixToSend = [[NSString stringWithFormat:@"SENDING TEST DATA" ] dataUsingEncoding:NSUTF8StringEncoding];
    
    // Reset the index
    self.sendDataIndex = 0;
    
    // Start sending
    [self sendMatrixData];
}


- (void) updateMatrixData
{
    if( readyToUpdate == YES )
    {
        self.matrixToSend = self.rotationMatrixData;
        self.sendDataIndex = 0;
        [self sendMatrixData];
    }
}

/** Recognise when the central unsubscribes
 */
- (void)peripheralManager:(CBPeripheralManager *)peripheral central:(CBCentral *)central didUnsubscribeFromCharacteristic:(CBCharacteristic *)characteristic
{
    NSLog(@"Central unsubscribed from characteristic");
}


- (void) sendMatrixData
{
    readyToUpdate = NO;
    
    // First up, check if we're meant to be sending an EOM
    static BOOL sendingMatrixEOM = NO;
    
    if (sendingMatrixEOM) {
        
        // send it
        BOOL didSendEOM = [self.peripheralManager updateValue:[@"EOM" dataUsingEncoding:NSUTF8StringEncoding] forCharacteristic:self.matrixCharacteristic onSubscribedCentrals:nil];
        
        // Did it send?
        if (didSendEOM) {
            
            // It did, so mark it as sent
            sendingMatrixEOM = NO;
            NSLog(@"Sent Matrix: EOM");
            readyToUpdate = YES;
        }
        
        // It didn't send, so we'll exit and wait for peripheralManagerIsReadyToUpdateSubscribers to call sendData again
        return;
    }
    
    // We're not sending an EOM, so we're sending data
    // Is there any left to send?
    
    if (self.sendDataIndex >= self.matrixToSend.length) {
        
        // No data left.  Do nothing
        return;
    }
    
    BOOL didSendMatrix = YES;
    
    while( didSendMatrix )
    {
        // Make the next chunk
        
        // Work out how big it should be
        NSInteger amountToSend = self.matrixToSend.length - self.sendDataIndex;
        
        // Can't be longer than 20 bytes
        if (amountToSend > NOTIFY_MTU) amountToSend = NOTIFY_MTU;
        
        // Copy out the data we want
        NSData *chunk = [NSData dataWithBytes:self.matrixToSend.bytes+self.sendDataIndex length:amountToSend];
        
        // Send it
        didSendMatrix = [self.peripheralManager updateValue:chunk forCharacteristic:self.matrixCharacteristic onSubscribedCentrals:nil];
        
        // If it didn't work, drop out and wait for the callback
        if (!didSendMatrix) {
//            NSLog( @"NOT YET SENT");
            return;
        }
        
        NSString *stringFromData = [[NSString alloc] initWithData:chunk encoding:NSUTF8StringEncoding];
//        NSLog(@"Sent: %@", stringFromData);
        
        // It did send, so update our index
        
        self.sendDataIndex += amountToSend;
        
        // Was it the last one?
        if (self.sendDataIndex >= self.matrixToSend.length) {
            
            // It was - send an EOM
            
            // Set this so if the send fails, we'll send it next time
            sendingMatrixEOM = YES;
            
            // Send it
            BOOL eomSent = [self.peripheralManager updateValue:[@"EOM" dataUsingEncoding:NSUTF8StringEncoding] forCharacteristic:self.matrixCharacteristic onSubscribedCentrals:nil];
            
            if (eomSent) {
                // It sent, we're all done
                sendingMatrixEOM = NO;
                
                NSLog(@"Sent: EOM");
                readyToUpdate = YES;
            }
            
            return;
        }
    }
}


/** This callback comes in when the PeripheralManager is ready to send the next chunk of data.
 *  This is to ensure that packets will arrive in the order they are sent
 */
- (void)peripheralManagerIsReadyToUpdateSubscribers:(CBPeripheralManager *)peripheral
{
    // Start sending again
    [self sendMatrixData];
}


@end
