//
//  ViewController.m
//  PositionLogger
//
//  Created by Sam Madden on 2/3/16.
//  Copyright © 2016 Sam Madden. All rights reserved.
//

#import "ViewController.h"

#define kDATA_FILE_NAME @"log.csv"

#define EWMA_WEIGHT .75

#define degToRad(x) (M_PI * (x) / 180.0)
#define radToDeg(x) ((x) * 180.0 / M_PI)

@interface ViewController ()
@end

@implementation ViewController {
  CLLocationManager *_locmgr;
  BOOL _isRecording;
  NSFileHandle *_f;
  UIAlertController *_alert;

  CLLocation *targetLoc;
  CLLocation *startLoc;
  //CLLocation *prevLoc;

  double prevSpeed;
  double eta;
  double thresholdDistance;
}

- (void)viewDidLoad {
  [super viewDidLoad];

  self.mapView.delegate = self;
  self.mapView.showsUserLocation = YES;
  NSLog(@"Content scale factor is %f",self.mapView.contentScaleFactor);
  
  [self.mapView setUserTrackingMode:MKUserTrackingModeFollow];
  
  startLoc = NULL;
  //prevLoc = NULL;
  thresholdDistance = 30; //distance (in meters) where we say you've arrived

  prevSpeed = 0;
  eta = INFINITY;

  [_accuracyControl addTarget:self
                       action:@selector(action:)
             forControlEvents:UIControlEventValueChanged];

  //location manager setup
  _locmgr = [[CLLocationManager alloc] init];
  [_locmgr requestAlwaysAuthorization];
  _locmgr.delegate = self;
  _locmgr.distanceFilter = kCLDistanceFilterNone;
  _locmgr.allowsBackgroundLocationUpdates = TRUE;
  [_locmgr disallowDeferredLocationUpdates];
  _locmgr.desiredAccuracy = kCLLocationAccuracyBest;

  //battery logging setup
  [[UIDevice currentDevice] setBatteryMonitoringEnabled:TRUE];
  //UI setup
  self.recordingIndicator.hidesWhenStopped = TRUE;
  self.startStopButton.layer.borderWidth = 1.0;
  self.startStopButton.layer.cornerRadius = 5.0;

  _f  = [self openFileForWriting];
  if (!_f) {
    NSAssert(_f, @"Couldn't open file for writing.");
  }

  [self logLineToDataFile:
            @"Time,Lat,Lon,Altitude,Accuracy,Heading,Speed,ETA\n"];

  // Do any additional setup after loading the view, typically from a nib.
}

-(NSString *)getPathToLogFile {
  NSArray *paths = NSSearchPathForDirectoriesInDomains(
                       NSDocumentDirectory, NSUserDomainMask, YES);
  NSString *documentsDirectory = [paths objectAtIndex:0];
  NSString *filePath =
      [documentsDirectory stringByAppendingPathComponent:kDATA_FILE_NAME];
  return filePath;
}

-(NSFileHandle *)openFileForWriting {
  NSFileManager *fileManager = [NSFileManager defaultManager];
  NSFileHandle *f;
  [fileManager createFileAtPath:[self getPathToLogFile]
                       contents:nil
                     attributes:nil];
  f = [NSFileHandle fileHandleForWritingAtPath:[self getPathToLogFile]];
  return f;
}

- (void)action:(id)sender {
  switch ([self.accuracyControl selectedSegmentIndex]) {
    case Loc1:
      _targetAddressLabel.text = @"Destination: 77 Mass Ave";
      targetLoc = [[CLLocation alloc] initWithLatitude:42.3593071
                                             longitude:-71.0957108];
      break;
    case Loc2:
      _targetAddressLabel.text = @"Destination: Stata Center";
      targetLoc = [[CLLocation alloc] initWithLatitude:42.3616423
                                             longitude:-71.0928574];
      break;
    case Loc3:
      _targetAddressLabel.text = @"Destination: Walker Memorial";
      targetLoc = [[CLLocation alloc] initWithLatitude:42.3593702
                                             longitude:-71.09051];
      break;
    case Loc4:
      _targetAddressLabel.text = @"Destination: Baker";
      targetLoc = [[CLLocation alloc] initWithLatitude:42.3569925
                                             longitude:-71.0957];
      break;
    default:
      NSLog(@"Didn't recognize loc");
  }
}

- (void)didReceiveMemoryWarning {
  [super didReceiveMemoryWarning];
  // Dispose of any resources that can be recreated.
}

-(void)logLineToDataFile:(NSString *)line {
  [_f writeData:[line dataUsingEncoding:NSUTF8StringEncoding]];
}

-(void)resetLogFile {
  [_f closeFile];
  _f = [self openFileForWriting];
  if (!_f)
    NSAssert(_f, @"Couldn't open file for writing.");
}

//TODO: Implement me
-(void)startRecordingLocationWithAccuracy:(Location)loc {
  [_locmgr startUpdatingLocation];
}

-(void)stopRecordingLocationWithAccuracy {
  [_locmgr stopUpdatingLocation];
}


-(IBAction)hitRecordStopButton:(UIButton *)b {
  startLoc = NULL;
  if (!_isRecording) {
    [self.accuracyControl setEnabled:FALSE];
    [b setTitle:@"Stop" forState:UIControlStateNormal];
    _isRecording = TRUE;
    [self.recordingIndicator startAnimating];
    [self startRecordingLocationWithAccuracy:
        (Location)[self.accuracyControl selectedSegmentIndex]];
  } else {
    [self.accuracyControl setEnabled:TRUE];
    [b setTitle:@"Start" forState:UIControlStateNormal];
    _isRecording = FALSE;
    [self.recordingIndicator stopAnimating];
    [self stopRecordingLocationWithAccuracy];
  }
}

-(IBAction)hitClearButton:(UIButton *)b {
  [self resetLogFile];
}

-(IBAction)emailLogFile:(UIButton *)b {
  
  if (![MFMailComposeViewController canSendMail]) {
    _alert =
        [UIAlertController
            alertControllerWithTitle:@"Can't send mail"
                             message:@"Please set up an email account on this "
                                      "phone to send mail"
                      preferredStyle:UIAlertControllerStyleAlert
        ];

    UIAlertAction* ok =
        [UIAlertAction
            actionWithTitle:@"OK"
                      style:UIAlertActionStyleDefault
                    handler:^(UIAlertAction * action) {
                           [self dismissViewControllerAnimated:YES
                                                    completion:nil];
                    }
        ];

    [_alert addAction:ok]; // add action to uialertcontroller
    [self presentViewController:_alert animated:YES completion:nil];

    return;
  }

  NSData *fileData = [NSData dataWithContentsOfFile:[self getPathToLogFile]];
  if (!fileData || [fileData length] == 0) {
    return;
  }

  NSString *emailTitle = @"Position File";
  NSString *messageBody = @"Data from PositionLogger";

  MFMailComposeViewController *mc = [[MFMailComposeViewController alloc] init];
  mc.mailComposeDelegate = self;
  [mc setSubject:emailTitle];
  [mc setMessageBody:messageBody isHTML:NO];

  // Determine the MIME type
  NSString *mimeType = @"text/plain";

  // Add attachment
  [mc addAttachmentData:fileData mimeType:mimeType fileName:kDATA_FILE_NAME];

  // Present mail view controller on screen
  [self presentViewController:mc animated:YES completion:NULL];
}


#pragma mark - CLLocationManagerDelegate Methods -

- (void)locationManager:(CLLocationManager *)manager
     didUpdateLocations:(NSArray<CLLocation *> *)locations {
  //TODO: Prune readings based on accuracy?
  for (CLLocation *location in locations) {

    //If path hasn't been started, use the first location found.
    if (startLoc == NULL){
      startLoc = location;
    }
    
    if ([self arrivedAtDestination:location]) {
      [self stopRecordingLocationWithAccuracy];
      _distanceToLabel.text = @"Distance: You've arrived!";
      _ETALabel.text = @"But actually, you've arrived.";
      [self hitRecordStopButton:_startStopButton];
      //update UI
    }
    
    [self calculateEstimate:location];

//    NSLog(@"Updating location");
    _distanceToLabel.text = [NSString stringWithFormat: @"Distance: %f",
                                [self distanceBetween:targetLoc and:location]];
    _speedLabel.text = [NSString stringWithFormat:@"Speed: %f", location.speed];
    _ETALabel.text = [NSString stringWithFormat:@"ETA: %f", eta];
    [self logLineToDataFile:
        [NSString stringWithFormat:@"%f,%f,%f,%f,%f,%f,%f,%f\n",
            [location.timestamp timeIntervalSince1970],
            location.coordinate.latitude,
            location.coordinate.longitude,
            location.altitude,
            location.horizontalAccuracy,
            location.course,
            location.speed,
            eta
        ]
    ];
  }
}


#pragma mark - MFMailComposeViewControllerDelegate Methods -

- (void) mailComposeController:(MFMailComposeViewController *)controller
           didFinishWithResult:(MFMailComposeResult)result
                         error:(NSError *)error {
  switch (result)
  {
    case MFMailComposeResultCancelled:
      NSLog(@"Mail cancelled");
      break;
    case MFMailComposeResultSaved:
      NSLog(@"Mail saved");
      break;
    case MFMailComposeResultSent:
      NSLog(@"Mail sent");
      break;
    case MFMailComposeResultFailed:
      NSLog(@"Mail sent failure: %@", [error localizedDescription]);
      break;
    default:
      break;
  }

  // Close the Mail Interface
  [self dismissViewControllerAnimated:YES completion:NULL];
}


# pragma mark - Helper Functions -

-(bool) arrivedAtDestination:(CLLocation *)currentLocation {
  NSLog(@"We arrived: %d",([self distanceBetween:currentLocation
                                            and:targetLoc] < thresholdDistance));
  return [self distanceBetween:currentLocation
                           and:targetLoc] < thresholdDistance;
}

-(double)distanceBetween:(CLLocation *)loc1 and:(CLLocation *)loc2 {
  double lat1 = degToRad(loc1.coordinate.latitude);
  double lon1 = degToRad(loc1.coordinate.longitude);
  double lat2 = degToRad(loc2.coordinate.latitude);
  double lon2 = degToRad(loc2.coordinate.longitude);
  double r = 6371000; //radius of the earth, m

  double distance =
             2*r*asin(
                     sqrt(pow(sin((lat2 - lat1)/2), 2) +
                          cos(lat1)*cos(lat2)*pow(sin((lon2 - lon1)/2), 2))
                 );

  return distance;
}

-(double)angleBetween:(CLLocation *)loc1 and:(CLLocation *)loc2 {
  double lat1 = loc1.coordinate.latitude;
  double lon1 = loc1.coordinate.longitude;
  double lat2 = loc2.coordinate.latitude;
  double lon2 = loc2.coordinate.longitude;

  double angleRadians =
             atan2(sin(lon2 - lon1)*cos(lat2),
                   cos(lat1)*sin(lat2) - sin(lat1)*cos(lat2)*cos(lon2 - lon1));

  // Ensure that results are in the range [0, 2pi).
  if (angleRadians < 0) {
    angleRadians += 2*M_PI;
  }

  return radToDeg(angleRadians);
}

//TODO: Make more robust by EWMA'ing angle? Or averaging over previous velocities?
-(void) calculateEstimate:(CLLocation *)location {
  if (location.speed != -1 && location.course >= 0) {
    // Generate destination vector.
    double distanceToDest = [self distanceBetween:location and:targetLoc];
    double angleToDest = [self angleBetween:location and:targetLoc];

    // Calculate projection.
    double angleDiff = angleToDest - location.course;
    double projectedSpeed = location.speed * fabs(cos(angleDiff));

    double speed = EWMA_WEIGHT*projectedSpeed + (1 - EWMA_WEIGHT)*prevSpeed;
    eta = distanceToDest/speed;
    prevSpeed = speed;
  }
}

@end
