#define main listenote_app_main
#import "../src/ListenoteStatusBar.m"
#undef main

@interface ConfigSaveTestDelegate : AppDelegate
@end
@implementation ConfigSaveTestDelegate
- (void)runScriptAtPath:(NSString *)path { (void)path; }
- (void)updateStatus:(NSTimer *)timer { (void)timer; }
@end

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        NSCAssert(argc == 2, @"Expected temporary root path");
        [NSApplication sharedApplication];
        NSString *root = [NSString stringWithUTF8String:argv[1]];
        NSString *configDir = [root stringByAppendingPathComponent:@"config"];
        [[NSFileManager defaultManager] createDirectoryAtPath:configDir
                                  withIntermediateDirectories:YES attributes:nil error:nil];
        NSString *configPath = [configDir stringByAppendingPathComponent:@"schedule.conf"];
        NSString *before = @"ENABLED=1\nDAYS=1,2,3,4,5,6,7\nWINDOWS=09:00-12:00\n"
                           "ASR_BACKEND=qwen\nQWEN_MODEL=moona3k/mlx-qwen3-asr-0.6b-8bit\n"
                           "MODEL_SIZE=large-v3-turbo\nLANGUAGE=zh\n";
        NSCAssert([before writeToFile:configPath atomically:YES encoding:NSUTF8StringEncoding error:nil], @"Seed config");

        ConfigSaveTestDelegate *delegate = [[ConfigSaveTestDelegate alloc] init];
        delegate.rootPath = root;
        delegate.scheduleEnabledButton = [[NSButton alloc] init];
        delegate.scheduleEnabledButton.state = NSControlStateValueOn;
        NSMutableArray *days = [NSMutableArray array];
        for (int i = 0; i < 7; i++) {
            NSButton *button = [[NSButton alloc] init];
            button.state = NSControlStateValueOn;
            [days addObject:button];
        }
        delegate.dayButtons = days;
        NSDatePicker *start = [[NSDatePicker alloc] init];
        NSDatePicker *end = [[NSDatePicker alloc] init];
        start.dateValue = [delegate dateForTime:@"09:00"];
        end.dateValue = [delegate dateForTime:@"12:00"];
        delegate.windowRows = [@[@{@"start": start, @"end": end}] mutableCopy];
        [delegate saveSchedule:nil];

        NSDictionary *saved = [delegate configuration];
        NSCAssert([saved[@"ASR_BACKEND"] isEqualToString:@"qwen"], @"Schedule save must preserve Qwen backend");
        NSCAssert([saved[@"QWEN_MODEL"] isEqualToString:@"moona3k/mlx-qwen3-asr-0.6b-8bit"], @"Schedule save must preserve Qwen model");
        NSCAssert([[delegate modelTitle:saved] isEqualToString:@"Qwen 0.6B · MLX"], @"Menu must show Qwen model");
    }
    return 0;
}
