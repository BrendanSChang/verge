//
//  ViewController.m
//  PositionLogger
//
//  Created by Sam Madden on 2/3/16.
//  Copyright © 2016 Sam Madden. All rights reserved.
//

#import "ViewController.h"

#define kDATA_FILE_NAME @"log.csv"
#define magDATA_FILE_NAME @"magnetometerData.csv"
#define gyroDATA_FILE_NAME @"gyroscopeData.csv"
#define accDATA_FILE_NAME @"accelerometerData.csv"
#define pedDATA_FILE_NAME @"pedometerData.csv"
#define headingDATA_FILE_NAME @"headingData.csv"

//TODO: These need to be tuned.
#define EWMA_WEIGHT .75
#define INTERVAL 1
#define THRESHOLD_DISTANCE 15
#define STATE_COUNT 3

// Estimate of one degree of latitude in meters.
#define LAT_ONE_DEGREE_M 111111

#define degToRad(x) (M_PI * (x) / 180.0)
#define radToDeg(x) ((x) * 180.0 / M_PI)

@interface ViewController ()
@end

@implementation ViewController {
  CLLocationManager *_locmgr;
  CMMotionManager *_motmgr;
  CMPedometer *_pedometer;
  BOOL _isRecording;
  NSFileHandle *_f,*_mag,*_gyro,*_acc,*_ped,*_devmot,*_heading;
  UIAlertController *_alert;

  CLLocation *targetLoc;
  CLLocation *curLoc;

  double prevSpeed;
  double prevDist;
  double head;
  double eta;
  int count;
  bool outside;
}

- (void)viewDidLoad {

  [super viewDidLoad];

  self.mapView.delegate = self;
  self.mapView.showsUserLocation = YES;
  NSLog(@"Content scale factor is %f",self.mapView.contentScaleFactor);

  [self.mapView setUserTrackingMode:MKUserTrackingModeFollow];

  curLoc = NULL;

  prevSpeed = 0;
  prevDist = 0; //Only used for indoor localization with pedometer.
  head = 0;
  eta = INFINITY;
  count = 0; // Counter for determining outdoor/indoor state change.
  outside = TRUE; // Assume that we start outdoors.
  _timeLabel.text = [NSString stringWithFormat:@"Outside: %@",(outside ? @"True":@"False")];

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

  //motion manager setup
  _motmgr = [[CMMotionManager alloc] init];
  _motmgr.accelerometerUpdateInterval = INTERVAL;
  _motmgr.gyroUpdateInterval = INTERVAL;
  _motmgr.magnetometerUpdateInterval = INTERVAL;

  //pedometer setup
  _pedometer = [[CMPedometer alloc] init];
  
  //battery logging setup
  [[UIDevice currentDevice] setBatteryMonitoringEnabled:TRUE];
  //UI setup
  self.recordingIndicator.hidesWhenStopped = TRUE;
  self.startStopButton.layer.borderWidth = 1.0;
  self.startStopButton.layer.cornerRadius = 5.0;

  [self initializeAllFileHandles];
  [self writeFileHeaders];


  // Do any additional setup after loading the view, typically from a nib.
}

#pragma mark - Handling File Handles -
-(void) initializeAllFileHandles{
  
  _f  = [self openFileForWriting:kDATA_FILE_NAME];
  if (!_f) {
    NSAssert(_f, @"Couldn't open file for writing.");
  }
  
  _acc  = [self openFileForWriting:accDATA_FILE_NAME];
  if (!_acc) {
    NSAssert(_acc, @"Couldn't open file for writing.");
  }
  
  _gyro  = [self openFileForWriting:gyroDATA_FILE_NAME];
  if (!_gyro) {
    NSAssert(_gyro, @"Couldn't open file for writing.");
  }
  
  _mag  = [self openFileForWriting:magDATA_FILE_NAME];
  if (!_mag) {
    NSAssert(_mag, @"Couldn't open file for writing.");
  }
  
  _ped  = [self openFileForWriting:pedDATA_FILE_NAME];
  if (!_ped) {
    NSAssert(_ped, @"Couldn't open file for writing.");
  }
  
  _heading = [self openFileForWriting:headingDATA_FILE_NAME];
  if (!_heading) {
    NSAssert(_heading, @"Couldn't open file for writing.");
  }
  
}

-(void) writeFileHeaders{
  [self logLine:@"Time,Lat,Lon,Altitude,Accuracy,Heading,Speed,ETA,Type,Outside\n"
     ToDataFile:kDATA_FILE_NAME];
  [self logLine:@"Time,X,Y,Z\n" ToDataFile:magDATA_FILE_NAME];
  [self logLine:@"Time,X,Y,Z\n" ToDataFile:gyroDATA_FILE_NAME];
  [self logLine:@"Time,X,Y,Z\n" ToDataFile:accDATA_FILE_NAME];
  [self logLine:@"Time,Distance\n" ToDataFile:pedDATA_FILE_NAME];
  [self logLine:@"TimeStamp,Heading,Accuracy\n"
     ToDataFile:headingDATA_FILE_NAME];
}

-(void) closeAllFiles{
  [_f closeFile];
  [_acc closeFile];
  [_gyro closeFile];
  [_mag closeFile];
  [_ped closeFile];
  [_heading closeFile];
}

-(NSString *)getPathToLogFile:(NSString *) fileName {
  NSArray *paths = NSSearchPathForDirectoriesInDomains(
                       NSDocumentDirectory, NSUserDomainMask, YES);
  NSString *documentsDirectory = [paths objectAtIndex:0];
  NSString *filePath =
      [documentsDirectory stringByAppendingPathComponent:fileName];
  return filePath;
}

-(NSFileHandle *)openFileForWriting:(NSString *) fileName {
  NSFileManager *fileManager = [NSFileManager defaultManager];
  NSFileHandle *f;
  [fileManager createFileAtPath:[self getPathToLogFile:fileName]
                       contents:nil
                     attributes:nil];
  f = [NSFileHandle fileHandleForWritingAtPath:
                        [self getPathToLogFile:fileName]];
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

-(void)logLine:(NSString *)line ToDataFile:(NSString *)fileName {
  NSFileHandle *handle = [self getHandleOfFile:fileName];
  [handle writeData:[line dataUsingEncoding:NSUTF8StringEncoding]];
}

//Returns appropriate file handle based upon the file name we want to write to
-(NSFileHandle *)getHandleOfFile:(NSString *) fileName{
  //Objective-C can't handle switching on NSStrings...
  if ([fileName isEqual: kDATA_FILE_NAME]){
    return _f;
  } else if ([fileName isEqual: magDATA_FILE_NAME]) {
    return _mag;
  } else if ([fileName isEqual: gyroDATA_FILE_NAME]) {
    return _gyro;
  } else if ([fileName isEqual: accDATA_FILE_NAME]) {
    return _acc;
  } else if ([fileName isEqual: pedDATA_FILE_NAME]){
    return _ped;
  } else if ([fileName isEqual: headingDATA_FILE_NAME]){
    return _heading;
  } else {
    NSLog(@"File name didn't correspond to file handle.");
  }
  
  return [[NSFileHandle alloc]init];
}

-(void)resetLogFile {
  [self closeAllFiles];
  [self initializeAllFileHandles];
  [self writeFileHeaders];
}

//TODO: Implement me
-(void)startRecordingLocationWithAccuracy:(Location)loc {
  [_locmgr startUpdatingLocation];
  [_locmgr startUpdatingHeading];
  [self startRecordingIMUData];
  [self startPedometer];
}

-(void)stopRecordingLocationWithAccuracy {
  [_locmgr stopUpdatingLocation];
  [_locmgr stopUpdatingHeading];
  [self stopRecordingIMUData];
  [self stopPedometer];
}


//TODO: Write these values to file.
-(void)startRecordingIMUData {
  [_motmgr
      startAccelerometerUpdatesToQueue:[[NSOperationQueue alloc] init]
      withHandler:^(CMAccelerometerData *data, NSError *error) {
        if (error) {
          NSLog(@"Accelerometer error");
        } else {
          NSString *line = [NSString stringWithFormat:@"%@,%f,%f,%f\n",
                            [NSDate date],
                            data.acceleration.x,
                            data.acceleration.y,
                            data.acceleration.z
                            ];
          [self logLine:line ToDataFile:accDATA_FILE_NAME];
        }
      }
  ];
  
  [_motmgr
      startGyroUpdatesToQueue:[[NSOperationQueue alloc] init]
      withHandler:^(CMGyroData *data, NSError *error) {
        if (error) {
          NSLog(@"Gyroscope error");
        } else {
          NSString *line = [NSString stringWithFormat:@"%@,%f,%f,%f\n",
                            [NSDate date],
                            data.rotationRate.x,
                            data.rotationRate.y,
                            data.rotationRate.z
                            ];
          [self logLine:line ToDataFile:gyroDATA_FILE_NAME];
        }
      }
  ];
  
  [_motmgr
      startMagnetometerUpdatesToQueue:[[NSOperationQueue alloc] init]
      withHandler:^(CMMagnetometerData *data, NSError *error) {
        if (error) {
          NSLog(@"Magnetometer error");
        } else {
          NSString *line = [NSString stringWithFormat:@"%@,%f,%f,%f\n",
                            [NSDate date],
                            data.magneticField.x,
                            data.magneticField.y,
                            data.magneticField.z
                            ];
          [self logLine:line ToDataFile:magDATA_FILE_NAME];
        }
      }
  ];
}

-(void)stopRecordingIMUData {
  [_motmgr stopAccelerometerUpdates];
  [_motmgr stopGyroUpdates];
  [_motmgr stopMagnetometerUpdates];
}

-(void)startPedometer {
  [_pedometer
      startPedometerUpdatesFromDate:[NSDate date]
      withHandler:^(CMPedometerData *data, NSError *error) {
        if (error) {
          NSLog(@"Pedometer error: %@", [error localizedDescription]);
        } else {
          if ([CMPedometer isDistanceAvailable]) {
            double curDist = [data.distance doubleValue];
            double delta = curDist - prevDist;
            double speed = 1 / [data.currentPace doubleValue];
            prevDist = curDist;

            // Only estimate user's location if GPS is unavailable and there is
            // a well-defined previous location.
            if (!outside && curLoc != NULL) {
              double latDisp = (delta*cos(head))/LAT_ONE_DEGREE_M;
              double longDisp =
                         (delta*sin(head))/
                         (LAT_ONE_DEGREE_M*cos(curLoc.coordinate.longitude));

              curLoc = [[CLLocation alloc] initWithCoordinate:
                                               CLLocationCoordinate2DMake(
                                                   curLoc.coordinate.latitude +
                                                       latDisp,
                                                   curLoc.coordinate.longitude +
                                                       longDisp
                                               )
                                                     altitude:curLoc.altitude
                                           horizontalAccuracy:
                                               curLoc.horizontalAccuracy
                                             verticalAccuracy:
                                                 curLoc.verticalAccuracy
                                                       course:head
                                                        speed:speed
                                                    timestamp:[NSDate date]
                       ];
              
              if ([self arrivedAtDestination:curLoc]) {
                [self stopRecordingLocationWithAccuracy];
                _distanceToLabel.text = @"Distance: You've arrived";
                _ETALabel.text = @"ETA: You've arrived";
                [self hitRecordStopButton:_startStopButton];
              } else {
                [self calculateEstimate:curLoc];

                _distanceToLabel.text =
                    [NSString stringWithFormat:
                                  @"Distance: %f",
                                  [self distanceBetween:targetLoc and:curLoc]];
                _speedLabel.text =
                    [NSString stringWithFormat:@"Speed: %f", curLoc.speed];
                _ETALabel.text = [NSString stringWithFormat:@"ETA: %f", eta];

                [self logLine:
                  [NSString stringWithFormat:
                                @"%@,%f,%f,%f,%f,%f,%f,%f,%@,%i\n",
                                curLoc.timestamp,
                                curLoc.coordinate.latitude,
                                curLoc.coordinate.longitude,
                                curLoc.altitude,
                                curLoc.horizontalAccuracy,
                                curLoc.course,
                                curLoc.speed,
                                eta,
                                @"Est",
                                outside
                  ]
                  ToDataFile:kDATA_FILE_NAME
                ];
              }
            }

            NSString *line = [NSString stringWithFormat:@"%@,%f\n",
                                                        [NSDate date],
                                                        delta
                             ];
            [self logLine:line ToDataFile:pedDATA_FILE_NAME];
          }
        }
      }
  ];
}

-(void)stopPedometer {
  [_pedometer stopPedometerUpdates];
}

-(IBAction)hitRecordStopButton:(UIButton *)b {
  curLoc = NULL;
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

  NSString *emailTitle = @"Position File";
  NSString *messageBody = @"Data from PositionLogger";

  MFMailComposeViewController *mc = [[MFMailComposeViewController alloc] init];
  mc.mailComposeDelegate = self;
  [mc setSubject:emailTitle];
  [mc setMessageBody:messageBody isHTML:NO];
  
  //Attach all necessary data files
  [self addAttachment:kDATA_FILE_NAME To:mc];
  [self addAttachment:magDATA_FILE_NAME To:mc];
  [self addAttachment:gyroDATA_FILE_NAME To:mc];
  [self addAttachment:accDATA_FILE_NAME To:mc];
  [self addAttachment:pedDATA_FILE_NAME To:mc];
  [self addAttachment:headingDATA_FILE_NAME To:mc];

  // Present mail view controller on screen
  [self presentViewController:mc animated:YES completion:NULL];
}

-(void) addAttachment:(NSString *)fileName
                   To:(MFMailComposeViewController *)mc {
  //Get contents of file
  NSData *fileData = [NSData dataWithContentsOfFile:
                                 [self getPathToLogFile:fileName]];
  if (!fileData || [fileData length] == 0) {
    NSLog(@"THE DATA FILE IS EMPTY");
    return;
  }

  // Determine the MIME type
  NSString *mimeType = @"text/plain";

  // Add attachment
  [mc addAttachmentData:fileData mimeType:mimeType fileName:fileName];
}

#pragma mark - CLLocationManagerDelegate Methods -

- (void)locationManager:(CLLocationManager *)manager
     didUpdateLocations:(NSArray<CLLocation *> *)locations {
  // Use the most recent accurate update.
  for (CLLocation *location in [locations reverseObjectEnumerator]) {
    if (location.horizontalAccuracy <= THRESHOLD_DISTANCE) {
      [self updateState:Outdoors];

      if (outside) {
        curLoc = location;

        if ([self arrivedAtDestination:location]) {
          [self stopRecordingLocationWithAccuracy];
          _distanceToLabel.text = @"Distance: You've arrived";
          _ETALabel.text = @"ETA: You've arrived";
          [self hitRecordStopButton:_startStopButton];
        } else {
          [self calculateEstimate:location];

          _distanceToLabel.text =
              [NSString stringWithFormat:
                            @"Distance: %f",
                            [self distanceBetween:targetLoc and:location]];
          _speedLabel.text =
              [NSString stringWithFormat:@"Speed: %f", location.speed];
          _ETALabel.text = [NSString stringWithFormat:@"ETA: %f", eta];

          [self logLine:
                    [NSString stringWithFormat:
                                 @"%@,%f,%f,%f,%f,%f,%f,%f,%@,%i\n",
                                 location.timestamp,
                                 location.coordinate.latitude,
                                 location.coordinate.longitude,
                                 location.altitude,
                                 location.horizontalAccuracy,
                                 location.course,
                                 location.speed,
                                 eta,
                                 @"GPS",
                                 outside
                    ]
             ToDataFile:kDATA_FILE_NAME
          ];
        }
      }

      return;
    }
  }

  [self updateState:Indoors];
}

-(void)locationManager:(CLLocationManager *)manager
      didUpdateHeading:(CLHeading *)newHeading {
  if (newHeading.headingAccuracy >= 0) {
    head = newHeading.magneticHeading;
  }

  [self logLine:
            [NSString stringWithFormat:
                          @"%@,%f,%f\n",
                          newHeading.timestamp,
                          newHeading.magneticHeading,
                          newHeading.headingAccuracy
            ]
     ToDataFile:headingDATA_FILE_NAME
  ];
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

// STATE_COUNT is the threshold used to determine the number of updates with
// good/bad accuracy necessary to change the user's state from outdoors to
// indoors or vice versa.
-(void) updateState:(State)move {
  if ((outside && move == Indoors) || (!outside && move == Outdoors)) {
    count++;
  } else {
    count = 0;
  }

  if (count == STATE_COUNT) {
    _timeLabel.text = [NSString stringWithFormat:@"Outside: %@",(outside ? @"True":@"False")];
    outside = !outside;
    count = 0;
  }
}

-(bool) arrivedAtDestination:(CLLocation *)currentLocation {
    return [self distanceBetween:currentLocation
                             and:targetLoc]
                                                  < THRESHOLD_DISTANCE;
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

//TODO: Make more robust by EWMA'ing angle/averaging over previous velocities?
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
