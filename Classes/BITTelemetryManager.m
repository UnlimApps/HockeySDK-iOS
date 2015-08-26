#import "HockeySDK.h"

#if HOCKEYSDK_FEATURE_TELEMETRY

#import "BITTelemetryManager.h"
#import "BITTelemetryManagerPrivate.h"
#import "BITHockeyHelper.h"
#import "HockeySDKPrivate.h"

#import "BITSession.h"

static char *const kBITTelemetryEventQueue =
"com.microsoft.ApplicationInsights.telemetryEventQueue";

NSString *const kBITSessionFileType = @"plist";
NSString *const kBITApplicationDidEnterBackgroundTime = @"BITApplicationDidEnterBackgroundTime";
NSString *const kBITApplicationWasLaunched = @"BITApplicationWasLaunched";

@implementation BITTelemetryManager {
  id _appWillEnterForegroundObserver;
  id _appDidEnterBackgroundObserver;
}

#pragma mark - Create & start instance

- (instancetype)init {
  if((self = [super init])) {
    _telemetryEventQueue = dispatch_queue_create(kBITTelemetryEventQueue, DISPATCH_QUEUE_CONCURRENT);
    _appBackgroundTimeBeforeSessionExpires = 20;
  }
  return self;
}

- (void)startManager {
  [self startNewSession];
  [self registerObservers];
  
}

#pragma mark - Sessions

- (void)registerObservers {
  NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
  
  __weak typeof(self) weakSelf = self;
  
  if(nil == _appDidEnterBackgroundObserver) {
    _appDidEnterBackgroundObserver = [nc addObserverForName:UIApplicationDidEnterBackgroundNotification
                                                     object:nil
                                                      queue:NSOperationQueue.mainQueue
                                                 usingBlock:^(NSNotification *note) {
                                                   typeof(self) strongSelf = weakSelf;
                                                   [strongSelf updateDidEnterBackgroundTime];
                                                 }];
  }
  if(nil == _appWillEnterForegroundObserver) {
    _appWillEnterForegroundObserver = [nc addObserverForName:UIApplicationWillEnterForegroundNotification
                                                      object:nil
                                                       queue:NSOperationQueue.mainQueue
                                                  usingBlock:^(NSNotification *note) {
                                                    typeof(self) strongSelf = weakSelf;
                                                    [strongSelf startNewSessionIfNeeded];
                                                  }];
  }
}

- (void)unregisterObservers {
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  _appDidEnterBackgroundObserver = nil;
  _appWillEnterForegroundObserver = nil;
}

- (void)updateDidEnterBackgroundTime {
  [[NSUserDefaults standardUserDefaults] setDouble:[[NSDate date] timeIntervalSince1970] forKey:kBITApplicationDidEnterBackgroundTime];
  [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)startNewSessionIfNeeded {
  if(self.appBackgroundTimeBeforeSessionExpires == 0) {
    [self startNewSession];
    return;
  }
  
  double appDidEnterBackgroundTime = [[NSUserDefaults standardUserDefaults] doubleForKey:kBITApplicationDidEnterBackgroundTime];
  double timeSinceLastBackground = [[NSDate date] timeIntervalSince1970] - appDidEnterBackgroundTime;
  if(timeSinceLastBackground > self.appBackgroundTimeBeforeSessionExpires) {
    [self startNewSession];
  }
}

- (void)startNewSession {
  NSString *newSessionId = bit_UUID();
  [self startNewSessionWithId:newSessionId];
}

- (void)startNewSessionWithId:(NSString *)sessionId {
  BITSession *session = [BITSession new];
  session.sessionId = sessionId;
  session.isNew = @"false";
  
  if(![[NSUserDefaults standardUserDefaults] boolForKey:kBITApplicationWasLaunched]) {
    session.isFirst = @"true";
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:kBITApplicationWasLaunched];
    [[NSUserDefaults standardUserDefaults] synchronize];
  } else {
    session.isFirst = @"false";
  }
  
  // TODO: Send session event to server
  BITHockeyLog(@"TELEMETRY: Session with ID %@ has been tracked", sessionId);
}

@end

#endif /* HOCKEYSDK_FEATURE_TELEMETRY */
