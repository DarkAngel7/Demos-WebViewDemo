//
//  AppDelegate.m
//  WebViewDemo
//
//  Created by DarkAngel on 16/9/1.
//  Copyright © 2016年 暗の天使. All rights reserved.
//

#import "AppDelegate.h"
#import "Constants.h"

@interface DAURLProtocol : NSURLProtocol

@end

@implementation DAURLProtocol

+ (BOOL)canInitWithRequest:(NSURLRequest *)request
{
    //处理过不再处理
    if ([NSURLProtocol propertyForKey:DAURLProtocolHandledKey inRequest:request]) {
        return NO;
    }
    //根据request header中的 accept 来判断是否加载图片
    /*
    {
     "Accept" = "image/png,image/svg+xml";
     "User-Agent" = "Mozilla/5.0 (iPhone; CPU iPhone OS 10_3 like Mac OS X) AppleWebKit/603.1.30 (KHTML, like Gecko) Mobile/14E269 WebViewDemo/1.0.0";
    }
     */
    NSDictionary *headers = request.allHTTPHeaderFields;
    NSString *accept = headers[@"Accept"];
    if (accept.length >= @"image".length && [accept rangeOfString:@"image"].location != NSNotFound) {
        return YES;
    }
    return NO;
}

+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request
{
    return request;
}

+ (BOOL)requestIsCacheEquivalent:(NSURLRequest *)a toRequest:(NSURLRequest *)b
{
    return [super requestIsCacheEquivalent:a toRequest:b];
}

- (void)startLoading
{
    NSMutableURLRequest *mutableReqeust = [[self request] mutableCopy];
    //标记，已经处理过
    [NSURLProtocol setProperty:@(YES) forKey:DAURLProtocolHandledKey inRequest:mutableReqeust];
    
    //NSURLProtocol拦截了图片请求
    NSLog(@"NSURLProtocol拦截了图片请求：%@", mutableReqeust);
    
    [self.client URLProtocolDidFinishLoading:self];
//
//    //这里NSURLProtocolClient的相关方法都要调用
//    //比如 [self.client URLProtocol:self didLoadData:data];
//
//    //下面是一些伪代码
//    //开始下载图片
//    [ImageDownloader startLoadImage:mutableReqeust completion:^(UIImage *image, NSData *data, NSError *error){
//        if (error) {
//            [self.client URLProtocol:self didFailWithError:error];
//        } else {
//            [self.client URLProtocol:self didLoadData:data];
//
//        }
//    }];
}

- (void)stopLoading
{
//    [ImageDownloader cancel];
}

@end

@interface AppDelegate ()

@end

@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // Override point for customization after application launch.
    
    //设置自定义UserAgent
    [self setCustomUserAgent];
    
    //拦截
//    [NSURLProtocol registerClass:[DAURLProtocol class]];
    
    return YES;
}

- (void)setCustomUserAgent
{
    //get the original user-agent of webview
    UIWebView *webView = [[UIWebView alloc] initWithFrame:CGRectZero];
    NSString *oldAgent = [webView stringByEvaluatingJavaScriptFromString:@"navigator.userAgent"];
    //add my info to the new agent
    NSString *newAgent = [oldAgent stringByAppendingFormat:@" %@", @"WebViewDemo/1.0.0"];
    //regist the new agent
    NSDictionary *dictionnary = [[NSDictionary alloc] initWithObjectsAndKeys:newAgent, @"UserAgent", newAgent, @"User-Agent", nil];
    [[NSUserDefaults standardUserDefaults] registerDefaults:dictionnary];
}

- (void)applicationWillResignActive:(UIApplication *)application {
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application {
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

@end
