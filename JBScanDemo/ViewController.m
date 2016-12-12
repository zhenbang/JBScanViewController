//
//  ViewController.m
//  JBScanDemo
//
//  Created by Jubal on 2016/12/12.
//  Copyright © 2016年 Jubal. All rights reserved.
//

#import "ViewController.h"
#import "JBScanViewController.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"JBScanDemo";
    // Do any additional setup after loading the view, typically from a nib.
}

- (IBAction)scanButtonAction:(id)sender {
    UIViewController *scanVC = [[JBScanViewController alloc] init];
    [self.navigationController pushViewController:scanVC animated:YES];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
