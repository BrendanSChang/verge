//
//  ViewController.m
//  verge
//
//  Created by Brendan Chang on 3/10/16.
//  Copyright © 2016 verge. All rights reserved.
//

#import "ViewController.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.

    [GIDSignIn sharedInstance].uiDelegate = self;
    
    // Attempt to sign-in silently.
    //[[GIDSignIn sharedInstance] signInSilently];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
