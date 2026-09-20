#import <Foundation/Foundation.h>

int main(void) {
    @autoreleasepool {
        NSData *data = [[NSFileHandle fileHandleWithStandardInput] readDataToEndOfFile];
        NSMutableString *text = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] mutableCopy];
        if (!text) return 1;
        CFStringTransform((__bridge CFMutableStringRef)text, NULL, CFSTR("Traditional-Simplified"), false);
        NSData *output = [text dataUsingEncoding:NSUTF8StringEncoding];
        [[NSFileHandle fileHandleWithStandardOutput] writeData:output];
    }
    return 0;
}
