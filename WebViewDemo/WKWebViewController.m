//
//  WKWebViewController.m
//  WebViewDemo
//
//  Created by DarkAngel on 16/9/1.
//  Copyright © 2016年 暗の天使. All rights reserved.
//

#import "WKWebViewController.h"
#import <WebKit/WebKit.h>
#import "Constants.h"

@interface WKWebViewController () <
WKUIDelegate,
WKNavigationDelegate,
WKScriptMessageHandler
>

@property (strong, nonatomic) WKWebView *webView;

@end

@implementation WKWebViewController

#pragma mark - Life Cycle

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    WKWebViewConfiguration *configuration = [[WKWebViewConfiguration alloc] init];
    static WKProcessPool *pool;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        //共用一个pool
        pool = [[WKProcessPool alloc] init];
    });
    configuration.processPool = pool;
    
    //自定义脚本等
    WKUserContentController *controller = [[WKUserContentController alloc] init];
    //添加js全局变量
    WKUserScript *script = [[WKUserScript alloc] initWithSource:@"var interesting = 123;" injectionTime:WKUserScriptInjectionTimeAtDocumentStart forMainFrameOnly:NO];
    //页面加载完成立刻回调，获取页面上的所有Cookie
    WKUserScript *cookieScript = [[WKUserScript alloc] initWithSource:@"                window.webkit.messageHandlers.currentCookies.postMessage(document.cookie);" injectionTime:WKUserScriptInjectionTimeAtDocumentEnd forMainFrameOnly:NO];
    //添加自定义的cookie
    WKUserScript *baiduCookieScript = [[WKUserScript alloc] initWithSource:@"                document.cookie = 'DarkAngelCookie=DarkAngel;'" injectionTime:WKUserScriptInjectionTimeAtDocumentStart forMainFrameOnly:NO];
//    WKUserScript *baiduCookieScript = [[WKUserScript alloc] initWithSource:@"func" injectionTime:WKUserScriptInjectionTimeAtDocumentEnd forMainFrameOnly:NO];
    
    //添加脚本
    [controller addUserScript:script];
    [controller addUserScript:cookieScript];
    [controller addUserScript:baiduCookieScript];
    //注册回调
    [controller addScriptMessageHandler:self name:@"share"];
    [controller addScriptMessageHandler:self name:@"currentCookies"];
    [controller addScriptMessageHandler:self name:@"shareNew"];
    
    configuration.userContentController = controller;
    
    self.webView = [[WKWebView alloc] initWithFrame:self.view.bounds configuration:configuration];
    self.webView.allowsBackForwardNavigationGestures = YES;
    self.webView.UIDelegate = self;
    self.webView.navigationDelegate = self;
    
    self.webView.scrollView.contentInset = UIEdgeInsetsMake(64, 0, 49, 0);
    //史诗级神坑，为何如此写呢？参考https://opensource.apple.com/source/WebKit2/WebKit2-7600.1.4.11.10/ChangeLog   以及我博客中的介绍
    [self.webView setValue:[NSValue valueWithUIEdgeInsets:self.webView.scrollView.contentInset] forKey:@"_obscuredInsets"];
    
    [self.view addSubview:self.webView];
    [self.webView loadRequest:[NSURLRequest requestWithURL:[NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"test" ofType:@"html"]]]];
    //可以测试百度还是test
    //[self.webView loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:@"http://baidu.com"]]];
}

#pragma mark - Events

- (IBAction)refresh:(id)sender {
    //刷新
    [self.webView reload];
    /*
    //等同于
    [self.webView evaluateJavaScript:@"location.reload()" completionHandler:^(id _Nullable result, NSError * _Nullable error) {
        
    }];
     */
}

#pragma mark - WKNavigationDelegate

- (void)webView:(WKWebView *)webView didCommitNavigation:(null_unspecified WKNavigation *)navigation
{
    NSLog(@"%@", NSStringFromSelector(_cmd));
}

- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler
{
    NSURL *URL = navigationAction.request.URL;
    if (navigationAction.navigationType == WKNavigationTypeLinkActivated) {
        if ([URL.scheme isEqualToString:DAWebViewDemoScheme]) {
            if ([URL.host isEqualToString:DAWebViewDemoHostSmsLogin]) {
                NSString *param = URL.query;
                NSLog(@"短信验证码登录, 参数为%@", param);
                decisionHandler(WKNavigationActionPolicyCancel);
                return;
            }
        }
    }
    decisionHandler(WKNavigationActionPolicyAllow);
    NSLog(@"%@", NSStringFromSelector(_cmd));
}

- (void)webView:(WKWebView *)webView decidePolicyForNavigationResponse:(WKNavigationResponse *)navigationResponse decisionHandler:(void (^)(WKNavigationResponsePolicy))decisionHandler
{
    NSLog(@"%@", NSStringFromSelector(_cmd));
    decisionHandler(WKNavigationResponsePolicyAllow);
}
 
- (void)webView:(WKWebView *)webView didStartProvisionalNavigation:(null_unspecified WKNavigation *)navigation
{
    [UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
    NSLog(@"%@", NSStringFromSelector(_cmd));
}


- (void)webView:(WKWebView *)webView didReceiveServerRedirectForProvisionalNavigation:(null_unspecified WKNavigation *)navigation
{
    NSLog(@"%@", NSStringFromSelector(_cmd));
}


- (void)webView:(WKWebView *)webView didFinishNavigation:(null_unspecified WKNavigation *)navigation
{
    self.navigationItem.title = [self.title stringByAppendingString:webView.title];  //其实可以kvo来实现动态切换title
    [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
//    self.webView.scrollView.frame = CGRectMake(0, 64, self.webView.scrollView.frame.size.width, self.webView.scrollView.frame.size.height);
//    self.webView.scrollView.contentOffset = CGPointMake(0, -64);

//    [self.webView evaluateJavaScript:@"document.title" completionHandler:^(id _Nullable result, NSError * _Nullable error) {
//        
//    }];
    NSLog(@"%@", NSStringFromSelector(_cmd));
}

- (void)webView:(WKWebView *)webView didFailNavigation:(null_unspecified WKNavigation *)navigation withError:(NSError *)error
{
    [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
    NSLog(@"%@\nerror：%@", NSStringFromSelector(_cmd), error);
}

- (void)webView:(WKWebView *)webView didFailProvisionalNavigation:(null_unspecified WKNavigation *)navigation withError:(NSError *)error
{
    [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
    NSLog(@"%@\nerror：%@", NSStringFromSelector(_cmd), error);
}


#pragma mark - WKScriptMessageHandler

- (void)userContentController:(WKUserContentController *)userContentController didReceiveScriptMessage:(WKScriptMessage *)message
{
    if ([message.name isEqualToString:@"share"]) {
        id body = message.body;
        NSLog(@"share分享的内容为：%@", body);
    }
    else if ([message.name isEqualToString:@"shareNew"]) {
        id body = message.body;
        NSLog(@"shareNew分享的数据为： %@", body);
    }
    else if ([message.name isEqualToString:@"currentCookies"]) {
        NSString *cookiesStr = message.body;
        NSLog(@"当前的cookie为： %@", cookiesStr);
    }
}
#pragma mark WKUIDelegate

- (WKWebView *)webView:(WKWebView *)webView createWebViewWithConfiguration:(WKWebViewConfiguration *)configuration forNavigationAction:(WKNavigationAction *)navigationAction windowFeatures:(WKWindowFeatures *)windowFeatures
{
    //这里不打开新窗口
    [self.webView loadRequest:navigationAction.request];
    return nil;
}

- (void)webView:(WKWebView *)webView runJavaScriptAlertPanelWithMessage:(NSString *)message initiatedByFrame:(WKFrameInfo *)frame completionHandler:(nonnull void (^)(void))completionHandler
{
    //js 里面的alert实现，如果不实现，网页的alert函数无效
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:message message:nil preferredStyle:UIAlertControllerStyleAlert];
    [alertController addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
        completionHandler();
    }]];
    [self presentViewController:alertController animated:YES completion:^{}];
}

- (void)webView:(WKWebView *)webView runJavaScriptConfirmPanelWithMessage:(NSString *)message initiatedByFrame:(WKFrameInfo *)frame completionHandler:(void (^)(BOOL))completionHandler {
    //  js 里面的alert实现，如果不实现，网页的alert函数无效  ,
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:message message:nil preferredStyle:UIAlertControllerStyleAlert];
    [alertController addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:^(UIAlertAction *action){
        completionHandler(NO);
    }]];
    [alertController addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        completionHandler(YES);
    }]];
    [self presentViewController:alertController animated:YES completion:^{}];
}

- (void)webView:(WKWebView *)webView runJavaScriptTextInputPanelWithPrompt:(NSString *)prompt defaultText:(NSString *)defaultText initiatedByFrame:(WKFrameInfo *)frame completionHandler:(void (^)(NSString *))completionHandler
{
    //用于和JS交互，弹出输入框
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:prompt message:nil preferredStyle:UIAlertControllerStyleAlert];
    [alertController addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:^(UIAlertAction *action){
        completionHandler(nil);
    }]];
    [alertController addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        UITextField *textField = alertController.textFields.firstObject;
        completionHandler(textField.text);
    }]];
    [alertController addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.text = defaultText;
    }];
    [self presentViewController:alertController animated:YES completion:NULL];
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
