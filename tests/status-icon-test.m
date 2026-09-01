#import "../src/ListenoteStatusIcon.h"

static NSBitmapImageRep *RenderIcon(NSImage *image, NSInteger scale, BOOL dark) {
    NSInteger pixels = 18 * scale;
    NSBitmapImageRep *bitmap = [[NSBitmapImageRep alloc]
        initWithBitmapDataPlanes:NULL pixelsWide:pixels pixelsHigh:pixels
        bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO
        colorSpaceName:NSDeviceRGBColorSpace bytesPerRow:0 bitsPerPixel:0];
    [NSGraphicsContext saveGraphicsState];
    [NSGraphicsContext setCurrentContext:[NSGraphicsContext graphicsContextWithBitmapImageRep:bitmap]];
    NSRect bounds = NSMakeRect(0, 0, pixels, pixels);
    [image drawInRect:bounds fromRect:NSZeroRect operation:NSCompositingOperationCopy fraction:1];
    if (dark) {
        [[NSColor whiteColor] setFill];
        NSRectFillUsingOperation(bounds, NSCompositingOperationSourceIn);
    }
    [NSGraphicsContext restoreGraphicsState];
    return bitmap;
}

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        NSImage *recording = ListenoteStatusIcon(YES);
        NSImage *paused = ListenoteStatusIcon(NO);
        NSCAssert(recording.isTemplate && paused.isTemplate, @"Both states must be template images");
        NSCAssert(NSEqualSizes(recording.size, NSMakeSize(18, 18)), @"Stable menu-bar size");
        NSCAssert(NSEqualSizes(recording.size, paused.size), @"State change must not resize icon");
        NSCAssert(![recording.accessibilityDescription isEqual:paused.accessibilityDescription],
                  @"States must have distinct accessible descriptions");
        for (NSInteger scale = 1; scale <= 2; scale++) {
            NSData *stateData[2];
            for (NSInteger state = 0; state < 2; state++) {
                for (NSInteger dark = 0; dark < 2; dark++) {
                    NSBitmapImageRep *bitmap = RenderIcon(state == 0 ? recording : paused, scale, dark);
                    NSInteger ink = 0;
                    NSInteger transparent = 0;
                    for (NSInteger y = 0; y < bitmap.pixelsHigh; y++) {
                        for (NSInteger x = 0; x < bitmap.pixelsWide; x++) {
                            CGFloat alpha = [[bitmap colorAtX:x y:y] alphaComponent];
                            if (alpha > 0.1) ink++;
                            else transparent++;
                        }
                    }
                    NSCAssert(ink > 20 * scale * scale, @"Icon must contain visible artwork");
                    NSCAssert(transparent > 30 * scale * scale, @"Icon must retain negative space");
                    NSData *png = [bitmap representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
                    if (!dark) stateData[state] = png;
                    if (argc > 1) {
                        NSString *name = [NSString stringWithFormat:@"%@-%@@%ldx.png",
                            state == 0 ? @"recording" : @"paused", dark ? @"dark" : @"light", (long)scale];
                        NSString *path = [[NSString stringWithUTF8String:argv[1]] stringByAppendingPathComponent:name];
                        NSCAssert([png writeToFile:path atomically:YES], @"Save preview");
                    }
                }
            }
            NSCAssert(![stateData[0] isEqualToData:stateData[1]], @"Recording and pause must differ");
        }
        if (argc > 1) {
            NSBitmapImageRep *sheet = [[NSBitmapImageRep alloc]
                initWithBitmapDataPlanes:NULL pixelsWide:540 pixelsHigh:220
                bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO
                colorSpaceName:NSDeviceRGBColorSpace bytesPerRow:0 bitsPerPixel:0];
            [NSGraphicsContext saveGraphicsState];
            [NSGraphicsContext setCurrentContext:[NSGraphicsContext graphicsContextWithBitmapImageRep:sheet]];
            [[NSColor whiteColor] setFill];
            NSRectFill(NSMakeRect(0, 0, 540, 220));
            for (NSInteger state = 0; state < 2; state++) {
                NSImage *icon = state == 0 ? recording : paused;
                CGFloat x = state * 270;
                [icon drawInRect:NSMakeRect(x + 90, 80, 90, 90)];
                [(state == 0 ? @"Recording" : @"Paused") drawAtPoint:NSMakePoint(x + 98, 190)
                    withAttributes:@{NSFontAttributeName: [NSFont systemFontOfSize:14],
                                     NSForegroundColorAttributeName: [NSColor blackColor]}];
                [icon drawInRect:NSMakeRect(x + 88, 30, 18, 18)];
                [[NSColor blackColor] setFill];
                NSRectFill(NSMakeRect(x + 145, 25, 60, 28));
                [RenderIcon(icon, 2, YES) drawInRect:NSMakeRect(x + 166, 30, 18, 18)];
            }
            [NSGraphicsContext restoreGraphicsState];
            NSString *path = [[NSString stringWithUTF8String:argv[1]] stringByAppendingPathComponent:@"preview.png"];
            NSData *png = [sheet representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
            NSCAssert([png writeToFile:path atomically:YES], @"Save preview sheet");
        }
        NSLog(@"Status icons passed: two states, two scales, light/dark tint.");
    }
    return 0;
}
