//
//  nsdGLK.m
//  HelloGLBuffers
//
//  Created by voxels on 7/4/13.
//  Copyright (c) 2013 com.noisederived. All rights reserved.
//

#import "NSDGLK.h"
#include <math.h>
#import <QuartzCore/QuartzCore.h>
#import "nsdAppDelegate.h"


static const NSTimeInterval deviceMotionMin = 0.01;

typedef struct {
    float Position[3];
    float Color[4];
    float TexCoord[2];
} Vertex;

typedef struct {
    float Position[3];
    float TexCoord[3];
} SkyboxVertex;

const Vertex Vertices[] = {
    // Front
    {{1, -1, 1}, {1, 0, 0, 1}, {1, 0}},
    {{1, 1, 1}, {0, 1, 0, 1}, {1, 1}},
    {{-1, 1, 1}, {0, 0, 1, 1}, {0, 1}},
    {{-1, -1, 1}, {0, 0, 0, 1}, {0, 0}},
    // Back
    {{1, 1, -1}, {1, 0, 0, 1}, {0, 1}},
    {{-1, -1, -1}, {0, 1, 0, 1}, {1, 0}},
    {{1, -1, -1}, {0, 0, 1, 1}, {0, 0}},
    {{-1, 1, -1}, {0, 0, 0, 1}, {1, 1}},
    // Left
    {{-1, -1, 1}, {1, 0, 0, 1}, {1, 0}},
    {{-1, 1, 1}, {0, 1, 0, 1}, {1, 1}},
    {{-1, 1, -1}, {0, 0, 1, 1}, {0, 1}},
    {{-1, -1, -1}, {0, 0, 0, 1}, {0, 0}},
    // Right
    {{1, -1, -1}, {1, 0, 0, 1}, {1, 0}},
    {{1, 1, -1}, {0, 1, 0, 1}, {1, 1}},
    {{1, 1, 1}, {0, 0, 1, 1}, {0, 1}},
    {{1, -1, 1}, {0, 0, 0, 1}, {0, 0}},
    // Top
    {{1, 1, 1}, {1, 0, 0, 1}, {1, 0}},
    {{1, 1, -1}, {0, 1, 0, 1}, {1, 1}},
    {{-1, 1, -1}, {0, 0, 1, 1}, {0, 1}},
    {{-1, 1, 1}, {0, 0, 0, 1}, {0, 0}},
    // Bottom
    {{1, -1, -1}, {1, 0, 0, 1}, {1, 0}},
    {{1, -1, 1}, {0, 1, 0, 1}, {1, 1}},
    {{-1, -1, 1}, {0, 0, 1, 1}, {0, 1}},
    {{-1, -1, -1}, {0, 0, 0, 1}, {0, 0}}
};

const GLubyte Indices[] = {
    // Front
    0, 1, 2,
    2, 3, 0,
    // Back
    4, 6, 5,
    4, 5, 7,
    // Left
    8, 9, 10,
    10, 11, 8,
    // Right
    12, 13, 14,
    14, 15, 12,
    // Top
    16, 17, 18,
    18, 19, 16,
    // Bottom
    20, 21, 22,
    22, 23, 20
};


@interface NSDGLK () {
    GLuint _vertexBuffer;
    GLuint _indexBuffer;
    GLuint _vertexArray;
    GLKMatrix4 _modelViewProjectionMatrix;
    GLKMatrix3 _normalMatrix;
    float _rotation;
    
}
@property (nonatomic, strong ) EAGLContext *context;
@property (nonatomic, strong ) GLKBaseEffect *effect;
@property (nonatomic, strong ) GLKSkyboxEffect *skyboxEffect;
@property (nonatomic, strong ) GLKTextureInfo *cubemap;
@property (strong, nonatomic) GLKReflectionMapEffect *reflectionEffect;

@end


@implementation NSDGLK

@synthesize context = _context;
@synthesize effect = _effect;
@synthesize skyboxEffect = _skyboxEffect;
@synthesize cubemap = _cubemap;
@synthesize reflectionEffect = _reflectionEffect;
@synthesize peripheralController = _peripheralController;


- (void)setupGL {
    
    self.preferredFramesPerSecond = 60;
    
    [EAGLContext setCurrentContext:self.context];
    glEnable( GL_DEPTH_TEST );
    glEnable(GL_CULL_FACE);
    glEnable(GL_BLEND);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    
    
    // GLKBaseEffect handles the standard shader setup
    _effect = [[GLKBaseEffect alloc] init];
    
    // New lines
    glGenVertexArraysOES(1, &_vertexArray);
    glBindVertexArrayOES(_vertexArray);
    
    glGenBuffers(1, &_vertexBuffer);
    glGenBuffers(1, &_indexBuffer);
    
    // Setup texture
    NSDictionary * options = [NSDictionary dictionaryWithObjectsAndKeys:
                              [NSNumber numberWithBool:YES],
                              GLKTextureLoaderOriginBottomLeft,
                              nil];
    
    NSError * error;
    NSString *path = [[NSBundle mainBundle] pathForResource:@"tile_floor" ofType:@"png"];
    GLKTextureInfo * info = [GLKTextureLoader textureWithContentsOfFile:path options:options error:&error];
    if (info == nil) {
        NSLog(@"Error loading file: %@", [error localizedDescription]);
    }
    _effect.texture2d0.name = info.name;
    _effect.texture2d0.enabled = true;
    
    // Setup a Skybox
    _skyboxEffect = [[GLKSkyboxEffect alloc] init];
    NSArray *cubeMapFileNames = [NSArray arrayWithObjects:
                                 [[NSBundle mainBundle] pathForResource:@"cubemap1" ofType:@"png"],
                                 [[NSBundle mainBundle] pathForResource:@"cubemap2" ofType:@"png"],
                                 [[NSBundle mainBundle] pathForResource:@"cubemap3" ofType:@"png"],
                                 [[NSBundle mainBundle] pathForResource:@"cubemap4" ofType:@"png"],
                                 [[NSBundle mainBundle] pathForResource:@"cubemap5" ofType:@"png"],
                                 [[NSBundle mainBundle] pathForResource:@"cubemap6" ofType:@"png"],
                                 nil];
    
    NSError *cubemapError;
    NSDictionary *cubemapOptions = [NSDictionary dictionaryWithObject:[NSNumber numberWithBool:YES]
                                                               forKey:GLKTextureLoaderOriginBottomLeft];
    _cubemap = [GLKTextureLoader cubeMapWithContentsOfFiles:cubeMapFileNames
                                                    options:cubemapOptions
                                                      error:&cubemapError];
    
    _skyboxEffect.textureCubeMap.name = _cubemap.name;
    
    // Setup a Reflection
    //    _reflectionEffect = [[GLKReflectionMapEffect alloc] init];
    //    _reflectionEffect.textureCubeMap.name = _cubemap.name;
    
    // Configure a light
    /*
     _effect.light0.position =
     GLKVector4Make(
     -0.6f,
     1.0f,
     0.4f,
     0.0f); // Directional light
     _effect.light0.enabled = GL_TRUE;
     _effect.light0.diffuseColor = GLKVector4Make(1.0f, 1.0f, 1.0f, 1.0f);
     _effect.light0.transform = _effect.transform;
     
     _effect.light1.enabled = GL_TRUE;
     _effect.light1.diffuseColor = GLKVector4Make(1.0f, 1.f, 1.f, 1.0f);
     _effect.light1.position = GLKVector4Make(-1.f, -1.f, 2.f, 1.0f);
     _effect.light1.specularColor = GLKVector4Make(1.0f, 1.0f, 1.0f, 1.0f);
     _effect.light1.ambientColor = GLKVector4Make(.2, .2, .2, 1.0);
     
     // Set material
     _effect.material.diffuseColor = GLKVector4Make(1.f, 1.f, 1.0f, 1.0f);
     _effect.material.ambientColor = GLKVector4Make(1.f, 1.f, 1.f, 1.0f);
     _effect.material.specularColor = GLKVector4Make(1.0f, 0.0f, 0.0f, 1.0f);
     _effect.material.shininess = 320.0f;
     _effect.material.emissiveColor = GLKVector4Make(0.4f, 0.4, 0.4f, 1.0f);
     */
}



#pragma mark - GLKViewControllerDelegate

// THIS IS WHERE YOU SET STATE
- (void) update
{
//    NSLog(@"timeSinceLastUpdate: %f", self.timeSinceLastUpdate);
//    NSLog(@"timeSinceLastDraw: %f", self.timeSinceLastDraw);
//    NSLog(@"timeSinceFirstResume: %f", self.timeSinceFirstResume);
//    NSLog(@"timeSinceLastResume: %f", self.timeSinceLastResume);
    
    // Set the Projection Matrix
    float aspect = fabsf(self.view.bounds.size.width / self.view.bounds.size.height);
    GLKMatrix4 projectionMatrix = GLKMatrix4MakePerspective(GLKMathDegreesToRadians(65.0f), aspect, 4.0f, 100.0f);
    _effect.transform.projectionMatrix = projectionMatrix;
    _skyboxEffect.transform.projectionMatrix = projectionMatrix;
    
    // Set the ModelViewMatrix
    GLKMatrix4 modelViewMatrix = GLKMatrix4Identity;
    modelViewMatrix = GLKMatrix4Translate(modelViewMatrix, 0.0f, 0.0f, -10.0f);
    //modelViewMatrix = GLKMatrix4Rotate(modelViewMatrix, 3.1415926/3, 1, 0, 0);
    modelViewMatrix = GLKMatrix4Multiply( modelViewMatrix, _coreMotionMatrix );

    _effect.transform.modelviewMatrix = modelViewMatrix;
    
    
//    GLKMatrix4 skyboxModelViewMatrix = GLKMatrix4MakeTranslation(0.0f, 0.0f, -10.0f);
    GLKMatrix4 skyboxModelViewMatrix = GLKMatrix4Identity;

    skyboxModelViewMatrix = GLKMatrix4Rotate(skyboxModelViewMatrix, GLKMathDegreesToRadians(25), 1, 0, 0);
    skyboxModelViewMatrix = GLKMatrix4Rotate(skyboxModelViewMatrix, GLKMathDegreesToRadians(_rotation), 0, 1, 0);
    
    skyboxModelViewMatrix = GLKMatrix4Scale(skyboxModelViewMatrix, 50, 50, 50);
    _skyboxEffect.transform.modelviewMatrix = skyboxModelViewMatrix;
    
    _rotation += 90 * self.timeSinceLastUpdate * 0.5;
}

// THIS IS THE DRAW CALL
#pragma mark - GLKViewDelegate

- (void)glkView:(GLKView *)view drawInRect:(CGRect)rect {
    
    glClearColor(0.0, 0.0, 0.0, 1.0);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT );
    
    [_skyboxEffect prepareToDraw];
    [_skyboxEffect draw];
    
    // This keeps the buffers below from fucking with the skybox
    glBindVertexArrayOES(_vertexArray);
    
    glBindBuffer(GL_ARRAY_BUFFER, _vertexBuffer);
    glBufferData(GL_ARRAY_BUFFER, sizeof(Vertices), Vertices, GL_STATIC_DRAW);
    
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, _indexBuffer);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(Indices), Indices, GL_STATIC_DRAW);
    
    glEnableVertexAttribArray(GLKVertexAttribPosition);
    glVertexAttribPointer(GLKVertexAttribPosition, 3, GL_FLOAT, GL_FALSE, sizeof(Vertex), (const GLvoid *) offsetof(Vertex, Position));
    glEnableVertexAttribArray(GLKVertexAttribColor);
    glVertexAttribPointer(GLKVertexAttribColor, 4, GL_FLOAT, GL_FALSE, sizeof(Vertex), (const GLvoid *) offsetof(Vertex, Color));
    
    glEnableVertexAttribArray(GLKVertexAttribTexCoord0);
    glVertexAttribPointer(GLKVertexAttribTexCoord0, 2, GL_FLOAT, GL_FALSE, sizeof(Vertex), (const GLvoid *) offsetof(Vertex, TexCoord));
    
    [_effect prepareToDraw];
    glDrawElements(GL_TRIANGLES, sizeof(Indices)/sizeof(Indices[0]), GL_UNSIGNED_BYTE, 0);
    
    glBindBuffer( GL_ARRAY_BUFFER, 0 );
    glBindBuffer( GL_ELEMENT_ARRAY_BUFFER, 0 );
    glDisableVertexAttribArray(GLKVertexAttribPosition);
    glDisableVertexAttribArray(GLKVertexAttribColor);
    glDisableVertexAttribArray(GLKVertexAttribTexCoord0);
}


#pragma mark - Boring Stuff
- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)didReceiveMemoryWarning
{
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    _context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
    
    NSTimeInterval delta = 0.005;
    NSTimeInterval updateInterval = deviceMotionMin + delta;
    
    if (!_context) {
        NSLog(@"Failed to create ES context");
    }
    
    CMMotionManager *coreMotionData = [(NSDAppDelegate *) [[UIApplication sharedApplication] delegate] sharedManager];
    
    if ([coreMotionData isDeviceMotionAvailable] == YES) {
        [coreMotionData setDeviceMotionUpdateInterval:updateInterval];
        [coreMotionData startDeviceMotionUpdatesToQueue:[NSOperationQueue mainQueue] withHandler:^
         
         
         (CMDeviceMotion *deviceMotion, NSError *error) {
             CMRotationMatrix r = coreMotionData.deviceMotion.attitude.rotationMatrix;
             GLKMatrix4 baseModelViewMatrix = GLKMatrix4Make(r.m11, r.m21, r.m31, 0.0f, r.m12, r.m22, r.m32, 0.0f, r.m13, r.m23, r.m33, 0.0f, 0.0f, 0.0f, 0.0f, 1.0f);
             
             _coreMotionMatrix = baseModelViewMatrix;
             NSString *transmitMatrix = [NSString stringWithFormat:@"%f,%f,%f,%f,%f,%f,%f,%f,%f", r.m11, r.m21, r.m31, r.m12, r.m22, r.m32, r.m13, r.m23, r.m33 ];
             
             self.peripheralController.rotationMatrixData = [transmitMatrix dataUsingEncoding:NSUTF8StringEncoding];
             [self.peripheralController updateMatrixData];

         }];
    }
    
    
    GLKView *view = (GLKView *)self.view;
    view.context = _context;
    view.drawableMultisample = GLKViewDrawableMultisample4X;
    
    [self setupGL];
}


- (void) viewDidAppear:(BOOL)animated
{
 

    [super viewDidAppear:animated];
    NSLog( @"View did appear");
    
    [self.peripheralController viewDidAppear];
}




- (void) viewWillDisappear:(BOOL)animated
{
    
    [self.peripheralController viewWillDisappear];
    
    [super viewWillDisappear:animated];    
}


- (void)viewDidUnload
{
    [super viewDidUnload];
    
    [self tearDownGL];
    
    if ([EAGLContext currentContext] == _context) {
        [EAGLContext setCurrentContext:nil];
    }
    _context = nil;
}

- (void)tearDownGL {
    
    [EAGLContext setCurrentContext:_context];
    
    glDeleteBuffers(1, &_vertexBuffer);
    glDeleteBuffers(1, &_indexBuffer);
    
    _effect = nil;
    _skyboxEffect = nil;
    _reflectionEffect = nil;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}





@end
