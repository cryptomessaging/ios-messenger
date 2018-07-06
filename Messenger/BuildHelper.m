#import <Foundation/Foundation.h>

NSString *compileDate() {
    return [NSString stringWithUTF8String:__DATE__];
}

NSString *compileTime() {
    return [NSString stringWithUTF8String:__TIME__];
}