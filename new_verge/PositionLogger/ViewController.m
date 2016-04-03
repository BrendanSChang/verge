//
//  ViewController.m
//  PositionLogger
//
//  Created by Sam Madden on 2/3/16.
//  Copyright © 2016 Sam Madden. All rights reserved.
//

#import "ViewController.h"

#define kDATA_FILE_NAME @"log.csv"

@interface ViewController ()
@end

@implementation ViewController {
  CLLocationManager *_locmgr;
  BOOL _isRecording;
  NSFileHandle *_f;
  UIAlertController *_alert;
  
  CLLocation *targetLoc;
  CLLocation *startLoc;
}

- (void)viewDidLoad {
  [super viewDidLoad];
  
  startLoc = NULL;
  
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
  if (!_f)
    NSAssert(_f,@"Couldn't open file for writing.");
  [self logLineToDataFile:@"Time,Lat,Lon,Altitude,Accuracy,Heading,Speed,Battery\n"];
  // Do any additional setup after loading the view, typically from a nib.
}

-(NSString *)getPathToLogFile {
  NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
  NSString *documentsDirectory = [paths objectAtIndex:0];
  NSString *filePath = [documentsDirectory stringByAppendingPathComponent:kDATA_FILE_NAME];
  return filePath;
}


-(NSFileHandle *)openFileForWriting {
  NSFileManager *fileManager = [NSFileManager defaultManager];
  NSFileHandle *f;
  [fileManager createFileAtPath:[self getPathToLogFile] contents:nil attributes:nil];
  f = [NSFileHandle fileHandleForWritingAtPath:[self getPathToLogFile]];
  return f;
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
    NSAssert(_f,@"Couldn't open file for writing.");
}

//TODO: Implement me
-(void)startRecordingLocationWithAccuracy:(Location)acc {

  switch (acc) {
    case Loc1:
      targetLoc = [[CLLocation alloc] initWithLatitude:42.3593071 longitude:-71.0957108];
      _targetAddressLabel.text = @"77 Mass Ave.";
      break;
    case Loc2:
      targetLoc = [[CLLocation alloc] initWithLatitude:42.3616423 longitude:-71.0928574];
      _targetAddressLabel.text = @"Stata Center";
      break;
    default:
      targetLoc = [[CLLocation alloc] initWithLatitude:42.3593702 longitude:-71.09051];
      _targetAddressLabel.text = @"Walker Memorial";
      break;
  }
  [_locmgr startUpdatingLocation];
}

//TODO: Implement me
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
    [self startRecordingLocationWithAccuracy:(Location)[self.accuracyControl selectedSegmentIndex]];
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
    _alert = [UIAlertController alertControllerWithTitle:@"Can't send mail" message:@"Please set up an email account on this phone to send mail" preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction* ok = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault
                                               handler:^(UIAlertAction * action)
                         {
                           [self dismissViewControllerAnimated:YES completion:nil];
                         }];
    [_alert addAction:ok]; // add action to uialertcontroller
    [self presentViewController:_alert animated:YES completion:nil];
    return;
  }
  NSData *fileData = [NSData dataWithContentsOfFile:[self getPathToLogFile]];
  
  if (!fileData || [fileData length] == 0)
    return;
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

//TODO: Implement me
- (void)locationManager:(CLLocationManager *)manager
     didUpdateLocations:(NSArray<CLLocation *> *)locations
{
  for (CLLocation *location in locations) {
    //if path hasn't been started, use the first location found
    if (startLoc == NULL){
      startLoc = location;
    }
    _distanceToLabel.text = [self distanceBetween:targetLoc and:location];
    _speedLabel.text = [NSString stringWithFormat:@"%f", location.speed];
    NSLog(@"Updating location");
    [self logLineToDataFile:[NSString stringWithFormat:@"%f,%f,%f,%f,%f,%f,%f,%f\n",[location.timestamp timeIntervalSince1970],location.coordinate.latitude,location.coordinate.longitude,location.altitude,location.horizontalAccuracy,location.course,location.speed,[[UIDevice currentDevice] batteryLevel]]];
  }
}


#pragma mark - MFMailComposeViewControllerDelegate Methods -

- (void) mailComposeController:(MFMailComposeViewController *)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError *)error
{
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


//Helper functions
-(NSString *)distanceBetween:(CLLocation *)loc1 and:(CLLocation *)loc2{
  double lat1 = loc1.coordinate.latitude;
  double lon1 = loc1.coordinate.longitude;
  double lat2 = loc2.coordinate.latitude;
  double lon2 = loc2.coordinate.longitude;
  double r = 6371;
  
  double distance = 2 * r * asin(sqrt(pow(sin((lat2 - lat1)/2),2) + cos(lat1)*cos(lat2)*pow(sin((lon2 - lon1)/2),2)));
  
  return [NSString stringWithFormat: @"%f",distance];
}

//TODO: Calculate the estimate of the progress on the path
-(void) calculateEstimate:(CLLocation *)location{
  
}

@end
