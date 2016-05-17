//
//  AppDelegate.h
//  verge
//
//  Created by Brendan Chang on 3/10/16.
//  Copyright © 2016 verge. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <Google/SignIn.h>
#import <CoreLocation/CoreLocation.h>

@interface AppDelegate : UIResponder <UIApplicationDelegate, GIDSignInDelegate>

@property (strong, nonatomic) UIWindow *window;


@end

