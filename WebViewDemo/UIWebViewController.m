//
//  UIWebViewController.m
//  WebViewDemo
//
//  Created by DarkAngel on 16/9/1.
//  Copyright © 2016年 暗の天使. All rights reserved.
//

#import "UIWebViewController.h"
#import "Constants.h"
#import <JavaScriptCore/JavaScriptCore.h>

@interface UIWebViewController () <UIWebViewDelegate>

@property (weak, nonatomic) IBOutlet UIWebView *webView;

@property (nonatomic, strong) JSContext *jsContext;

@end

@implementation UIWebViewController

#pragma mark - Life Cycle

- (void)viewDidLoad {
    [super viewDidLoad];

    // Do any additional setup after loading the view.
    [self.webView loadRequest:[NSURLRequest requestWithURL:[NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"test" ofType:@"html"]]]];
    //加载百度，可以调试一下，看看Cookie
    //[self.webView loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:@"http://baidu.com"]]];
    //点击返回，可以后退
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"返回" style:UIBarButtonItemStylePlain target:self.webView action:@selector(goBack)];
}

#pragma mark - UIWebViewDelegate

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType
{
    //标准的URL包含scheme、host、port、path、query、fragment等
    NSURL *URL = request.URL;
    if ([URL.scheme isEqualToString:DAWebViewDemoScheme]) {
        if ([URL.host isEqualToString:DAWebViewDemoHostSmsLogin]) {
            NSLog(@"短信验证码登录，参数为 %@", URL.query);
            return NO;
        }
    }
    return YES;
}

- (void)webViewDidStartLoad:(UIWebView *)webView
{
    
}

- (void)webViewDidFinishLoad:(UIWebView *)webView
{
    self.navigationItem.title = [self.title stringByAppendingString:[webView stringByEvaluatingJavaScriptFromString:@"document.title"]];
    [self convertJSFunctionsToOCMethods];
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error
{
 
}

#pragma mark - 将JS的函数转换成OC的方法

- (void)convertJSFunctionsToOCMethods
{
    //获取该UIWebview的javascript上下文
    //self持有jsContext
    //@property (nonatomic, strong) JSContext *jsContext;
    self.jsContext = [self.webView valueForKeyPath:@"documentView.webView.mainFrame.javaScriptContext"];
    
    //JSContext oc调用js
    //JSValue *value = [self.jsContext evaluateScript:@"document.title"];
    
    //js调用iOS
    //其中share就是js的方法名称，赋给是一个block 里面是iOS代码
    //此方法最终将打印出所有接收到的参数，js参数是不固定的
    self.jsContext[@"share"] = ^() {
        NSArray *args = [JSContext currentArguments];//获取到share里的所有参数
        //args中的元素是JSValue，需要转成OC的对象
        NSMutableArray *messages = [NSMutableArray array];
        for (JSValue *obj in args) {
            [messages addObject:[obj toObject]];
        }
        NSLog(@"点击分享js传回的参数：\n%@", messages);
    };
    
    /*
    //两数相加
    self.jsContext[@"testAddMethod"] = ^NSInteger(NSInteger a, NSInteger b) {
        return a + b;
    };
     */
    
    /*
    //两数相乘
    self.jsContext[@"testAddMethod"] = ^NSInteger(NSInteger a, NSInteger b) {
        return a * b;
    };
     */
    
    //调用方法的本来实现，给原结果乘以10
    JSValue *value = self.jsContext[@"testAddMethod"];
    self.jsContext[@"testAddMethod"] = ^NSInteger(NSInteger a, NSInteger b) {
        JSValue *resultValue = [value callWithArguments:[JSContext currentArguments]];
        return resultValue.toInt32 * 10;
    };
    
    //异步回调
    self.jsContext[@"shareNew"] = ^(JSValue *shareData) {
        NSLog(@"%@", [shareData toObject]);
        JSValue *resultFunction = [shareData valueForProperty:@"result"];
        //回调block
        void (^result)(BOOL) = ^(BOOL isSuccess) {
            [resultFunction callWithArguments:@[@(isSuccess)]];
        };
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            NSLog(@"回调分享成功");
            result(YES);
        });
    };
    
    //先注入给图片添加点击事件的js
    //防止频繁IO操作，造成性能影响
    static NSString *jsSource;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        jsSource = [NSString stringWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"ImgAddClickEvent" ofType:@"js"] encoding:NSUTF8StringEncoding error:nil];
    });
    [self.jsContext evaluateScript:jsSource];
    //替换回调方法
    self.jsContext[@"h5ImageDidClick"] = ^(NSDictionary *imgInfo) {
        NSLog(@"UIWebView点击了html上的图片，信息是：%@", imgInfo);
    };
}


/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
