//
//  ViewController.h
//  verge
//
//  Created by Brendan Chang on 3/10/16.
//  Copyright © 2016 verge. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <Google/SignIn.h>

@interface ViewController : UIViewController <GIDSignInUIDelegate>

@property (weak, nonatomic) IBOutlet GIDSignInButton *signInButton;

@end

