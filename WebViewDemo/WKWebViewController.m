//
//  WKWebViewController.m
//  WebViewDemo
//
//  Created by DarkAngel on 16/9/1.
//  Copyright © 2016年 暗の天使. All rights reserved.
//

#import "WKWebViewController.h"
#import "NSHTTPCookie+Utils.h"
#import "Constants.h"
#import <WebKit/WebKit.h>
#import <ContactsUI/ContactsUI.h>

@interface WKWebViewController () <
WKUIDelegate,
WKNavigationDelegate,
WKScriptMessageHandler,
CNContactPickerDelegate
>

@property (strong, nonatomic) WKWebView *webView;

@property (nonatomic, copy) void (^completion)(NSString *name, NSString *phone);

@end

@implementation WKWebViewController

#pragma mark - Life Cycle

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    WKWebViewConfiguration *configuration = [[WKWebViewConfiguration alloc] init];
//    static WKProcessPool *pool;
//    static dispatch_once_t onceToken;
//    dispatch_once(&onceToken, ^{
//        //共用一个pool
//        pool = [[WKProcessPool alloc] init];
//    });
//    configuration.processPool = pool;
    
    //自定义脚本等
    WKUserContentController *controller = [[WKUserContentController alloc] init];
    //添加js全局变量
    WKUserScript *script = [[WKUserScript alloc] initWithSource:@"var interesting = 123;" injectionTime:WKUserScriptInjectionTimeAtDocumentStart forMainFrameOnly:NO];
    //页面加载完成立刻回调，获取页面上的所有Cookie
    WKUserScript *cookieScript = [[WKUserScript alloc] initWithSource:@"                window.webkit.messageHandlers.currentCookies.postMessage(document.cookie);" injectionTime:WKUserScriptInjectionTimeAtDocumentEnd forMainFrameOnly:NO];
    //alert Cookie
//    WKUserScript *alertCookieScript = [[WKUserScript alloc] initWithSource:@"alert(document.cookie);" injectionTime:WKUserScriptInjectionTimeAtDocumentEnd forMainFrameOnly:NO];
    //添加自定义的cookie
    WKUserScript *newCookieScript = [[WKUserScript alloc] initWithSource:@"                document.cookie = 'DarkAngelCookie=DarkAngel;'" injectionTime:WKUserScriptInjectionTimeAtDocumentStart forMainFrameOnly:NO];
    
    //添加脚本
    [controller addUserScript:script];
    [controller addUserScript:cookieScript];
//    [controller addUserScript:alertCookieScript];
    [controller addUserScript:newCookieScript];
    //注册回调
    [controller addScriptMessageHandler:self name:@"share"];
    [controller addScriptMessageHandler:self name:@"currentCookies"];
    [controller addScriptMessageHandler:self name:@"shareNew"];
    
    configuration.userContentController = controller;
    
    self.webView = [[WKWebView alloc] initWithFrame:self.view.bounds configuration:configuration];
    self.webView.allowsBackForwardNavigationGestures = YES;
    self.webView.UIDelegate = self;
    self.webView.navigationDelegate = self;
    self.webView.allowsLinkPreview = YES; //允许链接3D Touch
    self.webView.customUserAgent = @"WebViewDemo/1.0.0";    //自定义UA
    self.webView.scrollView.contentInset = UIEdgeInsetsMake(64, 0, 49, 0);
    //史诗级神坑，为何如此写呢？参考https://opensource.apple.com/source/WebKit2/WebKit2-7600.1.4.11.10/ChangeLog   以及我博客中的介绍
    [self.webView setValue:[NSValue valueWithUIEdgeInsets:self.webView.scrollView.contentInset] forKey:@"_obscuredInsets"];
    
    [self.view addSubview:self.webView];
    
    //更新webView的cookie
    [self updateWebViewCookie];
    //图片添加点击事件
    [self imgAddClickEvent];
    //添加NativeApi
    [self addNativeApiToJS];
    
    [self.webView loadRequest:[NSURLRequest requestWithURL:[NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"test" ofType:@"html"]]]];
    //可以测试百度还是test
//    [self loadUrl:@"http://m.baidu.com/"];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if (self) {
        //比如我在这个时候保存了Cookie
        [self saveCookie];
    }
    return self;
}

- (void)dealloc
{
    //记得移除
    [self.webView.configuration.userContentController removeScriptMessageHandlerForName:@"share"];
    [self.webView.configuration.userContentController removeScriptMessageHandlerForName:@"currentCookies"];
    [self.webView.configuration.userContentController removeScriptMessageHandlerForName:@"shareNew"];
    [self.webView.configuration.userContentController removeScriptMessageHandlerForName:@"imageDidClick"];
    //NativeApi相关
    [self.webView.configuration.userContentController removeScriptMessageHandlerForName:@"nativeShare"];
    [self.webView.configuration.userContentController removeScriptMessageHandlerForName:@"nativeChoosePhoneContact"];
}

#pragma mark - Events

/**
 页面中的所有img标签添加点击事件
 */
- (void)imgAddClickEvent
{
    //防止频繁IO操作，造成性能影响
    static NSString *jsSource;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        jsSource = [NSString stringWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"ImgAddClickEvent" ofType:@"js"] encoding:NSUTF8StringEncoding error:nil];
    });
    //添加自定义的脚本
    WKUserScript *js = [[WKUserScript alloc] initWithSource:jsSource injectionTime:WKUserScriptInjectionTimeAtDocumentEnd forMainFrameOnly:NO];
    [self.webView.configuration.userContentController addUserScript:js];
    //注册回调
    [self.webView.configuration.userContentController addScriptMessageHandler:self name:@"imageDidClick"];
}

/**
 添加native端的api
 */
- (void)addNativeApiToJS
{
    //防止频繁IO操作，造成性能影响
    static NSString *nativejsSource;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        nativejsSource = [NSString stringWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"NativeApi" ofType:@"js"] encoding:NSUTF8StringEncoding error:nil];
    });
    //添加自定义的脚本
    WKUserScript *js = [[WKUserScript alloc] initWithSource:nativejsSource injectionTime:WKUserScriptInjectionTimeAtDocumentStart forMainFrameOnly:NO];
    [self.webView.configuration.userContentController addUserScript:js];
    //注册回调
    [self.webView.configuration.userContentController addScriptMessageHandler:self name:@"nativeShare"];
    [self.webView.configuration.userContentController addScriptMessageHandler:self name:@"nativeChoosePhoneContact"];
}

/*!
 *  更新webView的cookie
 */
- (void)updateWebViewCookie
{
    WKUserScript * cookieScript = [[WKUserScript alloc] initWithSource:[self cookieString] injectionTime:WKUserScriptInjectionTimeAtDocumentStart forMainFrameOnly:NO];
    //添加Cookie
    [self.webView.configuration.userContentController addUserScript:cookieScript];
}

//比如你在登录成功时，保存Cookie
- (void)saveCookie
{
    /*
    //如果从已有的地方保存Cookie，比如登录成功
    NSArray *allCookies = [[NSHTTPCookieStorage sharedHTTPCookieStorage] cookies];
    for (NSHTTPCookie *cookie in allCookies) {
        if ([cookie.name isEqualToString:DAServerSessionCookieName]) {
            NSDictionary *dict = [[NSUserDefaults standardUserDefaults] dictionaryForKey:DAUserDefaultsCookieStorageKey];
            if (dict) {
                NSHTTPCookie *localCookie = [NSHTTPCookie cookieWithProperties:dict];
                if (![cookie.value isEqual:localCookie.value]) {
                    NSLog(@"本地Cookie有更新");
                }
            }
            [[NSUserDefaults standardUserDefaults] setObject:cookie.properties forKey:DAUserDefaultsCookieStorageKey];
            [[NSUserDefaults standardUserDefaults] synchronize];
            break;
        }
    }
     */

    NSHTTPCookie *cookie = [NSHTTPCookie cookieWithProperties:@{
                                                                NSHTTPCookieName: DAServerSessionCookieName,
                                                                NSHTTPCookieValue: @"1314521",
                                                                NSHTTPCookieDomain: @".baidu.com",
                                                                NSHTTPCookiePath: @"/"
                                                                }];
    [[NSUserDefaults standardUserDefaults] setObject:cookie.properties forKey:DAUserDefaultsCookieStorageKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}


/**
 解决首次加载页面Cookie带不上问题

 @param url 链接
 */
- (void)loadUrl:(NSString *)url
{
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:url]];
    [self.webView loadRequest:[self fixRequest:request]];
}

/**
 修复打开链接Cookie丢失问题

 @param request 请求
 @return 一个fixedRequest
 */
- (NSURLRequest *)fixRequest:(NSURLRequest *)request
{
    NSMutableURLRequest *fixedRequest;
    if ([request isKindOfClass:[NSMutableURLRequest class]]) {
        fixedRequest = (NSMutableURLRequest *)request;
    } else {
        fixedRequest = request.mutableCopy;
    }
    //防止Cookie丢失
    NSDictionary *dict = [NSHTTPCookie requestHeaderFieldsWithCookies:[NSHTTPCookieStorage sharedHTTPCookieStorage].cookies];
    if (dict.count) {
        NSMutableDictionary *mDict = request.allHTTPHeaderFields.mutableCopy;
        [mDict setValuesForKeysWithDictionary:dict];
        fixedRequest.allHTTPHeaderFields = mDict;
    }
    return fixedRequest;
}

- (IBAction)refresh:(id)sender {
    //刷新
    [self.webView reload];
    /*
    //等同于
    [self.webView evaluateJavaScript:@"location.reload()" completionHandler:^(id _Nullable result, NSError * _Nullable error) {
        
    }];
     */
}

#pragma mark 选择联系人

- (void)selectContactCompletion:(void (^)(NSString *name, NSString *phone))completion
{
    self.completion = completion;
    CNContactPickerViewController *picker = [[CNContactPickerViewController alloc] init];
    picker.delegate = self;
    picker.displayedPropertyKeys = @[CNContactPhoneNumbersKey];
    [self presentViewController:picker animated:YES completion:nil];
}

#pragma mark oc -> js
/**
 测试evaluateJavaScript方法
 */
- (IBAction)testEvaluateJavaScript {
    
    [self.webView evaluateJavaScript:@"document.cookie" completionHandler:^(id _Nullable cookies, NSError * _Nullable error) {
        NSLog(@"调用evaluateJavaScript异步获取cookie：%@", cookies);
    }];
    
    // do not use dispatch_semaphore_t
    /*
    __block id cookies;
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    [self.webView evaluateJavaScript:@"document.cookie" completionHandler:^(id _Nullable result, NSError * _Nullable error) {
        cookies = result;
        dispatch_semaphore_signal(semaphore);
    }];
    //等待三秒，接收参数
    dispatch_semaphore_wait(semaphore, dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC));
    //打印cookie，肯定为空，因为足足等了3s，dispatch_semaphore_signal没有起作用
    NSLog(@"cookie的值为：%@", cookies);
    
    //还是老实的接受异步回调吧，不要用信号来搞成同步，会卡死的，不信可以试试
     */
}

#pragma mark - WKNavigationDelegate 方法按调用前后顺序排序

//针对一次action来决定是否允许跳转，允许与否都需要调用decisionHandler，比如decisionHandler(WKNavigationActionPolicyCancel);
- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler
{
    //可以通过navigationAction.navigationType获取跳转类型，如新链接、后退等
    NSURL *URL = navigationAction.request.URL;
    //判断URL是否符合自定义的URL Scheme
    if ([URL.scheme isEqualToString:DAWebViewDemoScheme]) {
        //根据不同的业务，来执行对应的操作，且获取参数
        if ([URL.host isEqualToString:DAWebViewDemoHostSmsLogin]) {
            NSString *param = URL.query;
            NSLog(@"短信验证码登录, 参数为%@", param);
            decisionHandler(WKNavigationActionPolicyCancel);
            return;
        }
    }
    
#warning important 这里很重要
    //解决Cookie丢失问题
    NSURLRequest *originalRequest = navigationAction.request;
    [self fixRequest:originalRequest];
    //如果originalRequest就是NSMutableURLRequest, originalRequest中已添加必要的Cookie，可以跳转
    //允许跳转
    decisionHandler(WKNavigationActionPolicyAllow);
    
    NSLog(@"%@", NSStringFromSelector(_cmd));
}

//根据response来决定，是否允许跳转，允许与否都需要调用decisionHandler，如decisionHandler(WKNavigationResponsePolicyAllow);
- (void)webView:(WKWebView *)webView decidePolicyForNavigationResponse:(WKNavigationResponse *)navigationResponse decisionHandler:(void (^)(WKNavigationResponsePolicy))decisionHandler
{
    NSLog(@"%@", NSStringFromSelector(_cmd));
    decisionHandler(WKNavigationResponsePolicyAllow);
}

//提交了一个跳转，早于 didStartProvisionalNavigation
- (void)webView:(WKWebView *)webView didCommitNavigation:(null_unspecified WKNavigation *)navigation
{
    NSLog(@"%@", NSStringFromSelector(_cmd));
}

//开始加载，对应UIWebView的- (void)webViewDidStartLoad:(UIWebView *)webView;
- (void)webView:(WKWebView *)webView didStartProvisionalNavigation:(null_unspecified WKNavigation *)navigation
{
    [UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
    NSLog(@"%@", NSStringFromSelector(_cmd));
}

//加载成功，对应UIWebView的- (void)webViewDidFinishLoad:(UIWebView *)webView;
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

//页面加载失败或者跳转失败，对应UIWebView的- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error;
- (void)webView:(WKWebView *)webView didFailNavigation:(null_unspecified WKNavigation *)navigation withError:(NSError *)error
{
    [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
    NSLog(@"%@\nerror：%@", NSStringFromSelector(_cmd), error);
}

//页面加载数据时报错
- (void)webView:(WKWebView *)webView didFailProvisionalNavigation:(null_unspecified WKNavigation *)navigation withError:(NSError *)error
{
    [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
    NSLog(@"%@\nerror：%@", NSStringFromSelector(_cmd), error);
}

#pragma mark - WKUIDelegate

- (WKWebView *)webView:(WKWebView *)webView createWebViewWithConfiguration:(WKWebViewConfiguration *)configuration forNavigationAction:(WKNavigationAction *)navigationAction windowFeatures:(WKWindowFeatures *)windowFeatures
{
#warning important 这里也很重要
    //这里不打开新窗口
    [self.webView loadRequest:[self fixRequest:navigationAction.request]];
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

#pragma mark - WKScriptMessageHandler  js -> oc

- (void)userContentController:(WKUserContentController *)userContentController didReceiveScriptMessage:(WKScriptMessage *)message
{
    if ([message.name isEqualToString:@"share"]) {
        id body = message.body;
        NSLog(@"share分享的内容为：%@", body);
    }
    else if ([message.name isEqualToString:@"shareNew"] || [message.name isEqualToString:@"nativeShare"]) {
        NSDictionary *shareData = message.body;
        NSLog(@"%@分享的数据为： %@", message.name, shareData);
        //模拟异步回调
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(4 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            //读取js function的字符串
            NSString *jsFunctionString = shareData[@"result"];
            //拼接调用该方法的js字符串
            NSString *callbackJs = [NSString stringWithFormat:@"(%@)(%d);", jsFunctionString, NO];    //后面的参数NO为模拟分享失败
            //执行回调
            [self.webView evaluateJavaScript:callbackJs completionHandler:^(id _Nullable result, NSError * _Nullable error) {
                if (!error) {
                    NSLog(@"模拟回调，分享失败");
                }
            }];
        });
    }
    else if ([message.name isEqualToString:@"currentCookies"]) {
        NSString *cookiesStr = message.body;
        NSLog(@"当前的cookie为： %@", cookiesStr);
    }
    else if ([message.name isEqualToString:@"imageDidClick"]) {
        //点击了html上的图片
        NSLog(@"点击了html上的图片，参数为%@", message.body);
        /*
         会log
         
         点击了html上的图片，参数为{
         height = 168;
         imgUrl = "http://cc.cocimg.com/api/uploads/170425/b2d6e7ea5b3172e6c39120b7bfd662fb.jpg";
         imgUrls =     (
         "http://cc.cocimg.com/api/uploads/170425/b2d6e7ea5b3172e6c39120b7bfd662fb.jpg"
         );
         index = 0;
         width = 252;
         x = 8;
         y = 8;
         }
         
         注意这里的x，y是不包含自定义scrollView的contentInset的，如果要获取图片在屏幕上的位置：
         x = x + contentInset.left;
         y = y + contentInset.top;
         */
        NSDictionary *dict = message.body;
        NSString *selectedImageUrl = dict[@"imgUrl"];
        CGFloat x = [dict[@"x"] floatValue] + + self.webView.scrollView.contentInset.left;
        CGFloat y = [dict[@"y"] floatValue] + self.webView.scrollView.contentInset.top;
        CGFloat width = [dict[@"width"] floatValue];
        CGFloat height = [dict[@"height"] floatValue];
        CGRect frame = CGRectMake(x, y, width, height);
        NSUInteger index = [dict[@"index"] integerValue];
        NSLog(@"点击了第%@个图片，\n链接为%@，\n在Screen中的绝对frame为%@，\n所有的图片数组为%@", @(index), selectedImageUrl, NSStringFromCGRect(frame), dict[@"imgUrls"]);
        
    }
    //选择联系人
    else if ([message.name isEqualToString:@"nativeChoosePhoneContact"]) {
        NSLog(@"正在选择联系人");
        
        [self selectContactCompletion:^(NSString *name, NSString *phone) {
            NSLog(@"选择完成");
            //读取js function的字符串
            NSString *jsFunctionString = message.body[@"completion"];
            //拼接调用该方法的js字符串
            NSString *callbackJs = [NSString stringWithFormat:@"(%@)({name: '%@', mobile: '%@'});", jsFunctionString, name, phone];
            //执行回调
            [self.webView evaluateJavaScript:callbackJs completionHandler:^(id _Nullable result, NSError * _Nullable error) {
                
            }];
        }];
    
    }
}

#pragma mark - CNContactPickerDelegate

- (void)contactPickerDidCancel:(CNContactPickerViewController *)picker
{
    [picker dismissViewControllerAnimated:YES completion:nil];
}

- (void)contactPicker:(CNContactPickerViewController *)picker didSelectContactProperty:(CNContactProperty *)contactProperty
{
    if (![contactProperty.key isEqualToString:CNContactPhoneNumbersKey]) {
        return;
    }
    CNContact *contact = contactProperty.contact;
    NSString *name = [CNContactFormatter stringFromContact:contact style:CNContactFormatterStyleFullName];
    
    CNPhoneNumber *phoneNumber = contactProperty.value;
    NSString *phone = phoneNumber.stringValue.length ? phoneNumber.stringValue : @"";
    //可以把-、+86、空格这些过滤掉
    NSString *phoneStr = [phone stringByReplacingOccurrencesOfString:@"-" withString:@""];
    phoneStr = [phoneStr stringByReplacingOccurrencesOfString:@"+86" withString:@""];
    phoneStr = [phoneStr stringByReplacingOccurrencesOfString:@" " withString:@""];
    phoneStr = [[phoneStr componentsSeparatedByCharactersInSet:[[NSCharacterSet characterSetWithCharactersInString:@"0123456789"] invertedSet]] componentsJoinedByString:@""];
    
    //回调
    if (self.completion) {
        self.completion(name, phoneStr);
    }
    
    //dismiss
    [picker dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - Setters and Getters

- (NSString *)cookieString
{
    NSMutableString *script = [NSMutableString string];
    for (NSHTTPCookie *cookie in [[NSHTTPCookieStorage sharedHTTPCookieStorage] cookies]) {
        // Skip cookies that will break our script
        if ([cookie.value rangeOfString:@"'"].location != NSNotFound) {
            continue;
        }
        // Create a line that appends this cookie to the web view's document's cookies
        [script appendFormat:@"document.cookie='%@'; \n", cookie.da_javascriptString];
    }
    return script;
}

@end
