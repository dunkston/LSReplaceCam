#import <spawn.h>

@interface SBApplicationProcessState
	@property(nonatomic, readonly) int pid;
@end

@interface SBApplication
	@property(nonatomic, readonly) SBApplicationProcessState * processState;
@end

@interface SBApplicationController
	+ (id)sharedInstance;
	- (id)applicationWithBundleIdentifier:(id)arg1;
	- (id)cameraApplication;
@end

@interface SBFUserAuthenticationController
	- (void)_setAuthState:(long long)arg1;
@end

@interface SBDashBoardIdleTimerProvider
	- (void)addDisabledIdleTimerAssertionReason:(id)arg1;
	- (void)removeDisabledIdleTimerAssertionReason:(id)arg1;
@end

SBFUserAuthenticationController *authController;
SBApplication *sbApp;
SBDashBoardIdleTimerProvider *idleTimer;

static BOOL alreadyRunning;

static void updatePrefs() {
		pid_t pid;
		int status;
		const char* args[] = {"killall", "-9", "backboardd", NULL};
		posix_spawn(&pid, "/usr/bin/killall", NULL, NULL, (char* const*)args, NULL);
		waitpid(pid, &status, WEXITED);
}

%hook SBApplicationController

	// Credit to iMokhles for finding this method
	- (id)cameraApplication {
		NSMutableDictionary *prefs = [[NSMutableDictionary alloc] initWithContentsOfFile:[NSHomeDirectory() stringByAppendingFormat:@"/Library/Preferences/%s.plist", "com.dunkston.lsreplacecam"]];
		NSString *app = prefs[@"app"] ? prefs[@"app"] : @"com.apple.camera";
		[prefs release];
		sbApp = [self applicationWithBundleIdentifier: app];
		return sbApp;
	}

%end

%hook SBDashBoardCameraPageViewController

	- (void)viewWillAppear:(BOOL)arg1 {
		[authController _setAuthState: 1];
		alreadyRunning = sbApp.processState != nil;
		%orig;
		[idleTimer addDisabledIdleTimerAssertionReason: @"LSReplaceCam"];
	}

	-(void)viewWillDisappear:(BOOL)arg1 {
		if(MSHookIvar<BOOL>(authController, "_inSecureMode")) [authController _setAuthState: 0];
		%orig;
	}

	-(void)viewDidDisappear:(BOOL)arg1 {
		%orig;
		[idleTimer removeDisabledIdleTimerAssertionReason: @"LSReplaceCam"];

		if(!alreadyRunning) {
			pid_t pid;
			int status;
			const char *process = [[[NSNumber numberWithInt: sbApp.processState.pid] stringValue] UTF8String];
			const char* args[] = {"kill", "-9", process, NULL};
			posix_spawn(&pid, "/bin/kill", NULL, NULL, (char* const*)args, NULL);
			waitpid(pid, &status, WEXITED);
		}
	}

%end

%hook SBFUserAuthenticationController

	- (void)_setAuthState:(long long)arg1 {
		%orig;
		authController = self;
	}

%end

// Credit to NeinZedd9 for the code to disable lock screen dim
%hook SBDashBoardIdleTimerProvider

	- (id)initWithDelegate:(id)arg1 {
		idleTimer = self;
		return %orig;
	}

%end

%ctor {
	CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),
		NULL,
		(CFNotificationCallback)updatePrefs,
		CFSTR("com.dunkston.lsreplacecam.preferencesChanged"),
		NULL,
		CFNotificationSuspensionBehaviorDeliverImmediately
	);
}