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
#import <CoreMotion/CoreMotion.h>
#import <MapKit/MapKit.h>

typedef enum {
    Loc1 = 0,
    Loc2 = 1,
    Loc3 = 2,
    Loc4 = 3
} Location;

@interface ViewController : UIViewController<MFMailComposeViewControllerDelegate,CLLocationManagerDelegate,MKMapViewDelegate>

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
@property (weak, nonatomic) IBOutlet UILabel *timeLabel;
@property (weak, nonatomic) IBOutlet MKMapView *mapView;

@end

