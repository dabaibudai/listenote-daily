#import <Cocoa/Cocoa.h>

// Template artwork stays sharp at either display scale and follows menu-bar tint.
static inline NSImage *ListenoteStatusIcon(BOOL recording) {
    NSImage *image = [NSImage imageWithSize:NSMakeSize(18, 18)
                                  flipped:NO
                           drawingHandler:^BOOL(NSRect destination) {
        [NSGraphicsContext saveGraphicsState];
        NSAffineTransform *transform = [NSAffineTransform transform];
        [transform translateXBy:destination.origin.x yBy:destination.origin.y];
        [transform scaleXBy:destination.size.width / 20.0
                       yBy:destination.size.height / 20.0];
        [transform concat];
        [[NSColor blackColor] set];

        NSBezierPath *page = [NSBezierPath bezierPath];
        page.lineWidth = 1.6;
        page.lineJoinStyle = NSLineJoinStyleRound;
        page.lineCapStyle = NSLineCapStyleRound;
        [page moveToPoint:NSMakePoint(5.5, 18.5)];
        [page lineToPoint:NSMakePoint(11.3, 18.5)];
        [page lineToPoint:NSMakePoint(16.5, 13.3)];
        [page lineToPoint:NSMakePoint(16.5, 3.5)];
        [page curveToPoint:NSMakePoint(14.5, 1.5)
            controlPoint1:NSMakePoint(16.5, 2.4)
            controlPoint2:NSMakePoint(15.6, 1.5)];
        [page lineToPoint:NSMakePoint(5.5, 1.5)];
        [page curveToPoint:NSMakePoint(3.5, 3.5)
            controlPoint1:NSMakePoint(4.4, 1.5)
            controlPoint2:NSMakePoint(3.5, 2.4)];
        [page lineToPoint:NSMakePoint(3.5, 16.5)];
        [page curveToPoint:NSMakePoint(5.5, 18.5)
            controlPoint1:NSMakePoint(3.5, 17.6)
            controlPoint2:NSMakePoint(4.4, 18.5)];
        [page closePath];
        [page stroke];

        NSBezierPath *fold = [NSBezierPath bezierPath];
        fold.lineWidth = 1.6;
        fold.lineJoinStyle = NSLineJoinStyleRound;
        fold.lineCapStyle = NSLineCapStyleRound;
        [fold moveToPoint:NSMakePoint(11.3, 18.5)];
        [fold lineToPoint:NSMakePoint(11.3, 14.5)];
        [fold curveToPoint:NSMakePoint(12.5, 13.3)
            controlPoint1:NSMakePoint(11.3, 13.8)
            controlPoint2:NSMakePoint(11.8, 13.3)];
        [fold lineToPoint:NSMakePoint(16.5, 13.3)];
        [fold stroke];

        if (recording) {
            const CGFloat heights[] = { 4.0, 7.0, 4.0 };
            for (NSInteger i = 0; i < 3; i++) {
                NSRect bar = NSMakeRect(6.3 + i * 2.8, 8.0 - heights[i] / 2.0,
                                        1.8, heights[i]);
                [[NSBezierPath bezierPathWithRoundedRect:bar xRadius:0.9 yRadius:0.9] fill];
            }
        } else {
            for (NSInteger i = 0; i < 2; i++) {
                NSRect bar = NSMakeRect(6.8 + i * 4.1, 4.7, 2.3, 6.6);
                [[NSBezierPath bezierPathWithRoundedRect:bar xRadius:1.15 yRadius:1.15] fill];
            }
        }
        [NSGraphicsContext restoreGraphicsState];
        return YES;
    }];
    image.template = YES;
    image.accessibilityDescription = recording ? @"声音笔记，录音中" : @"声音笔记，已暂停";
    return image;
}
