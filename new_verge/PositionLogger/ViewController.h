//
//  ViewController.h
//  PositionLogger
//
//  Created by Sam Madden on 2/3/16.
//  Copyright © 2016 Sam Madden. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <MessageUI/MessageUI.h>
#import <CoreLocation/CoreLocation.h>

typedef enum {
    Loc1 = 0,
    Loc2 = 1,
    Loc3 = 2
} Location;

@interface ViewController : UIViewController<MFMailComposeViewControllerDelegate,CLLocationManagerDelegate>

@property IBOutlet UISegmentedControl *accuracyControl;
@property IBOutlet UIButton *startStopButton;
@property IBOutlet UIActivityIndicatorView *recordingIndicator;

-(IBAction)hitRecordStopButton:(UIButton *)b;
-(IBAction)hitClearButton:(UIButton *)b;
-(IBAction)emailLogFile:(UIButton *)b;

@property (weak, nonatomic) IBOutlet UILabel *ETALabel;
@property (weak, nonatomic) IBOutlet UILabel *speedLabel;
@property (weak, nonatomic) IBOutlet UILabel *distanceToLabel;
@property (weak, nonatomic) IBOutlet UILabel *targetAddressLabel;

@end

