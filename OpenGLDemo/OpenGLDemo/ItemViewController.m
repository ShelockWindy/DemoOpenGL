//
//  ItemViewController.m
//  OpenGLDemo
//
//  Created by zj-db0352 on 15/7/29.
//  Copyright (c) 2015年 zj-db0352. All rights reserved.
//

#import "ItemViewController.h"
#import <QuartzCore/QuartzCore.h>
#import <OpenGLES/ES2/gl.h>
#import <OpenGLES/ES2/glext.h>
#import <GLKit/GLKit.h>
#import <OpenGLES/EAGL.h>
#import <AVFoundation/AVFoundation.h>

#import "ShaderOperations.h"
#import "TouchDrawViewViaCoreGraphics.h"
#import "TouchDrawViewViaOpenGLES.h"

typedef NS_ENUM(NSInteger, enumDemoOpenGL){
    demoClearColor = 0,
    demoShader,
    demoTriangleViaShader,
    demoDrawImageViaCoreGraphics,
    demoDrawImageViaOpenGLES,
    demoPaintViaCoreGraphics,
    demoPaintViaOpenGLES,
    demoCoreImageFilter,
    demoCoreImageOpenGLESFilter,
    demo3DTransform,
    demoDisplayImageViaOpenGLES,
};

typedef NS_ENUM(NSInteger, enumPaintColor) {
    redColor = 0,
    greenColor,
    blueColor,
    yellowColor,
    purpleColor,
};

@interface ItemViewController () <UIImagePickerControllerDelegate, TouchDrawViewViaOpenGLESDelegate>

@property (nonatomic) NSArray *demosOpenGL;

@property (nonatomic) CAEAGLLayer *eaglLayer;
@property (nonatomic) EAGLContext *eaglContext; // OpenGL context,管理使用opengl es进行绘制的状态,命令及资源
@property (nonatomic) GLuint frameBuffer; // 帧缓冲区
@property (nonatomic) GLuint colorRenderBuffer; // 渲染缓冲区

@property (nonatomic) GLuint positionSlot; // ???
@property (nonatomic) GLuint colorSlot; // ???
@property (nonatomic) GLint modelViewSlot;
@property (nonatomic) GLint projectionSlot;

// filters
@property (nonatomic) UILabel *lbOriginalImage;
@property (nonatomic) UILabel *lbProcessedImage;
@property (nonatomic) UIImage *originImage;
@property (nonatomic) UIImageView *originImageView;

// GLKit framework provides a view that draws OpenGL es content and manages its own frame buffer object,
// and a view controller that supports animating OpenGL es content.
// GLKView manages OpenGL es infrastructure to provide a place for your drawing code.
// GLKViewController provides a rendering loop for smooth animation of OpenGL es content in a GLKit view.
@property (nonatomic) GLKView *glkView;
@property (nonatomic) CIFilter *ciFilter;
@property (nonatomic) CIContext *ciContext;
@property (nonatomic) CIImage *ciImage;

// Paint Color
@property (nonatomic) NSInteger paintColor;

@end

@implementation ItemViewController

#pragma mark - viewController lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.

    self.demosOpenGL = @[@"Clear Color", @"Shader", @"Draw Triangle via Shader", @"Draw Image via Core Graphics", @"Draw Image via OpenGL ES", @"Paint via Core Graphics", @"Paint via OpenGL ES", @"Core Image Filter", @"Core Image and OpenGS ES Filter", @"3D Transform", @"Display Image via OpenGL ES"];
    
    [self setupOpenGLContext];
    [self setupCAEAGLLayer];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.navigationItem.title = self.item;
    [self demoViaOpenGL];
}

#pragma mark - setupOpenGLContext

- (void)setupOpenGLContext {
    //setup context, 渲染上下文，管理所有绘制的状态，命令及资源信息。
    _eaglContext = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2]; //opengl es 2.0
    [EAGLContext setCurrentContext:_eaglContext]; //设置为当前上下文。
}

#pragma mark - setupCAEAGLLayer

- (void)setupCAEAGLLayer {
    //setup layer, 必须要是CAEAGLLayer才行，
    //如果在viewController中，使用[self.view.layer addSublayer:eaglLayer];
    //如果在view中，可以直接重写UIView的layerClass类方法即可return [CAEAGLLayer class]。
    _eaglLayer = [CAEAGLLayer layer];//(CAEAGLLayer *)self.view.layer;
    _eaglLayer.frame = self.view.frame;
    _eaglLayer.opaque = YES; //CALayer默认是透明的
    //描绘属性：不维持渲染内容，颜色格式
    _eaglLayer.drawableProperties = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:NO],kEAGLDrawablePropertyRetainedBacking,kEAGLColorFormatRGBA8,kEAGLDrawablePropertyColorFormat, nil];
    [self.view.layer addSublayer:_eaglLayer];
}

#pragma mark - setupOpenGLBuffers

- (void)setupOpenGLBuffers {
    //先要renderbuffer，然后framebuffer，顺序不能互换。
    //setup renderbuffer
    glGenRenderbuffers(1, &_colorRenderBuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, _colorRenderBuffer);
    //为color renderbuffer 分配存储空间
    [_eaglContext renderbufferStorage:GL_RENDERBUFFER fromDrawable:_eaglLayer];

    glGenFramebuffers(1, &_frameBuffer);
    //设置为当前framebuffer
    glBindFramebuffer(GL_FRAMEBUFFER, _frameBuffer);
    // 将 _colorRenderBuffer 装配到 GL_COLOR_ATTACHMENT0 这个装配点上
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, _colorRenderBuffer);
}

#pragma mark - tearDownOpenGLBuffers

- (void)tearDownOpenGLBuffers {
    //destory render and frame buffer
    if (_frameBuffer) {
        glDeleteFramebuffers(1, &_frameBuffer);
        _frameBuffer = 0;
    }
    if (_colorRenderBuffer) {
        glDeleteRenderbuffers(1, &_colorRenderBuffer);
        _colorRenderBuffer = 0;
    }
}

#pragma mark - demoViaOpenGL

- (void)demoViaOpenGL {
    //self.demosOpenGL = @[@"Clear Color", @"Shader", @"Draw Triangle via Shader", @"Draw Image via Core Graphics", @"Draw Image via OpenGL ES", @"Paint via Core Graphics", @"Paint via OpenGL ES", @"Core Image Filter", @"Core Image and OpenGS ES Filter", @"3D Transform", @"Display Image via OpenGL ES"];
    [self tearDownOpenGLBuffers];
    [self setupOpenGLBuffers];
    glClearColor(1.0, 1.0, 1.0, 1.0);
    glClear(GL_COLOR_BUFFER_BIT);
    glLineWidth(10.0);
    switch ([self.demosOpenGL indexOfObject:self.item]) {
        case demoClearColor:
            [self setClearColor];
            break;
        case demoShader:
            [self drawShader];
            break;
        case demoTriangleViaShader:
            [self drawTriangleViaShader];
            break;
        case demoDrawImageViaCoreGraphics:
            [self drawImageViaCoreGraphics];
            break;
        case demoDrawImageViaOpenGLES:
            [self drawImageViaOpenGLES];
            break;
        case demoPaintViaCoreGraphics:
            [self paintViaCoreGraphics];
            break;
        case demoPaintViaOpenGLES:
            [self paintViaOpenGLES];
            break;
        case demoCoreImageFilter:
            [self filterViaCoreImage];
            break;
        case demoCoreImageOpenGLESFilter:
            [self filterViaCoreImageAndOpenGLES];
            break;
        case demo3DTransform:
            [self demo3DTransform];
            break;
        case demoDisplayImageViaOpenGLES:
            [self displayImageViaOpenGLES];
            break;
        default:
            break;
    }
    [_eaglContext presentRenderbuffer:GL_RENDERBUFFER];
}

#pragma mark - draw somethings

- (void)setClearColor {
    glClearColor(0, 0, 1.0, 1.0);
    glClear(GL_COLOR_BUFFER_BIT);
}

- (void)drawShader {
    // 先要编译vertex和fragment两个shader
    NSString *shaderVertex = @"SimpleVertex";
    NSString *shaderFragment = @"SimpleFragment";
    [self compileShaders:shaderVertex shaderFragment:shaderFragment];

    //设置UIView用于渲染的部分, 这里是整个屏幕
    glViewport(0, 0, self.view.frame.size.width, self.view.frame.size.height);

    // 定义一个Vertex结构
    typedef struct {
        float Position[3];
        float Color[4];
    } Vertex;
    
    // 跟踪每个顶点信息
    // 如何将vertices数组与shader/opengl关联起来的? 使用glGenBuffers, glBindBuffer, glBufferData进行关联
    const Vertex Vertices[] = {
        {{-1,-1,0}, {0,0,0,1}},// 左下
        {{1,-1,0}, {1,0,0,1}}, // 右下
        {{-1,1,0}, {0,0,1,1}}, // 左上
        {{1,1,0}, {0,1,0,1}},  // 右上
    };
    
    // 跟踪组成每个三角形的索引信息, 与Vertices对应起来绘制出矩形
    const GLubyte Indices[] = {
        0,1,2, // 三角形0
        1,2,3  // 三角形1
    };
    
    //GL_ARRAY_BUFFER用于顶点数组
    GLuint vertexBuffer;
    // 创建一个VBO
    glGenBuffers(1, &vertexBuffer);
    // 绑定一个缓冲区对象, 也可视为切换到该缓冲区
    glBindBuffer(GL_ARRAY_BUFFER, vertexBuffer);
    // 把数据传到OpenGL
    glBufferData(GL_ARRAY_BUFFER, sizeof(Vertices), Vertices, GL_STATIC_DRAW);
    
    // GL_ELEMENT_ARRAY_BUFFER用于顶点数组对应的indices
    GLuint indexBuffer;
    // 步骤同vertices, 只是参数不同.
    glGenBuffers(1, &indexBuffer);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, indexBuffer);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(Indices), Indices, GL_STATIC_DRAW);

    //为vertex shader的两个输入参数设置合适的值
    glVertexAttribPointer(_positionSlot, 3, GL_FLOAT, GL_FALSE, sizeof(Vertex), 0);
    //Vertex结构体, 偏移3个float的位置之后, 即是color的值.
    glVertexAttribPointer(_colorSlot, 4, GL_FLOAT, GL_FALSE, sizeof(Vertex), (GLvoid *)(sizeof(float)*3));

    //在每个vertex上调用vertex shader, 每个像素调用fragment shader, 最终画出图形
    //相比glDrawArrays, 使用顶点索引数组结合glDrawElements来渲染, 可以减少存储重复顶点的内存消耗
    glDrawElements(GL_TRIANGLES, sizeof(Indices)/sizeof(Indices[0]), GL_UNSIGNED_BYTE, 0);
//    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4); // 使用glDrawArrays也可绘制
}

- (void)drawTriangleViaShader {
    // 先要编译vertex和fragment两个shader
    NSString *shaderVertex = @"VertexTriangle";
    NSString *shaderFragment = @"FragmentTriangle";
    [self compileShaders:shaderVertex shaderFragment:shaderFragment];

    //设置UIView用于渲染的部分, 这里是整个屏幕
    glViewport(0, 0, self.view.frame.size.width, self.view.frame.size.height);

    // 创建OpenGL视图, 使用GLKView来取代glViewPort的作用.
//    _glkView = [[GLKView alloc] initWithFrame:CGRectMake(10, 70, self.view.frame.size.width - 20, self.view.frame.size.height - 70) context:_eaglContext];
//    [_glkView bindDrawable];
//    [self.view addSubview:_glkView];
//    [_glkView display];

    GLfloat vertices[] = {
        0.0f,  -0.5f, 0.0f,
        -0.8f, -0.8f, 0.0f,
        0.8f,  -0.8f, 0.0f };

    //如何将vertices数组与shader/opengl关联起来的? 如下两种方法:
    //1. glVertexAttribPointer(_positionSlot, 3, GL_FLOAT, GL_FALSE, 0, vertices);
    //2. 使用glGenBuffers, glBindBuffer, glBufferData来进行设置,
    //此时 glVertexAttribPointer(_positionSlot, 3, GL_FLOAT, GL_FALSE, 0, 0);
    //即: 两种方法不能同时使用! 因为glVertexAttribPointer的最后一个参数, 指定第一个组件在数组的第一个顶点属性中的偏移量, 与GL_ARRAY_BUFFER绑定存储于缓冲区中
//    GLuint vertexBuffer;
//    glGenBuffers(1, &vertexBuffer);
//    glBindBuffer(GL_ARRAY_BUFFER, vertexBuffer);
//    glBufferData(GL_ARRAY_BUFFER, sizeof(vertices), vertices, GL_STATIC_DRAW);

    // Load the vertex data
    // 为vertex shader的唯一输入参数Position设置合适的值
    glVertexAttribPointer(_positionSlot, 3, GL_FLOAT, GL_FALSE, 0, vertices);
    glEnableVertexAttribArray(_positionSlot);
    
    // Draw triangle
    glDrawArrays(GL_TRIANGLES, 0, 3);

    [_eaglContext presentRenderbuffer:GL_RENDERBUFFER];
}

- (void)drawImageViaCoreGraphics {
    _lbOriginalImage = [[UILabel alloc] initWithFrame:CGRectMake(10, 70, self.view.frame.size.width - 20, 30)];
    _lbOriginalImage.text = @"Draw Image via CoreGraphics and QuartzCore...";
    _lbOriginalImage.textAlignment = NSTextAlignmentCenter;
    [self.view addSubview:_lbOriginalImage];

    // 使用Core Graphics绘制图片
    TouchDrawViewViaCoreGraphics *drawView = [[TouchDrawViewViaCoreGraphics alloc] initWithFrame:CGRectMake(10, 100, self.view.frame.size.width - 20, 200)];
    drawView.backgroundColor = [UIColor whiteColor];
    [self.view addSubview:drawView];
}

- (void)drawImageViaOpenGLES {
    [self displayOriginImage]; // 会被影响到, 成倒立图片.
    _lbOriginalImage.text = @"Click image to choose from local photos...";
    UITapGestureRecognizer *tapGestureRecognizer = [[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(chooseOriginImageFromPhotos)];
    tapGestureRecognizer.numberOfTapsRequired = 1;
    tapGestureRecognizer.numberOfTouchesRequired = 1;
    tapGestureRecognizer.delegate = self;
    [_originImageView addGestureRecognizer:tapGestureRecognizer];
    [_originImageView setUserInteractionEnabled:YES];
    
    [self didDrawImageViaOpenGLES:[UIImage imageNamed:@"testImage"] inFrame:CGRectMake(10, 340, self.view.frame.size.width - 20, 200)];
}

- (void)didDrawImageViaOpenGLES:(UIImage *)image inFrame:(CGRect)rect {
    // 创建OpenGL视图
    _glkView = [[GLKView alloc] initWithFrame:rect context:_eaglContext];
    [_glkView bindDrawable];
    [self.view addSubview:_glkView];
    [_glkView display];
    
    // 因OpenGL只能绘制三角形, 则该verteices2数组与glDrawArrays的组合要认真仔细.
    // 如glDrawArrays(GL_TRIANGLE_STRIP, 0, 4)是两个三角形:(左下,右下,右上)与(右下,右上,左上).
    // 而glDrawArrays(GL_TRIANGLE_STRIP, 1, 3)是一个三角形:(右下,右上,左上)
    // 若将vertices中的右上与左上互换, 则glDrawArrays(GL_TRIANGLE_STRIP, 0, 4)刚好绘制出一片白板(两个三角形拼接).
    GLfloat vertices[] = {
        -1, -1,//左下
        1, -1,//右下
        -1, 1,//左上
        1, 1,//右上
    };
    // 启用vertex数组
    glEnableVertexAttribArray(GLKVertexAttribPosition);
    // glVertexAttribPointer:加载vertex数据
    // 参数1:传递的顶点位置数据GLKVertexAttribPosition, 或顶点颜色数据GLKVertexAttribColor
    // 参数2:数据大小(2维为2, 3维为3)
    // 参数3:顶点的数据类型
    // 参数4:指定当被访问时, 固定点数据值是否应该被归一化或直接转换为固定点值.
    // 参数5:指定连续顶点属性之间的偏移量, 用于描述每个vertex数据大小
    // 参数6:指定第一个组件在数组的第一个顶点属性中的偏移量, 与GL_ARRAY_BUFFER绑定存储于缓冲区中
    glVertexAttribPointer(GLKVertexAttribPosition, 2, GL_FLOAT, GL_FALSE, 0, vertices);
    
    static GLfloat colors[] = {
        1,1,1,1,
        1,1,1,1,
        1,1,1,1,
        1,1,1,1
    };
    // 启用颜色
    glEnableVertexAttribArray(GLKVertexAttribColor);
    glVertexAttribPointer(GLKVertexAttribColor, 4, GL_FLOAT, GL_FALSE, 0, colors);

    static GLfloat texCoords[] = {
        0, 0,//左下
        1, 0,//右下
        0, 1,//左上
        1, 1,//右上
    };
    // 启用vertex贴图坐标
    glEnableVertexAttribArray(GLKVertexAttribTexCoord0);
    glVertexAttribPointer(GLKVertexAttribTexCoord0, 2, GL_FLOAT, GL_FALSE, 0, texCoords);
    // 因为读取图片信息的时候默认是从图片左上角读取的, 而OpenGL绘制却是从左下角开始的.所以我们要从左下角开始读取图片数据.
    NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:@(YES), GLKTextureLoaderOriginBottomLeft, nil];
    GLKTextureInfo *textureInfo = [GLKTextureLoader textureWithCGImage:image.CGImage options:options error:nil];

    GLKBaseEffect *baseEffect = [[GLKBaseEffect alloc] init];
    // 创建一个二维的投影矩阵, 即定义一个视野区域(镜头看到的东西)
    // GLKMatrix4MakeOrtho(float left, float right, float bottom, float top, float nearZ, float farZ)
    baseEffect.transform.projectionMatrix = GLKMatrix4MakeOrtho(-1, 1, -1, 1, -1, 1);
    baseEffect.texture2d0.name = textureInfo.name;
    [baseEffect prepareToDraw];
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);

    glDisableVertexAttribArray(GLKVertexAttribPosition);
    glDisableVertexAttribArray(GLKVertexAttribColor);
    glDisableVertexAttribArray(GLKVertexAttribTexCoord0);

    [_eaglContext presentRenderbuffer:GL_RENDERBUFFER];
}

#pragma mark - paint

- (void)paintViaCoreGraphics {
    _lbOriginalImage = [[UILabel alloc] initWithFrame:CGRectMake(10, 70, self.view.frame.size.width - 20, 30)];
    _lbOriginalImage.text = @"Paint via CoreGraphics and QuartzCore...";
    _lbOriginalImage.textAlignment = NSTextAlignmentCenter;
    [self.view addSubview:_lbOriginalImage];
    
    // 使用Core Graphics绘制图片, 添加画笔
    TouchDrawViewViaCoreGraphics *drawView = [[TouchDrawViewViaCoreGraphics alloc] initWithFrame:CGRectMake(10, 100, self.view.frame.size.width - 20, 200)];
    drawView.backgroundColor = [UIColor whiteColor];
    [self.view addSubview:drawView];

    _lbProcessedImage = [[UILabel alloc] initWithFrame:CGRectMake(10, 310, self.view.frame.size.width - 20, 30)];
    _lbProcessedImage.text = @"Click to draw via OpenGL ES...";
    _lbProcessedImage.textAlignment = NSTextAlignmentCenter;
    [self.view addSubview:_lbProcessedImage];

    UITapGestureRecognizer *tapGestureRecognizer = [[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(drawTriangleViaShader)];
    tapGestureRecognizer.numberOfTapsRequired = 1;
    tapGestureRecognizer.numberOfTouchesRequired = 1;
    tapGestureRecognizer.delegate = self;
    [_lbProcessedImage addGestureRecognizer:tapGestureRecognizer];
    [_lbProcessedImage setUserInteractionEnabled:YES];
}

- (void)paintViaOpenGLES {
    // 使用OpenGL ES绘制图片, 添加画笔
    TouchDrawViewViaOpenGLES *touchDrawViewViaOpenGLES = [[TouchDrawViewViaOpenGLES alloc] initWithFrame:self.view.frame];
    touchDrawViewViaOpenGLES.backgroundColor = [UIColor clearColor];
    touchDrawViewViaOpenGLES.delegate = self;
    [touchDrawViewViaOpenGLES addImageViaOpenGLES:[UIImage imageNamed:@"testImage"]];
    [self.view addSubview:touchDrawViewViaOpenGLES];

    UISegmentedControl *paintColorSegCtl = [[UISegmentedControl alloc] initWithItems:
                                            [NSArray arrayWithObjects:
                                             [[UIImage imageNamed:@"Red"] imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal],
                                             [[UIImage imageNamed:@"Green"] imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal],
                                             [[UIImage imageNamed:@"Blue"] imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal],
                                             [[UIImage imageNamed:@"Yellow"] imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal],
                                             [[UIImage imageNamed:@"Purple"] imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal],
                                             nil]];
    paintColorSegCtl.frame = CGRectMake(10, 70, self.view.frame.size.width - 20, 30);
    [paintColorSegCtl addTarget:self action:@selector(changePaintColor:) forControlEvents:UIControlEventValueChanged];
    paintColorSegCtl.tintColor = [UIColor darkGrayColor];
    paintColorSegCtl.selectedSegmentIndex = 0;
    [self.view addSubview:paintColorSegCtl];
}

- (void)changePaintColor:(UISegmentedControl *)paintColorSegCtl {
    _paintColor = paintColorSegCtl.selectedSegmentIndex;
}

#pragma mark - shader related

- (void)compileShaders:(NSString *)shaderVertex shaderFragment:(NSString *)shaderFragment {
    // 1 vertex和fragment两个shader都要编译
    GLuint vertexShader = [ShaderOperations compileShader:shaderVertex withType:GL_VERTEX_SHADER];
    GLuint fragmentShader = [ShaderOperations compileShader:shaderFragment withType:GL_FRAGMENT_SHADER];
    
    // 2 连接vertex和fragment shader成一个完整的program
    GLuint programHandle = glCreateProgram();
    glAttachShader(programHandle, vertexShader);
    glAttachShader(programHandle, fragmentShader);

    // link program
    glLinkProgram(programHandle);
    
    // 3 check link status
    GLint linkSuccess;
    glGetProgramiv(programHandle, GL_LINK_STATUS, &linkSuccess);
    if (linkSuccess == GL_FALSE) {
        GLchar messages[256];
        glGetProgramInfoLog(programHandle, sizeof(messages), 0, &messages[0]);
        NSString *messageString = [NSString stringWithUTF8String:messages];
        NSLog(@"%@", messageString);
        exit(1);
    }
    
    // 4 让OpenGL执行program
    glUseProgram(programHandle);

    // 5 获取指向vertex shader传入变量的指针, 然后就通过该指针来使用
    // 即将_positionSlot 与 shader中的Position参数绑定起来
    // 即将_colorSlot 与 shader中的SourceColor参数绑定起来
    _positionSlot = glGetAttribLocation(programHandle, "Position");
    // SourceColor采用的是uniform类型
    // 所以不能使用_colorSlot = glGetAttribLocation(programHandle, "SourceColor");
    _colorSlot = glGetUniformLocation(programHandle, "SourceColor");
    _modelViewSlot = glGetUniformLocation(programHandle, "ModelView");
    _projectionSlot = glGetUniformLocation(programHandle, "Projection");
    glEnableVertexAttribArray(_positionSlot); // 启用这些数据
    glEnableVertexAttribArray(_colorSlot);
    glEnableVertexAttribArray(_modelViewSlot);
    glEnableVertexAttribArray(_projectionSlot);
}

#pragma mark - display origin image

- (void)displayOriginImage {
    _lbOriginalImage = [[UILabel alloc] initWithFrame:CGRectMake(10, 70, self.view.frame.size.width - 20, 30)];
    _lbOriginalImage.text = @"Original image...";
    _lbOriginalImage.textAlignment = NSTextAlignmentCenter;
    [self.view addSubview:_lbOriginalImage];

    _originImage = [UIImage imageNamed:@"testImage"];
    _originImageView = [[UIImageView alloc] initWithFrame:CGRectMake(10, 100, self.view.frame.size.width - 20, 200)];
    _originImageView.image = _originImage;
    [self.view addSubview:_originImageView];
    
    _lbProcessedImage = [[UILabel alloc] initWithFrame:CGRectMake(10, 310, self.view.frame.size.width - 20, 30)];
    _lbProcessedImage.text = @"Processed image...";
    _lbProcessedImage.textAlignment = NSTextAlignmentCenter;
    [self.view addSubview:_lbProcessedImage];
}

- (void)chooseOriginImageFromPhotos {
    UIImagePickerController *imagePicker = [[UIImagePickerController alloc] init];
    imagePicker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    imagePicker.allowsEditing = YES;
    imagePicker.delegate = self;
    [self presentViewController:imagePicker animated:YES completion:nil];
}

#pragma mark - UIImagePickerControllerDelegate

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info {
    UIImage *originalImage = [info valueForKey:UIImagePickerControllerOriginalImage];
    UIImage *editedImage = [info valueForKey:UIImagePickerControllerEditedImage];
    UIImage *savedImage = editedImage ? editedImage : originalImage;
    [picker dismissViewControllerAnimated:YES completion:^{
        _originImageView.image = savedImage;
        if ([self.demosOpenGL indexOfObject:self.item] == demoDrawImageViaOpenGLES) {
            [self didDrawImageViaOpenGLES:savedImage inFrame:CGRectMake(10, 340, self.view.frame.size.width - 20, 200)];
        }
    }];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [picker dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - filters

- (void)filterViaCoreImage {
    [self displayOriginImage];

    // 0. 导入CIImage图片
    CIImage *ciInputImage = [[CIImage alloc] initWithImage:_originImage];
    // 1. 创建CIFilter
    CIFilter *filterPixellate = [CIFilter filterWithName:@"CIPixellate"];
    [filterPixellate setValue:ciInputImage forKey:kCIInputImageKey];
    [filterPixellate setDefaults];
    CIImage *ciOutImagePixellate = [filterPixellate valueForKey:kCIOutputImageKey];
    NSLog(@"filterPixellate : %@", filterPixellate.attributes);
    
    // 2. 用CIContext将滤镜中的图片渲染出来
    CIContext *context = [CIContext contextWithOptions:nil];
    CGImageRef cgImage = [context createCGImage:ciOutImagePixellate fromRect:[ciOutImagePixellate extent]];
    
    // 3. 导出图片
    UIImage *filteredImage = [UIImage imageWithCGImage:cgImage];
    CGImageRelease(cgImage);
    
    // 4. 显示图片
    UIImageView *filteredImageView = [[UIImageView alloc] initWithFrame:CGRectMake(10, 340, self.view.frame.size.width - 20, 200)];
    filteredImageView.image = filteredImage;
    [self.view addSubview:filteredImageView];
}

- (void)filterViaCoreImageAndOpenGLES {
    [self displayOriginImage];

    // 创建出渲染的buffer
    _glkView = [[GLKView alloc] initWithFrame:CGRectMake(10, 340, self.view.frame.size.width - 20, 200) context:_eaglContext];
    [_glkView bindDrawable];
    [self.view addSubview:_glkView];
    
    // 创建CoreImage使用的context
    _ciContext = [CIContext contextWithEAGLContext:_eaglContext options:@{kCIContextWorkingColorSpace:[NSNull null]}];
    
    // CoreImage的相关设置
    _ciImage = [[CIImage alloc] initWithImage:_originImage];
    _ciFilter = [CIFilter filterWithName:@"CISepiaTone"];
    [_ciFilter setValue:_ciImage forKey:kCIInputImageKey];
    [_ciFilter setValue:@(0) forKey:kCIInputIntensityKey];

    // 开始渲染
    [_ciContext drawImage:[_ciFilter outputImage] inRect:CGRectMake(0, 0, _glkView.drawableWidth, _glkView.drawableHeight) fromRect:[_ciImage extent]];
    [_glkView display];
    
    _lbProcessedImage.text = @"Slide to change the filter effect...";
    // 使用Slider进行动态渲染
    UISlider *slider = [[UISlider alloc] initWithFrame:CGRectMake(10, self.view.frame.size.height - 50, self.view.frame.size.width - 20, 64)];
    slider.minimumValue = 0.0f;
    slider.maximumValue = 5.0f;
    [slider addTarget:self action:@selector(sliderValueChanged:) forControlEvents:UIControlEventValueChanged];
    [self.view addSubview:slider];
}

- (void)sliderValueChanged:(UISlider *)sender {
    [_ciFilter setValue:_ciImage forKey:kCIInputImageKey];
    [_ciFilter setValue:@(sender.value) forKey:kCIInputIntensityKey];

    //开始渲染
    [_ciContext drawImage:[_ciFilter outputImage] inRect:CGRectMake(0, 0, _glkView.drawableWidth, _glkView.drawableHeight) fromRect:[_ciImage extent]];
    [_glkView display];
}

#pragma mark - 3D Transform

- (void)demo3DTransform {
    // 先要编译vertex和fragment两个shader
    NSString *shaderVertex = @"Vertex3DTransform";
    NSString *shaderFragment = @"Fragment3DTransform";
    [self compileShaders:shaderVertex shaderFragment:shaderFragment];

    //设置UIView用于渲染的部分, 这里是整个屏幕
    glViewport(0, 0, self.view.frame.size.width, self.view.frame.size.height);

    GLfloat vertices[] = {
        0.5f, 0.5f, 0.0f,
        0.5f, -0.5f, 0.0f,
        -0.5f, -0.5f, 0.0f,
        -0.5f, 0.5f, 0.0f,
        0.0f, 0.0f, -0.707f,
    };
    GLubyte indices[] = {
        0, 1, 1, 2, 2, 3, 3, 0,
        4, 0, 4, 1, 4, 2, 4, 3
    };

    glVertexAttribPointer(_positionSlot, 3, GL_FLOAT, GL_FALSE, 0, vertices);
    glVertexAttribPointer(_modelViewSlot, 3, GL_FLOAT, GL_FALSE, 0, vertices);
    glVertexAttribPointer(_projectionSlot, 3, GL_FLOAT, GL_FALSE, 0, vertices);
    glEnableVertexAttribArray(_positionSlot);
    glEnableVertexAttribArray(_modelViewSlot);
    glEnableVertexAttribArray(_projectionSlot);
    
    // draw lines
    glDrawElements(GL_LINES, sizeof(indices)/sizeof(GLubyte), GL_UNSIGNED_BYTE, indices);
}

- (void)displayImageViaOpenGLES {
    [self displayOriginImage];
    _lbOriginalImage.text = @"Click image to choose from local photos...";
    UITapGestureRecognizer *tapGestureRecognizer = [[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(chooseOriginImageFromPhotos)];
    tapGestureRecognizer.numberOfTapsRequired = 1;
    tapGestureRecognizer.numberOfTouchesRequired = 1;
    tapGestureRecognizer.delegate = self;
    [_originImageView addGestureRecognizer:tapGestureRecognizer];
    [_originImageView setUserInteractionEnabled:YES];

    // 创建出渲染的buffer
    _glkView = [[GLKView alloc] initWithFrame:CGRectMake(10, 340, self.view.frame.size.width - 20, 200) context:_eaglContext];
    [_glkView bindDrawable];
    [self.view addSubview:_glkView];
    [_glkView display];
}

#pragma mark - TouchDrawViewViaOpenGLESDelegate

- (void)drawCGPointViaOpenGLES:(CGPoint)point inFrame:(CGRect)rect {
    NSLog(@"drawCGPointViaOpenGLES : %.1f-%.1f", point.x, point.y);

    // 先要编译vertex和fragment两个shader
    NSString *shaderVertex = @"VertexPaint";
    NSString *shaderFragment = @"FragmentPaint";
    [self compileShaders:shaderVertex shaderFragment:shaderFragment];

    //设置UIView用于渲染的部分, 这里是整个rect
    glViewport(0, 0, rect.size.width, rect.size.height);

    CGFloat lineWidth = 5.0;
    GLfloat vertices[] = {
        -1 + 2 * (point.x - lineWidth) / rect.size.width, 1 - 2 * (point.y + lineWidth) / rect.size.height, 0.0f, // 左下
        -1 + 2 * (point.x + lineWidth) / rect.size.width, 1 - 2 * (point.y + lineWidth) / rect.size.height, 0.0f, // 右下
        -1 + 2 * (point.x - lineWidth) / rect.size.width, 1 - 2 * (point.y - lineWidth) / rect.size.height, 0.0f, // 左上
        -1 + 2 * (point.x + lineWidth) / rect.size.width, 1 - 2 * (point.y - lineWidth) / rect.size.height, 0.0f }; //右上

    // Load the vertex data
    glVertexAttribPointer(_positionSlot, 3, GL_FLOAT, GL_FALSE, 0, vertices);
    glEnableVertexAttribArray(_positionSlot);
    
    // _colorSlot对应SourceColor参数, uniform类型, 使用glUniform4f来传递参数至shader.
    switch (_paintColor) {
        case redColor:
            glUniform4f(_colorSlot, 1.0f, 0.0f, 0.0f, 1.0f);
            break;
        case greenColor:
            glUniform4f(_colorSlot, 0.0f, 1.0f, 0.0f, 1.0f);
            break;
        case blueColor:
            glUniform4f(_colorSlot, 0.0f, 0.0f, 1.0f, 1.0f);
            break;
        case yellowColor:
            glUniform4f(_colorSlot, 1.0f, 1.0f, 0.0f, 1.0f);
            break;
        case purpleColor:
            glUniform4f(_colorSlot, 1.0f, 0.0f, 1.0f, 1.0f);
            break;
        default:
            glUniform4f(_colorSlot, 0.0f, 0.0f, 0.0f, 1.0f);
            break;
    }

    // Draw triangle
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    [_eaglContext presentRenderbuffer:GL_RENDERBUFFER];
}

- (void)drawCGPointsViaOpenGLES:(NSArray *)points inFrame:(CGRect)rect {
    // 先要编译vertex和fragment两个shader
    NSString *shaderVertex = @"VertexPaint";
    NSString *shaderFragment = @"FragmentPaint";
    [self compileShaders:shaderVertex shaderFragment:shaderFragment];
    
    //设置viewport,即OpenGL ES要渲染的部分
    glViewport(0, 0, rect.size.width, rect.size.height);
    
    // _colorSlot对应SourceColor参数, uniform类型, 使用glUniform4f来传递参数至shader.
    switch (_paintColor) {
        case redColor:
            glUniform4f(_colorSlot, 1.0f, 0.0f, 0.0f, 1.0f);
            break;
        case greenColor:
            glUniform4f(_colorSlot, 0.0f, 1.0f, 0.0f, 1.0f);
            break;
        case blueColor:
            glUniform4f(_colorSlot, 0.0f, 0.0f, 1.0f, 1.0f);
            break;
        case yellowColor:
            glUniform4f(_colorSlot, 1.0f, 1.0f, 0.0f, 1.0f);
            break;
        case purpleColor:
            glUniform4f(_colorSlot, 1.0f, 0.0f, 1.0f, 1.0f);
            break;
        default:
            glUniform4f(_colorSlot, 0.0f, 0.0f, 0.0f, 1.0f);
            break;
    }
    
    for (id rawPoint in points) {
        CGPoint point = [rawPoint CGPointValue];
        NSLog(@"drawCGPointsViaOpenGLES : %.1f-%.1f", point.x, point.y);
        CGFloat lineWidth = 5.0;
        GLfloat vertices[] = {
            -1 + 2 * (point.x - lineWidth) / rect.size.width, 1 - 2 * (point.y + lineWidth) / rect.size.height, 0.0f, // 左下
            -1 + 2 * (point.x + lineWidth) / rect.size.width, 1 - 2 * (point.y + lineWidth) / rect.size.height, 0.0f, // 右下
            -1 + 2 * (point.x - lineWidth) / rect.size.width, 1 - 2 * (point.y - lineWidth) / rect.size.height, 0.0f, // 左上
            -1 + 2 * (point.x + lineWidth) / rect.size.width, 1 - 2 * (point.y - lineWidth) / rect.size.height, 0.0f }; //右上

        const GLubyte indices[] = {
            0, 1, 2, // 三角形0
            1, 2, 3  // 三角形1
        };

        //之前将_positionSlot与shader中的Position绑定起来, 这里将顶点数据vertices与_positionSlot绑定起来
        glVertexAttribPointer(_positionSlot, 3, GL_FLOAT, GL_FALSE, 0, vertices);
        glEnableVertexAttribArray(_positionSlot);

        // glDrawArrays(GL_TRIANGLE_STRIP, 0, 4); // 从0开始绘制4个点, 即两个三角形(012, 123)

        //通过index来绘制vertex,
        //参数1表示图元类型, 参数2表示索引数据的个数(不一定是要绘制的vertex的个数), 参数3表示索引数据格式(必须是GL_UNSIGNED_BYTE等).
        //参数4表示存放索引的数组(使用VBO:索引数据在VBO中的偏移量;不使用VBO:指向CPU内存中的索引数据数组).
        //相比glDrawArrays, 其优势在于:
        //通过index指定了要绘制的6个的vertex(用index对应),而1,2(index)重复了,所以实际只绘制0,1,2,3(index)对应的四个vertex
        glDrawElements(GL_TRIANGLE_STRIP, sizeof(indices)/sizeof(indices[0]), GL_UNSIGNED_BYTE, indices);
    }
    [_eaglContext presentRenderbuffer:GL_RENDERBUFFER];
}

- (void)addImageViaOpenGLES:(UIImage *)image inFrame:(CGRect)rect {
    [self didDrawImageViaOpenGLES:image inFrame:rect];
}

@end
