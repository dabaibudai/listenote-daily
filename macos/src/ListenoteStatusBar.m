#import <Cocoa/Cocoa.h>
#import <errno.h>
#import <signal.h>
#import "ListenoteStatusIcon.h"

@interface AppDelegate : NSObject <NSApplicationDelegate>
@property(nonatomic, strong) NSStatusItem *statusItem;
@property(nonatomic, strong) NSImage *recordingStatusImage;
@property(nonatomic, strong) NSImage *pausedStatusImage;
@property(nonatomic, strong) NSMenuItem *stateItem;
@property(nonatomic, strong) NSMenuItem *modelItem;
@property(nonatomic, strong) NSMenuItem *countItem;
@property(nonatomic, strong) NSMenuItem *latestItem;
@property(nonatomic, strong) NSMenuItem *recordingItem;
@property(nonatomic, strong) NSMenuItem *scheduleItem;
@property(nonatomic, strong) NSTimer *timer;
@property(nonatomic, strong) NSString *rootPath;
@property(nonatomic, strong) NSWindow *scheduleWindow;
@property(nonatomic, strong) NSButton *scheduleEnabledButton;
@property(nonatomic, strong) NSArray<NSButton *> *dayButtons;
@property(nonatomic, strong) NSView *windowRowsView;
@property(nonatomic, strong) NSMutableArray<NSDictionary *> *windowRows;
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
    return [self.rootPath stringByAppendingPathComponent:@"records/listenote-daily.pid"];
}

- (NSString *)statusPIDPath {
    return [self.rootPath stringByAppendingPathComponent:@"records/listenote-status.pid"];
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
    self.rootPath = [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Application Support/Listenote Daily"];

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
    self.statusItem.button.toolTip = @"Listenote Daily 本地转录";

    NSMenu *menu = [[NSMenu alloc] init];
    menu.autoenablesItems = NO;
    self.stateItem = [[NSMenuItem alloc] initWithTitle:@"正在检查…" action:nil keyEquivalent:@""];
    self.modelItem = [[NSMenuItem alloc] initWithTitle:@"Medium · CPU" action:nil keyEquivalent:@""];
    self.countItem = [[NSMenuItem alloc] initWithTitle:@"今日片段：0" action:nil keyEquivalent:@""];
    self.latestItem = [[NSMenuItem alloc] initWithTitle:@"最近转录：等待内容" action:nil keyEquivalent:@""];
    self.recordingItem = [[NSMenuItem alloc] initWithTitle:@"录音" action:@selector(toggleRecording:) keyEquivalent:@"r"];
    self.scheduleItem = [[NSMenuItem alloc] initWithTitle:@"日程设置…" action:@selector(openSchedule:) keyEquivalent:@","];

    self.stateItem.enabled = YES;
    self.modelItem.enabled = YES;
    self.countItem.enabled = YES;
    self.latestItem.enabled = YES;
    self.recordingItem.target = self;
    self.scheduleItem.target = self;

    self.recordingStatusImage = ListenoteStatusIcon(YES);
    self.pausedStatusImage = ListenoteStatusIcon(NO);
    self.stateItem.image = self.pausedStatusImage;
    self.modelItem.image = [self symbol:@"cpu" fallback:@"gearshape"];
    self.countItem.image = [self symbol:@"note.text" fallback:@"doc.text"];
    self.latestItem.image = [self symbol:@"text.quote" fallback:@"quote.bubble"];
    self.recordingItem.image = [self symbol:@"waveform" fallback:@"mic"];
    self.scheduleItem.image = [self symbol:@"calendar.badge.clock" fallback:@"clock"];

    [menu addItem:self.stateItem];
    [menu addItem:self.modelItem];
    [menu addItem:self.countItem];
    [menu addItem:self.latestItem];
    [menu addItem:[NSMenuItem separatorItem]];
    [menu addItem:self.recordingItem];
    [menu addItem:self.scheduleItem];
    [menu addItem:[NSMenuItem separatorItem]];

    NSMenuItem *openToday = [[NSMenuItem alloc] initWithTitle:@"打开今日记录" action:@selector(openTodayRecord:) keyEquivalent:@"o"];
    openToday.target = self;
    openToday.image = [self symbol:@"calendar" fallback:@"doc.text"];
    [menu addItem:openToday];

    NSMenuItem *openFolder = [[NSMenuItem alloc] initWithTitle:@"打开记录文件夹" action:@selector(openRecordFolder:) keyEquivalent:@""];
    openFolder.target = self;
    openFolder.image = [self symbol:@"folder" fallback:@"doc"];
    [menu addItem:openFolder];

    NSMenuItem *quit = [[NSMenuItem alloc] initWithTitle:@"隐藏状态栏图标" action:@selector(quitStatusApp:) keyEquivalent:@"q"];
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

- (NSDictionary<NSString *, NSString *> *)configuration {
    NSString *content = [NSString stringWithContentsOfFile:[self schedulePath]
                                                   encoding:NSUTF8StringEncoding
                                                      error:nil];
    NSMutableDictionary *values = [NSMutableDictionary dictionary];
    for (NSString *rawLine in [content componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]]) {
        NSString *line = [rawLine stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        if (line.length == 0 || [line hasPrefix:@"#"]) continue;
        NSRange separator = [line rangeOfString:@"="];
        if (separator.location == NSNotFound) continue;
        values[[line substringToIndex:separator.location]] = [line substringFromIndex:separator.location + 1];
    }
    return values;
}

- (NSString *)modelTitle:(NSString *)model {
    if ([model isEqualToString:@"large-v3-turbo"]) return @"Large v3 Turbo · CPU";
    if ([model isEqualToString:@"large-v3"]) return @"Large v3 · CPU";
    if ([model isEqualToString:@"medium"]) return @"Medium · CPU";
    return [NSString stringWithFormat:@"%@ · CPU", model.length ? model : @"Whisper"];
}

- (NSString *)scheduleTitle:(NSDictionary *)configuration {
    if (![configuration[@"ENABLED"] isEqualToString:@"1"]) return @"日程 · 已关闭…";
    NSArray *days = [configuration[@"DAYS"] componentsSeparatedByString:@","];
    NSArray *windows = [configuration[@"WINDOWS"] componentsSeparatedByString:@","];
    NSString *dayText = days.count == 7 ? @"每天" : [NSString stringWithFormat:@"每周%ld天", (long)days.count];
    return [NSString stringWithFormat:@"日程 · %@ · %ld个时段…", dayText, (long)windows.count];
}

- (void)updateStatus:(NSTimer *)timer {
    BOOL running = NO;
    NSTimeInterval elapsed = [self recordingElapsed:&running];
    NSDictionary *summary = [self transcriptSummary];
    NSStatusBarButton *button = self.statusItem.button;
    NSImage *statusImage = running ? self.recordingStatusImage : self.pausedStatusImage;
    button.image = statusImage;
    self.stateItem.image = statusImage;

    if (running) {
        button.contentTintColor = nil;
        button.wantsLayer = NO;
        button.title = [NSString stringWithFormat:@" %@", [self formatElapsed:elapsed]];
        self.stateItem.title = [NSString stringWithFormat:@"录音中 · %@", [self formatElapsed:elapsed]];
        self.recordingItem.state = NSControlStateValueOn;
        self.recordingItem.toolTip = @"暂停录音；到下一个日程时段会自动恢复";
    } else {
        button.contentTintColor = nil;
        button.wantsLayer = NO;
        button.title = @" --:--";
        self.stateItem.title = @"录音 · 已暂停";
        self.recordingItem.state = NSControlStateValueOff;
        self.recordingItem.toolTip = @"立即开始录音";
    }

    self.recordingItem.enabled = YES;
    NSDictionary *configuration = [self configuration];
    self.modelItem.title = [self modelTitle:configuration[@"MODEL_SIZE"]];
    self.scheduleItem.title = [self scheduleTitle:configuration];
    self.countItem.title = [NSString stringWithFormat:@"今日片段：%@", summary[@"count"]];
    NSDictionary *latest = summary[@"latest"];
    NSString *text = latest[@"text"];
    if (text.length > 0) {
        self.latestItem.title = [NSString stringWithFormat:@"最近转录：%@", [self clipped:text]];
        self.latestItem.toolTip = [NSString stringWithFormat:@"%@ - %@\n%@",
                                    latest[@"start_local"] ?: @"",
                                    latest[@"end_local"] ?: @"",
                                    text];
    } else {
        self.latestItem.title = @"最近转录：等待内容";
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

- (NSDate *)dateForTime:(NSString *)time {
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    formatter.dateFormat = @"HH:mm";
    return [formatter dateFromString:time] ?: [formatter dateFromString:@"09:00"];
}

- (NSString *)timeForDate:(NSDate *)date {
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    formatter.dateFormat = @"HH:mm";
    return [formatter stringFromDate:date];
}

- (NSTextField *)labelWithString:(NSString *)string frame:(NSRect)frame {
    NSTextField *label = [[NSTextField alloc] initWithFrame:frame];
    label.stringValue = string;
    label.editable = NO;
    label.selectable = NO;
    label.bordered = NO;
    label.drawsBackground = NO;
    return label;
}

- (void)layoutWindowRows {
    NSInteger index = 0;
    for (NSDictionary *row in self.windowRows) {
        NSView *rowView = row[@"view"];
        rowView.frame = NSMakeRect(0, 150 - index * 40, 472, 30);
        index++;
    }
}

- (void)addWindowFrom:(NSString *)start to:(NSString *)end {
    if (self.windowRows.count >= 4) return;
    NSView *row = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 472, 30)];
    NSTextField *number = [self labelWithString:[NSString stringWithFormat:@"%ld", (long)self.windowRows.count + 1]
                                           frame:NSMakeRect(0, 5, 22, 20)];
    number.textColor = [NSColor secondaryLabelColor];

    NSDatePicker *startPicker = [[NSDatePicker alloc] initWithFrame:NSMakeRect(28, 1, 120, 28)];
    startPicker.datePickerStyle = NSDatePickerStyleTextFieldAndStepper;
    startPicker.datePickerElements = NSDatePickerElementFlagHourMinute;
    startPicker.dateValue = [self dateForTime:start];
    NSTextField *toLabel = [self labelWithString:@"至" frame:NSMakeRect(160, 5, 24, 20)];
    toLabel.alignment = NSTextAlignmentCenter;
    NSDatePicker *endPicker = [[NSDatePicker alloc] initWithFrame:NSMakeRect(196, 1, 120, 28)];
    endPicker.datePickerStyle = NSDatePickerStyleTextFieldAndStepper;
    endPicker.datePickerElements = NSDatePickerElementFlagHourMinute;
    endPicker.dateValue = [self dateForTime:end];
    NSButton *remove = [NSButton buttonWithTitle:@"−" target:self action:@selector(removeWindow:)];
    remove.frame = NSMakeRect(330, 1, 30, 28);
    remove.bezelStyle = NSBezelStyleCircular;

    [row addSubview:number];
    [row addSubview:startPicker];
    [row addSubview:toLabel];
    [row addSubview:endPicker];
    [row addSubview:remove];
    [self.windowRowsView addSubview:row];
    [self.windowRows addObject:@{ @"view": row, @"start": startPicker, @"end": endPicker, @"remove": remove }];
    [self layoutWindowRows];
}

- (void)addWindow:(id)sender {
    [self addWindowFrom:@"09:00" to:@"18:00"];
}

- (void)removeWindow:(NSButton *)sender {
    if (self.windowRows.count == 1) {
        NSBeep();
        return;
    }
    NSDictionary *matched = nil;
    for (NSDictionary *row in self.windowRows) {
        if (row[@"remove"] == sender) matched = row;
    }
    if (!matched) return;
    [matched[@"view"] removeFromSuperview];
    [self.windowRows removeObject:matched];
    NSInteger index = 1;
    for (NSDictionary *row in self.windowRows) {
        NSArray *subviews = [row[@"view"] subviews];
        NSTextField *number = subviews.firstObject;
        number.stringValue = [NSString stringWithFormat:@"%ld", (long)index++];
    }
    [self layoutWindowRows];
}

- (void)showScheduleError:(NSString *)message {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"请检查日程设置";
    alert.informativeText = message;
    alert.alertStyle = NSAlertStyleWarning;
    [alert beginSheetModalForWindow:self.scheduleWindow completionHandler:nil];
}

- (void)saveSchedule:(id)sender {
    NSMutableArray<NSString *> *days = [NSMutableArray array];
    for (NSInteger i = 0; i < (NSInteger)self.dayButtons.count; i++) {
        if (self.dayButtons[i].state == NSControlStateValueOn) {
            [days addObject:[NSString stringWithFormat:@"%ld", (long)i + 1]];
        }
    }
    if (self.scheduleEnabledButton.state == NSControlStateValueOn && days.count == 0) {
        [self showScheduleError:@"请至少选择一天。"];
        return;
    }

    NSMutableArray<NSDictionary *> *windows = [NSMutableArray array];
    for (NSDictionary *row in self.windowRows) {
        NSString *start = [self timeForDate:[row[@"start"] dateValue]];
        NSString *end = [self timeForDate:[row[@"end"] dateValue]];
        if ([start compare:end] != NSOrderedAscending) {
            [self showScheduleError:@"每个时间段的开始时间必须早于结束时间。"];
            return;
        }
        [windows addObject:@{ @"start": start, @"end": end }];
    }
    [windows sortUsingComparator:^NSComparisonResult(NSDictionary *left, NSDictionary *right) {
        return [left[@"start"] compare:right[@"start"]];
    }];
    for (NSInteger i = 1; i < (NSInteger)windows.count; i++) {
        if ([windows[i - 1][@"end"] compare:windows[i][@"start"]] == NSOrderedDescending) {
            [self showScheduleError:@"时间段之间不能重叠。"];
            return;
        }
    }

    NSMutableArray<NSString *> *windowValues = [NSMutableArray array];
    for (NSDictionary *window in windows) {
        [windowValues addObject:[NSString stringWithFormat:@"%@-%@", window[@"start"], window[@"end"]]];
    }
    NSDictionary *existing = [self configuration];
    NSString *content = [NSString stringWithFormat:
        @"# 1 = use the schedule; 0 = manual mode only\nENABLED=%@\n\n"
         "# ISO weekday numbers: 1=Monday ... 7=Sunday\nDAYS=%@\n\n"
         "# Local-time windows, comma separated. End time is not included.\nWINDOWS=%@\n\n"
         "# Local multilingual Whisper model and fixed Chinese recognition\nMODEL_SIZE=%@\nLANGUAGE=%@\n",
        self.scheduleEnabledButton.state == NSControlStateValueOn ? @"1" : @"0",
        [days componentsJoinedByString:@","],
        [windowValues componentsJoinedByString:@","],
        existing[@"MODEL_SIZE"] ?: @"large-v3-turbo",
        existing[@"LANGUAGE"] ?: @"zh"];
    NSError *error = nil;
    if (![content writeToFile:[self schedulePath] atomically:YES encoding:NSUTF8StringEncoding error:&error]) {
        [self showScheduleError:error.localizedDescription ?: @"无法保存日程设置。"];
        return;
    }
    [self.scheduleWindow orderOut:nil];
    [self runScriptAtPath:[self.rootPath stringByAppendingPathComponent:@"runtime/schedule-controller.zsh"]];
    [self updateStatus:nil];
}

- (void)openSchedule:(id)sender {
    NSDictionary *configuration = [self configuration];
    self.scheduleWindow = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 520, 430)
                                                      styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable
                                                        backing:NSBackingStoreBuffered
                                                          defer:NO];
    self.scheduleWindow.title = @"录音日程";
    [self.scheduleWindow center];
    NSView *content = self.scheduleWindow.contentView;

    self.scheduleEnabledButton = [NSButton checkboxWithTitle:@"按此日程自动录音"
                                                      target:nil action:nil];
    self.scheduleEnabledButton.frame = NSMakeRect(24, 382, 350, 24);
    self.scheduleEnabledButton.state = [configuration[@"ENABLED"] isEqualToString:@"1"] ? NSControlStateValueOn : NSControlStateValueOff;
    [content addSubview:self.scheduleEnabledButton];

    NSTextField *daysLabel = [self labelWithString:@"重复日期" frame:NSMakeRect(24, 342, 100, 20)];
    daysLabel.font = [NSFont boldSystemFontOfSize:13];
    [content addSubview:daysLabel];
    NSSet *selectedDays = [NSSet setWithArray:[configuration[@"DAYS"] componentsSeparatedByString:@","]];
    NSArray *dayNames = @[@"周一", @"周二", @"周三", @"周四", @"周五", @"周六", @"周日"];
    NSMutableArray *dayButtons = [NSMutableArray array];
    for (NSInteger i = 0; i < 7; i++) {
        NSButton *button = [NSButton checkboxWithTitle:dayNames[i] target:nil action:nil];
        button.frame = NSMakeRect(24 + i * 68, 310, 64, 24);
        button.state = [selectedDays containsObject:[NSString stringWithFormat:@"%ld", (long)i + 1]] ? NSControlStateValueOn : NSControlStateValueOff;
        [content addSubview:button];
        [dayButtons addObject:button];
    }
    self.dayButtons = dayButtons;

    NSTextField *windowsLabel = [self labelWithString:@"时间段" frame:NSMakeRect(24, 272, 160, 20)];
    windowsLabel.font = [NSFont boldSystemFontOfSize:13];
    [content addSubview:windowsLabel];
    self.windowRowsView = [[NSView alloc] initWithFrame:NSMakeRect(24, 92, 472, 180)];
    [content addSubview:self.windowRowsView];
    self.windowRows = [NSMutableArray array];
    for (NSString *window in [configuration[@"WINDOWS"] componentsSeparatedByString:@","]) {
        NSArray *bounds = [window componentsSeparatedByString:@"-"];
        if (bounds.count == 2) [self addWindowFrom:bounds[0] to:bounds[1]];
    }
    if (self.windowRows.count == 0) [self addWindowFrom:@"09:00" to:@"18:00"];

    NSButton *add = [NSButton buttonWithTitle:@"＋ 添加时间段" target:self action:@selector(addWindow:)];
    add.frame = NSMakeRect(24, 58, 150, 28);
    add.bezelStyle = NSBezelStyleRounded;
    [content addSubview:add];
    NSTextField *hint = [self labelWithString:@"保存后立即生效。"
                                        frame:NSMakeRect(24, 24, 270, 20)];
    hint.textColor = [NSColor secondaryLabelColor];
    hint.font = [NSFont systemFontOfSize:11];
    [content addSubview:hint];

    NSButton *cancel = [NSButton buttonWithTitle:@"取消" target:self action:@selector(closeSchedule:)];
    cancel.frame = NSMakeRect(330, 20, 78, 32);
    cancel.keyEquivalent = @"\e";
    [content addSubview:cancel];
    NSButton *save = [NSButton buttonWithTitle:@"保存" target:self action:@selector(saveSchedule:)];
    save.frame = NSMakeRect(414, 20, 82, 32);
    save.keyEquivalent = @"\r";
    [content addSubview:save];

    [NSApp activateIgnoringOtherApps:YES];
    [self.scheduleWindow makeKeyAndOrderFront:nil];
}

- (void)closeSchedule:(id)sender {
    [self.scheduleWindow orderOut:nil];
}

- (void)runScriptAtPath:(NSString *)path {
    NSTask *task = [[NSTask alloc] init];
    task.executableURL = [NSURL fileURLWithPath:@"/bin/zsh"];
    task.arguments = @[path];
    task.standardOutput = [NSFileHandle fileHandleWithNullDevice];
    task.standardError = [NSFileHandle fileHandleWithNullDevice];
    __weak typeof(self) weakSelf = self;
    task.terminationHandler = ^(NSTask *finishedTask) {
        (void)finishedTask;
        dispatch_async(dispatch_get_main_queue(), ^{
            weakSelf.recordingItem.enabled = YES;
            [weakSelf updateStatus:nil];
        });
    };
    NSError *error = nil;
    if (![task launchAndReturnError:&error]) {
        self.recordingItem.enabled = YES;
        NSBeep();
    }
}

- (void)toggleRecording:(id)sender {
    BOOL running = NO;
    [self recordingElapsed:&running];
    self.recordingItem.enabled = NO;
    NSString *script = running ? @"stop.sh" : @"start.sh";
    NSString *path = [[self.rootPath stringByAppendingPathComponent:@"scripts"] stringByAppendingPathComponent:script];
    [self runScriptAtPath:path];
}

- (void)quitStatusApp:(id)sender {
    [NSApp terminate:nil];
}

@end

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        (void)argc;
        (void)argv;
        NSApplication *app = [NSApplication sharedApplication];
        AppDelegate *delegate = [[AppDelegate alloc] init];
        app.delegate = delegate;
        [app run];
    }
    return 0;
}
