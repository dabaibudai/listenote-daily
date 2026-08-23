#import <Cocoa/Cocoa.h>
#import <errno.h>
#import <signal.h>

@interface AppDelegate : NSObject <NSApplicationDelegate>
@property(nonatomic, strong) NSStatusItem *statusItem;
@property(nonatomic, strong) NSMenuItem *stateItem;
@property(nonatomic, strong) NSMenuItem *modelItem;
@property(nonatomic, strong) NSMenuItem *countItem;
@property(nonatomic, strong) NSMenuItem *latestItem;
@property(nonatomic, strong) NSMenuItem *stopItem;
@property(nonatomic, strong) NSTimer *timer;
@property(nonatomic, strong) NSString *rootPath;
@end

@implementation AppDelegate

- (NSImage *)symbol:(NSString *)name fallback:(NSString *)fallback {
    NSImage *image = [NSImage imageWithSystemSymbolName:name accessibilityDescription:nil];
    if (!image) image = [NSImage imageWithSystemSymbolName:fallback accessibilityDescription:nil];
    NSImageSymbolConfiguration *config =
        [NSImageSymbolConfiguration configurationWithPointSize:14 weight:NSFontWeightMedium];
    image = [image imageWithSymbolConfiguration:config];
    image.template = YES;
    return image;
}

- (NSString *)recordsDirectory {
    return [self.rootPath stringByAppendingPathComponent:@"records/transcripts"];
}

- (NSString *)recorderPIDPath {
    return [self.rootPath stringByAppendingPathComponent:@"records/whisper-daily.pid"];
}

- (NSString *)statusPIDPath {
    return [self.rootPath stringByAppendingPathComponent:@"records/whisper-status.pid"];
}

- (NSString *)schedulePath {
    return [self.rootPath stringByAppendingPathComponent:@"config/schedule.conf"];
}

- (pid_t)readPID:(NSString *)path {
    NSString *value = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
    return value ? (pid_t)[value intValue] : 0;
}

- (BOOL)processIsAlive:(pid_t)pid {
    if (pid <= 0) return NO;
    if (kill(pid, 0) == 0) return YES;
    return errno == EPERM;
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    self.rootPath = [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Application Support/WhisperDaily"];

    pid_t existing = [self readPID:[self statusPIDPath]];
    if (existing != 0 && existing != getpid() && [self processIsAlive:existing]) {
        [NSApp terminate:nil];
        return;
    }
    [[NSString stringWithFormat:@"%d", getpid()] writeToFile:[self statusPIDPath]
                                                      atomically:YES
                                                        encoding:NSUTF8StringEncoding
                                                           error:nil];

    [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
    self.statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    self.statusItem.button.font = [NSFont monospacedDigitSystemFontOfSize:12.5 weight:NSFontWeightMedium];
    self.statusItem.button.imagePosition = NSImageLeft;
    self.statusItem.button.toolTip = @"Focus Session";

    NSMenu *menu = [[NSMenu alloc] init];
    menu.autoenablesItems = NO;
    self.stateItem = [[NSMenuItem alloc] initWithTitle:@"Checking…" action:nil keyEquivalent:@""];
    self.modelItem = [[NSMenuItem alloc] initWithTitle:@"Medium · CPU" action:nil keyEquivalent:@""];
    self.countItem = [[NSMenuItem alloc] initWithTitle:@"Notes: 0" action:nil keyEquivalent:@""];
    self.latestItem = [[NSMenuItem alloc] initWithTitle:@"Latest: Waiting" action:nil keyEquivalent:@""];
    self.stopItem = [[NSMenuItem alloc] initWithTitle:@"End Session" action:@selector(stopRecording:) keyEquivalent:@""];

    self.stateItem.enabled = YES;
    self.modelItem.enabled = YES;
    self.countItem.enabled = YES;
    self.latestItem.enabled = YES;
    self.stopItem.target = self;

    self.stateItem.image = [self symbol:@"figure.mind.and.body" fallback:@"person.fill"];
    self.modelItem.image = [self symbol:@"cpu" fallback:@"gearshape"];
    self.countItem.image = [self symbol:@"note.text" fallback:@"doc.text"];
    self.latestItem.image = [self symbol:@"text.quote" fallback:@"quote.bubble"];
    self.stopItem.image = [self symbol:@"pause.circle" fallback:@"stop.circle"];

    [menu addItem:self.stateItem];
    [menu addItem:self.modelItem];
    [menu addItem:self.countItem];
    [menu addItem:self.latestItem];
    [menu addItem:[NSMenuItem separatorItem]];

    NSMenuItem *openToday = [[NSMenuItem alloc] initWithTitle:@"Open Today's Notes" action:@selector(openTodayRecord:) keyEquivalent:@"o"];
    openToday.target = self;
    openToday.image = [self symbol:@"calendar" fallback:@"doc.text"];
    [menu addItem:openToday];

    NSMenuItem *openFolder = [[NSMenuItem alloc] initWithTitle:@"Open Notes Folder" action:@selector(openRecordFolder:) keyEquivalent:@""];
    openFolder.target = self;
    openFolder.image = [self symbol:@"folder" fallback:@"doc"];
    [menu addItem:openFolder];

    NSMenuItem *openSchedule = [[NSMenuItem alloc] initWithTitle:@"Schedule Settings" action:@selector(openSchedule:) keyEquivalent:@","];
    openSchedule.target = self;
    openSchedule.image = [self symbol:@"clock.badge" fallback:@"clock"];
    [menu addItem:openSchedule];

    [menu addItem:self.stopItem];
    [menu addItem:[NSMenuItem separatorItem]];

    NSMenuItem *quit = [[NSMenuItem alloc] initWithTitle:@"Hide Status" action:@selector(quitStatusApp:) keyEquivalent:@"q"];
    quit.target = self;
    quit.image = [self symbol:@"eye.slash" fallback:@"xmark.circle"];
    [menu addItem:quit];

    self.statusItem.menu = menu;
    [self updateStatus:nil];
    self.timer = [NSTimer scheduledTimerWithTimeInterval:1.0
                                                  target:self
                                                selector:@selector(updateStatus:)
                                                userInfo:nil
                                                 repeats:YES];
}

- (void)applicationWillTerminate:(NSNotification *)notification {
    [self.timer invalidate];
    if ([self readPID:[self statusPIDPath]] == getpid()) {
        [[NSFileManager defaultManager] removeItemAtPath:[self statusPIDPath] error:nil];
    }
}

- (NSString *)todayRecordPath {
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    formatter.dateFormat = @"yyyy-MM-dd";
    NSString *name = [NSString stringWithFormat:@"%@.md", [formatter stringFromDate:[NSDate date]]];
    return [[self recordsDirectory] stringByAppendingPathComponent:name];
}

- (NSDictionary *)transcriptSummary {
    NSString *content = [NSString stringWithContentsOfFile:[self todayRecordPath] encoding:NSUTF8StringEncoding error:nil];
    if (!content) return @{ @"count": @0 };

    NSArray<NSString *> *lines = [content componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    NSInteger count = 0;
    NSInteger latestHeading = NSNotFound;
    NSString *latestRange = @"";
    for (NSInteger i = 0; i < (NSInteger)lines.count; i++) {
        if ([lines[i] hasPrefix:@"## "]) {
            count++;
            latestHeading = i;
            latestRange = [lines[i] substringFromIndex:3];
        }
    }
    if (latestHeading == NSNotFound) return @{ @"count": @0 };

    NSMutableArray<NSString *> *textLines = [NSMutableArray array];
    for (NSInteger i = latestHeading + 1; i < (NSInteger)lines.count; i++) {
        NSString *line = lines[i];
        if ([line hasPrefix:@"<!--"]) break;
        if (line.length > 0) [textLines addObject:line];
    }
    NSString *text = [textLines componentsJoinedByString:@" "];
    NSArray<NSString *> *range = [latestRange componentsSeparatedByString:@"–"];
    NSDictionary *latest = @{
        @"text": text ?: @"",
        @"start_local": range.count > 0 ? range[0] : @"",
        @"end_local": range.count > 1 ? range[1] : @""
    };
    return @{ @"count": @(count), @"latest": latest };
}

- (NSTimeInterval)recordingElapsed:(BOOL *)running {
    pid_t pid = [self readPID:[self recorderPIDPath]];
    if (![self processIsAlive:pid]) {
        *running = NO;
        return 0;
    }
    *running = YES;
    NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:[self recorderPIDPath] error:nil];
    NSDate *started = attributes[NSFileModificationDate] ?: [NSDate date];
    return MAX(0, [[NSDate date] timeIntervalSinceDate:started]);
}

- (NSString *)formatElapsed:(NSTimeInterval)seconds {
    NSInteger total = MAX(0, (NSInteger)seconds);
    return [NSString stringWithFormat:@"%02ld:%02ld", (long)(total / 60), (long)(total % 60)];
}

- (NSString *)clipped:(NSString *)text {
    if (text.length <= 42) return text;
    return [[text substringToIndex:42] stringByAppendingString:@"…"];
}

- (void)updateStatus:(NSTimer *)timer {
    BOOL running = NO;
    NSTimeInterval elapsed = [self recordingElapsed:&running];
    NSDictionary *summary = [self transcriptSummary];
    NSStatusBarButton *button = self.statusItem.button;

    if (running) {
        button.image = [self symbol:@"figure.mind.and.body" fallback:@"person.fill"];
        button.contentTintColor = nil;
        button.wantsLayer = NO;
        button.title = [NSString stringWithFormat:@" %@", [self formatElapsed:elapsed]];
        self.stateItem.title = [NSString stringWithFormat:@"Session · %@", [self formatElapsed:elapsed]];
        self.stopItem.enabled = YES;
    } else {
        button.image = [self symbol:@"figure.mind.and.body" fallback:@"person"];
        button.contentTintColor = nil;
        button.wantsLayer = NO;
        button.title = @" --:--";
        self.stateItem.title = @"Session · Idle";
        self.stopItem.enabled = NO;
    }

    self.modelItem.title = @"Medium · CPU";
    self.countItem.title = [NSString stringWithFormat:@"Notes: %@", summary[@"count"]];
    NSDictionary *latest = summary[@"latest"];
    NSString *text = latest[@"text"];
    if (text.length > 0) {
        self.latestItem.title = [NSString stringWithFormat:@"Latest: %@", [self clipped:text]];
        self.latestItem.toolTip = [NSString stringWithFormat:@"%@ - %@\n%@",
                                    latest[@"start_local"] ?: @"",
                                    latest[@"end_local"] ?: @"",
                                    text];
    } else {
        self.latestItem.title = @"Latest: Waiting";
        self.latestItem.toolTip = nil;
    }
}

- (void)openTodayRecord:(id)sender {
    NSString *path = [self todayRecordPath];
    if (![[NSFileManager defaultManager] fileExistsAtPath:path]) {
        [[NSWorkspace sharedWorkspace] openURL:[NSURL fileURLWithPath:[self recordsDirectory]]];
        return;
    }
    NSTask *task = [[NSTask alloc] init];
    task.executableURL = [NSURL fileURLWithPath:@"/usr/bin/open"];
    task.arguments = @[@"-a", @"TextEdit", path];
    [task launchAndReturnError:nil];
}

- (void)openRecordFolder:(id)sender {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL fileURLWithPath:[self recordsDirectory]]];
}

- (void)openSchedule:(id)sender {
    NSTask *task = [[NSTask alloc] init];
    task.executableURL = [NSURL fileURLWithPath:@"/usr/bin/open"];
    task.arguments = @[@"-a", @"TextEdit", [self schedulePath]];
    [task launchAndReturnError:nil];
}

- (void)stopRecording:(id)sender {
    NSTask *task = [[NSTask alloc] init];
    task.executableURL = [NSURL fileURLWithPath:@"/bin/zsh"];
    task.arguments = @[[self.rootPath stringByAppendingPathComponent:@"scripts/stop.sh"]];
    task.standardOutput = [NSFileHandle fileHandleWithNullDevice];
    task.standardError = [NSFileHandle fileHandleWithNullDevice];
    [task launchAndReturnError:nil];
}

- (void)quitStatusApp:(id)sender {
    [NSApp terminate:nil];
}

@end

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        NSApplication *app = [NSApplication sharedApplication];
        AppDelegate *delegate = [[AppDelegate alloc] init];
        app.delegate = delegate;
        [app run];
    }
    return 0;
}
