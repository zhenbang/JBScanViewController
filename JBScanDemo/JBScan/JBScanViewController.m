//
//  CPQRScanViewController.m
//
//  Created by Jubal on 2016/12/7.
//  Copyright © 2016年 Jubal. All rights reserved.
//

#import "JBScanViewController.h"
#import <AVFoundation/AVFoundation.h>
#import <MobileCoreServices/MobileCoreServices.h>

#define VIEW_SIZE_HEIGHT  self.view.bounds.size.height  //当前View高度
#define VIEW_SIZE_WIDTH   self.view.bounds.size.width   //当前View宽度
#define SCAN_RECT_RATIO   0.7                           //扫码区域与当前View宽的比例
#define SCAN_OFFSET       -40                           //扫描框偏移量(大于0往下，小于0往上)
#define SCAN_FRAME_ANIMATION_DURATION  0.2              //扫描框生成动画时长

@interface JBScanViewController ()<AVCaptureMetadataOutputObjectsDelegate,UINavigationControllerDelegate,UIImagePickerControllerDelegate>{
    AVCaptureSession * session;      //输入输出的中间桥梁
    UIActivityIndicatorView *acView; //loading菊花框
    UILabel *label;                  //loading提示语
}

@property (strong, nonatomic) CAShapeLayer *maskLayer;

@end

@implementation JBScanViewController

#pragma mark - ScanResult
/** 扫描获取字符串触发 */
- (void)scanResultString:(NSString*)result{
    //提示扫描结果(演示)
    [self alertControllerMessage:result];
}

/** 扫描获取对象触发 */
- (void)scanResult:(id)result{
    NSLog(@">>>%@",result);
}

#pragma mark - LifeCycle
- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"扫码";
    self.view.backgroundColor = [UIColor blackColor];
    //相册入口
    UIBarButtonItem *rightButton = [[UIBarButtonItem alloc] initWithTitle:@"🏯" style:UIBarButtonItemStylePlain target:self action:@selector(scanImage)];
    self.navigationItem.rightBarButtonItem = rightButton;
    //初始化UI
    [self setupScanUI];
}

- (void)viewWillAppear:(BOOL)animated{
    [super viewWillAppear:animated];
    //屏蔽自动锁屏
    [UIApplication sharedApplication].idleTimerDisabled=YES;
    if (session) [session startRunning];
}

- (void)viewDidAppear:(BOOL)animated{
    [super viewDidAppear:animated];
    if (!session && [self checkCameraPermissions]) [self initScan];
}

- (void)viewWillDisappear:(BOOL)animated{
    [super viewWillDisappear:animated];
    //打开自动锁屏
    [UIApplication sharedApplication].idleTimerDisabled=YES;
    [session stopRunning];
}

#pragma mark - LoadOperation
/** 设置界面 */
- (void)setupScanUI{
    //扫描框
    UIView *maskView = [[UIView alloc] initWithFrame:self.view.frame];
    maskView.backgroundColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0.55];
    [self.view addSubview:maskView];
    UIBezierPath *maskPath = [UIBezierPath bezierPathWithRect:CGRectMake(0, 0, VIEW_SIZE_WIDTH, VIEW_SIZE_HEIGHT)];
    [maskPath appendPath:[[UIBezierPath bezierPathWithRoundedRect:CGRectMake(VIEW_SIZE_WIDTH/2,VIEW_SIZE_HEIGHT/2+SCAN_OFFSET,0,0) cornerRadius:1] bezierPathByReversingPath]];
    self.maskLayer = [[CAShapeLayer alloc] init];
    self.maskLayer.path = maskPath.CGPath;
    maskView.layer.mask = self.maskLayer;
    
    //启动提示和loading菊花
    acView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
    label = [UILabel new];
    [acView startAnimating];
    [acView setHidesWhenStopped:YES];
    label.text = @"相机启动中...";
    label.textColor = [UIColor whiteColor];
    [label setTextAlignment:NSTextAlignmentCenter];
    [self.view addSubview:acView];
    [self.view addSubview:label];
    acView.frame = CGRectMake((VIEW_SIZE_WIDTH-200)/2,(VIEW_SIZE_HEIGHT-200)/2-50, 200, 200);
    label.frame  = CGRectMake((VIEW_SIZE_WIDTH-200)/2,(VIEW_SIZE_HEIGHT-30)/2, 200, 30);
}

/** 初始化相机扫描(部分UI参数更改在此方法) */
- (void)initScan{
    // Do any additional setup after loading the view, typically from a nib.
    //获取摄像设备
    AVCaptureDevice * device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    //创建输入流
    AVCaptureDeviceInput * input = [AVCaptureDeviceInput deviceInputWithDevice:device error:nil];
    //创建输出流
    AVCaptureMetadataOutput * output = [[AVCaptureMetadataOutput alloc]init];
    //设置代理 在主线程里刷新
    [output setMetadataObjectsDelegate:self queue:dispatch_get_main_queue()];
    //设置扫码范围(Y,X,HEIGHT,WIDTH)
    output.rectOfInterest=CGRectMake(
                                     ((1-(VIEW_SIZE_WIDTH/VIEW_SIZE_HEIGHT*SCAN_RECT_RATIO))/2)+(SCAN_OFFSET/VIEW_SIZE_HEIGHT),
                                     (1-SCAN_RECT_RATIO)/2,
                                     VIEW_SIZE_WIDTH/VIEW_SIZE_HEIGHT*SCAN_RECT_RATIO,
                                     SCAN_RECT_RATIO
                                     );
    //初始化链接对象
    session = [[AVCaptureSession alloc]init];
    //高质量采集率
    [session setSessionPreset:AVCaptureSessionPresetHigh];
    [session addInput:input];
    [session addOutput:output];
    //设置扫码支持的编码格式
    output.metadataObjectTypes=@[AVMetadataObjectTypeQRCode,AVMetadataObjectTypeEAN13Code, AVMetadataObjectTypeEAN8Code, AVMetadataObjectTypeCode128Code];
    
    AVCaptureVideoPreviewLayer * layer = [AVCaptureVideoPreviewLayer layerWithSession:session];
    layer.videoGravity=AVLayerVideoGravityResizeAspectFill;
    layer.frame=self.view.layer.bounds;
    [acView stopAnimating];
    label.hidden = YES;
    //插入相机Layer
    [self.view.layer insertSublayer:layer atIndex:0];
    //开始捕获
    [session startRunning];
    //扫描框动画
    [self loadScanAnimation];
    //扫描框四角动画
    [self.view.layer addSublayer:[self getFourCornerLayerColor:[UIColor greenColor] lineWidth:2 lineLenghRatio:0.05]];
    //扫描线
    [self.view.layer addSublayer:[self getScanLine:[UIColor greenColor] height:2 duration:2.5]];
    
    //提示文字
    UILabel *remindLabel = [[UILabel alloc] initWithFrame:CGRectMake(VIEW_SIZE_WIDTH*0.1, (VIEW_SIZE_HEIGHT-VIEW_SIZE_WIDTH*SCAN_RECT_RATIO)/2+VIEW_SIZE_WIDTH*SCAN_RECT_RATIO+SCAN_OFFSET, VIEW_SIZE_WIDTH*0.8, 30)];
    remindLabel.text = @"将二维码/条形码放入框内，即可自动扫描";
    remindLabel.textColor = [UIColor lightGrayColor];
    remindLabel.font = [UIFont systemFontOfSize:12];
    [remindLabel setTextAlignment:NSTextAlignmentCenter];
    [self.view addSubview:remindLabel];
}


/**
 生成扫描框四个拐角

 @param color 拐角颜色
 @param lineWidth 拐角线宽
 @param ratio 线宽与当前扫描框宽度的比例
 @return 四角Layer
 */
- (CAShapeLayer*)getFourCornerLayerColor:(UIColor*)color lineWidth:(float)lineWidth lineLenghRatio:(float)ratio{
    //四角
    CAShapeLayer *scanBoxLayer = [[CAShapeLayer alloc] init];
    UIBezierPath *fourCorner = [UIBezierPath bezierPath];
    
    /** 四个角的轨迹点全部按该角顺时针方向生成 */
    //左上角
    UIBezierPath *leftUpCorner= [UIBezierPath bezierPath];
    [leftUpCorner moveToPoint:CGPointMake(VIEW_SIZE_WIDTH*(1-SCAN_RECT_RATIO)/2, (VIEW_SIZE_HEIGHT-VIEW_SIZE_WIDTH*SCAN_RECT_RATIO)/2+SCAN_OFFSET+VIEW_SIZE_WIDTH*SCAN_RECT_RATIO*ratio)];
    [leftUpCorner addLineToPoint:CGPointMake(VIEW_SIZE_WIDTH*(1-SCAN_RECT_RATIO)/2, (VIEW_SIZE_HEIGHT-VIEW_SIZE_WIDTH*SCAN_RECT_RATIO)/2+SCAN_OFFSET)];
    [leftUpCorner addLineToPoint:CGPointMake(VIEW_SIZE_WIDTH*((1-SCAN_RECT_RATIO)/2+SCAN_RECT_RATIO*ratio), (VIEW_SIZE_HEIGHT-VIEW_SIZE_WIDTH*SCAN_RECT_RATIO)/2+SCAN_OFFSET)];
    //左下角
    UIBezierPath *leftDownCorner= [UIBezierPath bezierPath];
    [leftDownCorner moveToPoint:CGPointMake(VIEW_SIZE_WIDTH*(1-SCAN_RECT_RATIO)/2+VIEW_SIZE_WIDTH*SCAN_RECT_RATIO*ratio, (VIEW_SIZE_HEIGHT-VIEW_SIZE_WIDTH*SCAN_RECT_RATIO)/2+VIEW_SIZE_WIDTH*SCAN_RECT_RATIO+SCAN_OFFSET)];
    [leftDownCorner addLineToPoint:CGPointMake(VIEW_SIZE_WIDTH*(1-SCAN_RECT_RATIO)/2, (VIEW_SIZE_HEIGHT-VIEW_SIZE_WIDTH*SCAN_RECT_RATIO)/2+VIEW_SIZE_WIDTH*SCAN_RECT_RATIO+SCAN_OFFSET)];
    [leftDownCorner addLineToPoint:CGPointMake(VIEW_SIZE_WIDTH*(1-SCAN_RECT_RATIO)/2, VIEW_SIZE_HEIGHT/2-VIEW_SIZE_WIDTH*SCAN_RECT_RATIO*(ratio-0.5)+SCAN_OFFSET)];
    //右上角
    UIBezierPath *rightUpCorner= [UIBezierPath bezierPath];
    [rightUpCorner moveToPoint:CGPointMake(VIEW_SIZE_WIDTH*(1-(1-SCAN_RECT_RATIO)/2)-VIEW_SIZE_WIDTH*SCAN_RECT_RATIO*ratio, (VIEW_SIZE_HEIGHT-VIEW_SIZE_WIDTH*SCAN_RECT_RATIO)/2+SCAN_OFFSET)];
    [rightUpCorner addLineToPoint:CGPointMake(VIEW_SIZE_WIDTH*(1-(1-SCAN_RECT_RATIO)/2), (VIEW_SIZE_HEIGHT-VIEW_SIZE_WIDTH*SCAN_RECT_RATIO)/2+SCAN_OFFSET)];
    [rightUpCorner addLineToPoint:CGPointMake(VIEW_SIZE_WIDTH*(1-(1-SCAN_RECT_RATIO)/2), VIEW_SIZE_HEIGHT/2-VIEW_SIZE_WIDTH*SCAN_RECT_RATIO*(0.5-ratio)+SCAN_OFFSET)];
    //右下角
    UIBezierPath *rightDownCorner= [UIBezierPath bezierPath];
    [rightDownCorner moveToPoint:CGPointMake(VIEW_SIZE_WIDTH*(1-(1-SCAN_RECT_RATIO)/2), (VIEW_SIZE_HEIGHT-VIEW_SIZE_WIDTH*SCAN_RECT_RATIO)/2+SCAN_OFFSET-VIEW_SIZE_WIDTH*SCAN_RECT_RATIO*ratio+VIEW_SIZE_WIDTH*SCAN_RECT_RATIO)];
    [rightDownCorner addLineToPoint:CGPointMake(VIEW_SIZE_WIDTH*(1-(1-SCAN_RECT_RATIO)/2), (VIEW_SIZE_HEIGHT-VIEW_SIZE_WIDTH*SCAN_RECT_RATIO)/2+VIEW_SIZE_WIDTH*SCAN_RECT_RATIO+SCAN_OFFSET)];
    [rightDownCorner addLineToPoint:CGPointMake(VIEW_SIZE_WIDTH*(1-(1-SCAN_RECT_RATIO)/2)-VIEW_SIZE_WIDTH*SCAN_RECT_RATIO*ratio,  (VIEW_SIZE_HEIGHT-VIEW_SIZE_WIDTH*SCAN_RECT_RATIO)/2+VIEW_SIZE_WIDTH*SCAN_RECT_RATIO+SCAN_OFFSET)];
    //添加所有路径
    [fourCorner appendPath:leftUpCorner];
    [fourCorner appendPath:leftDownCorner];
    [fourCorner appendPath:rightUpCorner];
    [fourCorner appendPath:rightDownCorner];
    //设置线宽和颜色
    scanBoxLayer.lineWidth = lineWidth;
    scanBoxLayer.strokeColor = color.CGColor;
    scanBoxLayer.fillColor = nil;
    //添加动画
    UIBezierPath *initPath = [UIBezierPath bezierPathWithRect:CGRectMake(VIEW_SIZE_WIDTH/2, VIEW_SIZE_HEIGHT/2+SCAN_OFFSET, 0, 0)];
    scanBoxLayer.path = initPath.CGPath;
    CABasicAnimation *cornerAnimation = [CABasicAnimation animationWithKeyPath:@"path"];
    cornerAnimation.toValue = (id)fourCorner.CGPath;
    cornerAnimation.duration = SCAN_FRAME_ANIMATION_DURATION;
    cornerAnimation.fillMode = kCAFillModeForwards;
    cornerAnimation.removedOnCompletion = NO;
    [scanBoxLayer addAnimation:cornerAnimation forKey:nil];
    
    return scanBoxLayer;
}


/**
 生成扫描线

 @param color 扫描线颜色
 @param height 扫描线厚度
 @param duration 扫描线动画时间
 @return 扫描线Layer
 */
- (CAGradientLayer*)getScanLine:(UIColor*)color height:(float)height duration:(float)duration{
    //扫描线生成和遮罩
    CAShapeLayer *scanlineMask = [[CAShapeLayer alloc] init];
    UIBezierPath *scanLineMaskPath = [UIBezierPath  bezierPathWithOvalInRect:CGRectMake(0, 0, VIEW_SIZE_WIDTH*SCAN_RECT_RATIO*0.95, height)];
    scanlineMask.path = scanLineMaskPath.CGPath;
    scanlineMask.strokeColor = color.CGColor;
    scanlineMask.fillColor = color.CGColor;
    CAGradientLayer *scanLineLayer = [CAGradientLayer layer];
    scanLineLayer.frame    = CGRectMake(0, 0, VIEW_SIZE_WIDTH*SCAN_RECT_RATIO*0.95, height);
    scanLineLayer.position = CGPointMake(VIEW_SIZE_WIDTH/2, VIEW_SIZE_HEIGHT/2+SCAN_OFFSET);
    scanLineLayer.colors = @[(__bridge id)[color colorWithAlphaComponent:0.05].CGColor,
                          (__bridge id)[color colorWithAlphaComponent:0.8].CGColor,
                          (__bridge id)[color colorWithAlphaComponent:0.05].CGColor];
    scanLineLayer.locations  = @[@(0.05), @(0.5), @(0.95)];
    scanLineLayer.startPoint = CGPointMake(0.5, 0.5);
    scanLineLayer.endPoint   = CGPointMake(0.5, 0.5);
    scanLineLayer.mask = scanlineMask;
    //扫描线生成动画
    CABasicAnimation *scanLinePositionAnimation = [CABasicAnimation animationWithKeyPath:@"position"];
    scanLinePositionAnimation.toValue = [NSValue valueWithCGPoint:CGPointMake(VIEW_SIZE_WIDTH/2, (VIEW_SIZE_HEIGHT-VIEW_SIZE_WIDTH*SCAN_RECT_RATIO)/2+SCAN_OFFSET+height)];
    CABasicAnimation *scanLineStartPointAnimation = [CABasicAnimation animationWithKeyPath:@"startPoint"];
    scanLineStartPointAnimation.toValue = [NSValue valueWithCGPoint:CGPointMake(0, 0)];
    CABasicAnimation *scanLineEndPointAnimation = [CABasicAnimation animationWithKeyPath:@"endPoint"];
    scanLineEndPointAnimation.toValue = [NSValue valueWithCGPoint:CGPointMake(1, 0)];
    CAAnimationGroup *initialAnimations = [CAAnimationGroup animation];
    initialAnimations.animations = @[scanLinePositionAnimation,scanLineStartPointAnimation,scanLineEndPointAnimation];
    initialAnimations.duration=SCAN_FRAME_ANIMATION_DURATION;
    initialAnimations.removedOnCompletion = NO;
    initialAnimations.fillMode = kCAFillModeForwards;
    [scanLineLayer addAnimation:initialAnimations forKey:nil];
    //扫描动画
    CABasicAnimation *scanAnimation = [CABasicAnimation animationWithKeyPath:@"position"];
    scanAnimation.toValue = [NSValue valueWithCGPoint:CGPointMake(VIEW_SIZE_WIDTH/2, (VIEW_SIZE_HEIGHT-VIEW_SIZE_WIDTH*SCAN_RECT_RATIO)/2+SCAN_OFFSET-height+VIEW_SIZE_WIDTH*SCAN_RECT_RATIO)];
    scanAnimation.duration = duration;
    scanAnimation.repeatCount = HUGE_VALF;
    scanAnimation.removedOnCompletion = NO;
    [scanLineLayer addAnimation:scanAnimation forKey:nil];
    return scanLineLayer;
}

/** 加载扫描框生成动画 */
- (void)loadScanAnimation{
    UIBezierPath *maskFinalPath = [UIBezierPath bezierPathWithRect:CGRectMake(0, 0, VIEW_SIZE_WIDTH, VIEW_SIZE_HEIGHT)];
    [maskFinalPath appendPath:[[UIBezierPath bezierPathWithRoundedRect:CGRectMake(
                                                                                  (VIEW_SIZE_WIDTH-VIEW_SIZE_WIDTH*SCAN_RECT_RATIO)/2,
                                                                                  (VIEW_SIZE_HEIGHT-VIEW_SIZE_WIDTH*SCAN_RECT_RATIO)/2+SCAN_OFFSET,
                                                                                  VIEW_SIZE_WIDTH*SCAN_RECT_RATIO,
                                                                                  VIEW_SIZE_WIDTH*SCAN_RECT_RATIO
                                                                                  ) cornerRadius:1] bezierPathByReversingPath]];
    CABasicAnimation *scanAnimation = [CABasicAnimation animationWithKeyPath:@"path"];
    scanAnimation.toValue = (id)maskFinalPath.CGPath;
    scanAnimation.duration = SCAN_FRAME_ANIMATION_DURATION;
    scanAnimation.fillMode = kCAFillModeForwards;
    scanAnimation.removedOnCompletion = NO;
    [self.maskLayer addAnimation:scanAnimation forKey:nil];
}

#pragma mark - AVCaptureMetadataOutputObjectsDelegate
-(void)captureOutput:(AVCaptureOutput *)captureOutput didOutputMetadataObjects:(NSArray *)metadataObjects fromConnection:(AVCaptureConnection *)connection{
    if (metadataObjects.count>0) {
        [session stopRunning];
        AVMetadataMachineReadableCodeObject * metadataObject = [metadataObjects objectAtIndex : 0 ];
        [self scanResultString:metadataObject.stringValue];
        [self scanResult:metadataObject];
        //输出扫描字符串
        NSLog(@"%@",metadataObject.stringValue);
    }
}

#pragma mark - UIImagePickerControllerDelegate
-(void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<NSString *,id> *)info{
    //获取选中的照片
    UIImage *image = info[UIImagePickerControllerEditedImage];
    if (!image) {image = info[UIImagePickerControllerOriginalImage];}
    //初始化  将类型设置为二维码
    CIDetector *detector = [CIDetector detectorOfType:CIDetectorTypeQRCode context:nil options:nil];
    [picker dismissViewControllerAnimated:YES completion:^{
        //设置数组，放置识别完之后的数据
        NSArray *features = [detector featuresInImage:[CIImage imageWithData:UIImagePNGRepresentation(image)]];
        //判断是否有数据（即是否是二维码）
        if (features.count >= 1) {
            //取第一个元素就是二维码所存放的文本信息
            CIQRCodeFeature *feature = features[0];
            NSString *scannedResult = feature.messageString;
            //通过对话框的形式呈现(临时)
            [self scanResultString:scannedResult];
            [self scanResult:feature];
        }else{
            [self alertControllerMessage:@"未检测到二维码"];
        }
    }];
}

#pragma mark - CommonMethod
/** 相册读取图片方法 */
- (void)scanImage{
    UIImagePickerController *imagrPicker = [[UIImagePickerController alloc]init];
    imagrPicker.delegate = self;
    imagrPicker.allowsEditing = YES;
    imagrPicker.mediaTypes = [[NSArray alloc] initWithObjects:(NSString*)kUTTypeImage,nil];
    //将来源设置为相册
    imagrPicker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    [self presentViewController:imagrPicker animated:YES completion:nil];
}

/** 闪光灯开关方法 */
- (void)onOffFlashLight:(BOOL)on{
    AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    if ([device hasTorch]) {
        
        [device lockForConfiguration:nil];
        if (on) {
            [device setTorchMode:AVCaptureTorchModeOn];
        }else{
            [device setTorchMode:AVCaptureTorchModeOff];
        }
        [device unlockForConfiguration];
    }
}

/** 弹窗(临时) */
-(void)alertControllerMessage:(NSString *)message{
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"" message:message preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *action = [UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
        [session startRunning];
    }];
    [alert addAction:action];
    [self presentViewController:alert animated:YES completion:nil];
}

/** 检测是否有相机权限 */
- (BOOL)checkCameraPermissions{
    NSString *mediaType = AVMediaTypeVideo;//读取媒体类型
    AVAuthorizationStatus authStatus = [AVCaptureDevice authorizationStatusForMediaType:mediaType];//读取设备授权状态
    if(authStatus == AVAuthorizationStatusRestricted || authStatus == AVAuthorizationStatusDenied){
        NSString *errorStr = @"应用相机权限受限,请在设置中启用";
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"" message:errorStr preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction *cancleAction = [UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil];
        UIAlertAction *settingAction = [UIAlertAction actionWithTitle:@"设置" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            NSURL *url = [NSURL URLWithString:UIApplicationOpenSettingsURLString];
            if ([[UIApplication sharedApplication] canOpenURL:url]) {[[UIApplication sharedApplication] openURL:url];}
        }];
        [alert addAction:cancleAction];
        [alert addAction:settingAction];
        [self presentViewController:alert animated:YES completion:nil];
        return NO;
    }
    return YES;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
