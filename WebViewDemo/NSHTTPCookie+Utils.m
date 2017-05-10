//
//  NSHTTPCookie+Utils.m
//  WebViewDemo
//
//  Created by DarkAngel on 2017/5/10.
//  Copyright © 2017年 暗の天使. All rights reserved.
//

#import "NSHTTPCookie+Utils.h"

@implementation NSHTTPCookie (Utils)

- (NSString *)da_javascriptString
{
    NSString *string = [NSString stringWithFormat:@"%@=%@;domain=%@;path=%@",
                        self.name,
                        self.value,
                        self.domain,
                        self.path ?: @"/"];
    if (self.secure) {
        string = [string stringByAppendingString:@";secure=true"];
    }
    return string;
}

@end
