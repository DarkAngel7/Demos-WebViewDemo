
![](http://ww4.sinaimg.cn/large/006tNc79ly1fff1sa06wrj30sg0iwwi9.jpg)

# 前言

iOS开发中，用来显示一个html页、H5页，经常会用的一个控件是WebView。说到WebView，你知道多少呢？是简单的展示，还是要和OC交互实现比较复杂的功能呢？本文将为您介绍iOS中的WebView，并且由浅到深，一步步带你了解并掌握WebView的用法，JavaScript与Objective的交互，以及Cookie的管理、js的调试等。

文章因涉及到的内容较多，因此拆分成以下几部分：

- iOS中UIWebView与WKWebView、JavaScript与OC交互、Cookie管理看我就够（上）
- [iOS中UIWebView与WKWebView、JavaScript与OC交互、Cookie管理看我就够（中）]()（待填坑...）
- [iOS中UIWebView与WKWebView、JavaScript与OC交互、Cookie管理看我就够（下）]()（待填坑...）

关于文中提到的一些内容，这里我准备了个[Demo](https://github.com/DarkAngel7/Demos-WebViewDemo)，有需要的小伙伴可以下载。

# UIWebView
## UIWebView基本用法
首先要介绍的就是我们的老朋友`UIWebView`。相信对大多数小伙伴儿而言，`UIWebView`和`UILabel`一样，都是最早接触的控件了，其实`UIWebView`用法比较简单（功能基本能满足需求），简单的创建，并且调用
```objective-c
- (void)loadRequest:(NSURLRequest *)request;
- (void)loadHTMLString:(NSString *)string baseURL:(nullable NSURL *)baseURL;
- (void)loadData:(NSData *)data MIMEType:(NSString *)MIMEType textEncodingName:(NSString *)textEncodingName baseURL:(NSURL *)baseURL;
```
这些方法，加载就可以了。
当然，如果需要监听页面加载的结果，或者需要判断是否允许打开某个URL，那需要设置`UIWebView`的`delegate`，代理只需要遵循`<UIWebViewDelegate>`协议，并且在代理中实现下面的这些可选方法就可以：
```objective-c
__TVOS_PROHIBITED @protocol UIWebViewDelegate <NSObject>

@optional
- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType;
- (void)webViewDidStartLoad:(UIWebView *)webView;
- (void)webViewDidFinishLoad:(UIWebView *)webView;
- (void)webView:(UIWebView *)webView didFailLoadWithError:(nullable NSError *)error;

@end
```



## UIWebView中JavaScript与Objective的交互

这里不详细讨论一些很好的第三方实现，比如[WebViewJavascriptBridge](https://github.com/marcuswestin/WebViewJavascriptBridge)，单纯的讲讲native端JS与OC的交互实现方式，读完了下面的部分，相信你也会实现一个简单的`bridge`了。

### UIWebView OC调用JS

#### 1. stringByEvaluatingJavaScriptFromString:

最常用的方法，很简单，只要调用`- (nullable NSString *)stringByEvaluatingJavaScriptFromString:(NSString *)script;`就可以了，如：
```objective-c
    self.navigationItem.title = [webView stringByEvaluatingJavaScriptFromString:@"document.title"];
```
虽然比较方便，但是缺点也有：

1. 该方法不能判断调用了一个js方法之后，是否发生了错误。当错误发生时，返回值为nil，而当调用一个方法本身没有返回值时，返回值也为nil，所以无法判断是否调用成功了。
2. 返回值类型为`nullable NSString *`，就意味着当调用的js方法有返回值时，都以字符串返回，不够灵活。当返回值是一个js的Array时，还需要解析字符串，比较麻烦。

对于上述缺点，可以通过使用JavaScriptCore（iOS 7.0 +）来解决。

#### 2. JavaScriptCore（iOS 7.0 +）

想必大家不会陌生吧，前些日子弄的沸沸扬扬的`JSPatch`被禁事件中，最核心的就是它了。因为`JavaScriptCore`的JS到OC的映射，可以替换各种js方法成oc方法，所以其**动态性（配合runtime的不安全性）**也就成为了`JSPatch`被**Apple**禁掉的最主要原因。这里讲下`UIWebView`通过`JavaScriptCore`来实现OC->JS。

其实WebKit都有一个内嵌的js环境，一般我们在页面加载完成之后，获取js上下文，然后通过`JSContext`的`evaluateScript:`方法来获取返回值。因为该方法得到的是一个`JSValue`对象，所以支持JavaScript的Array、Number、String、对象等数据类型。

```objective-c
- (void)webViewDidFinishLoad:(UIWebView *)webView
{
	//更新标题，这是上面的讲过的方法
    //self.navigationItem.title = [webView stringByEvaluatingJavaScriptFromString:@"document.title"];
    
    //获取该UIWebView的javascript上下文
    JSContext *jsContext = [self.webView valueForKeyPath:@"documentView.webView.mainFrame.javaScriptContext"];
    
	//这也是一种获取标题的方法。
	JSValue *value = [self.jsContext evaluateScript:@"document.title"];
	//更新标题
    self.navigationItem.title = value.toString;
}
```

该方法解决了`stringByEvaluatingJavaScriptFromString:`返回值只是`NSString`的问题。

那么如果我执行了一个不存在的方法，比如

```objective-c
[self.jsContext evaluateScript:@"document.titlexxxx"];
```

那么必然会报错，报错了，可以通过`@property (copy) void(^exceptionHandler)(JSContext *context, JSValue *exception);`，设置该block来获取异常。

```objective-c
//在调用前，设置异常回调
[self.jsContext setExceptionHandler:^(JSContext *context, JSValue *exception){
        NSLog(@"%@", exception);
}];
//执行方法
JSValue *value = [self.jsContext evaluateScript:@"document.titlexxxx"];
```

该方法，也很好的解决了`stringByEvaluatingJavaScriptFromString:`调用js方法后，出现错误却捕获不到的缺点。

### UIWebView JS调用OC

#### 1. Custom URL Scheme（拦截URL）

比如`darkangel://`。方法是在html或者js中，点击某个按钮触发事件时，跳转到自定义URL Scheme构成的链接，而Objective-C中捕获该链接，从中解析必要的参数，实现JS到OC的一次交互。比如页面中一个a标签，链接如下：

```html
<a href="darkangel://smsLogin?username=12323123&code=892845">短信验证登录</a>
```

而在Objective-C中，只要遵循了`UIWebViewDelegate`协议，那么每次打开一个链接之前，都会触发方法

```objective-c
- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType；
```

在该方法中，捕获该链接，并且返回NO（**阻止本次跳转**），从而执行对应的OC方法。

```objective-c
- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType
{
	//标准的URL包含scheme、host、port、path、query、fragment等
    NSURL *URL = request.URL;    
    if ([URL.scheme isEqualToString:@"darkangel"]) {
        if ([URL.host isEqualToString:@"smsLogin"]) {
            NSLog(@"短信验证码登录，参数为 %@", URL.query);
            return NO;
        }
    }
    return YES;
}
```

当用户点击**短信验证登录**时，控制台会输出` 短信验证码登录，参数为 username=12323123&code=892845`。参数可以是一个json格式并且URLEncode过的字符串，这样就可以实现复杂参数的传递（比如[WebViewJavascriptBridge](https://github.com/marcuswestin/WebViewJavascriptBridge)）。

**优点**：泛用性强，可以配合h5实现页面动态化。比如页面中一个活动链接到活动详情页，当native尚未开发完毕时，链接可以是一个h5链接，等到native开发完毕时，可以通过该方法跳转到native页面，实现页面动态化。且该方案适用于Android和iOS，泛用性很强。

**缺点**：无法直接获取本次交互的返回值，比较适合单向传参，且不关心回调的情景，比如h5页面跳转到native页面等。

其实，[WebViewJavascriptBridge](https://github.com/marcuswestin/WebViewJavascriptBridge)使用的方案就是**拦截URL**，为了解决无法直接获取返回值的缺点，它采用了将一个名为`callback`的`function`作为参数，通过一些封装，传递到OC（**js->oc** 传递参数和callbackId），然后在OC端执行完毕，再通过`block`来回调callback（**oc->js**，传递返回值参数），实现异步获取返回值，比如在js端调用

```javascript
//JS调用OC的分享方法（当然需要OC提前注册）share为方法名，shareData为参数，后面的为回调function
WebViewJavascriptBridge.callHandler('share', shareData, function(response) {
   //OC端通过block回调分享成功或者失败的结果
   alert(response);   
});
```

具体的可以看下它的源码，还是很值得学习的。

#### 2. JavaScriptCore（iOS 7.0 +）

除了**拦截URL**的方法，还可以利用上面提到的`JavaScriptCore`。它十分强大，强大在哪里呢？下面我们来一探究竟。

当然，还是需要在页面加载完成时，先获取js上下文。获取到之后，我们就可以进行强大的方法映射了。

比如js中我定义了一个分享的方法

```javascript
function share(title, imgUrl, link) {
     //这里需要OC实现
}
```

在OC中实现如下

```objective-c
- (void)webViewDidFinishLoad:(UIWebView *)webView
{
    //将js的function映射到OC的方法
    [self convertJSFunctionsToOCMethods];
}

- (void)convertJSFunctionsToOCMethods
{
	//获取该UIWebview的javascript上下文
	//self持有jsContext
	//@property (nonatomic, strong) JSContext *jsContext;
    self.jsContext = [self.webView valueForKeyPath:@"documentView.webView.mainFrame.javaScriptContext"];
	
    //js调用oc
    //其中share就是js的方法名称，赋给是一个block 里面是oc代码
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
}
```

在html或者js的某处，点击a标签调用这个share方法，并传参，如

```html
<a href="javascript:void(0);" class="sharebtn" onClick="share('分享标题', 'http://cc.cocimg.com/api/uploads/170425/b2d6e7ea5b3172e6c39120b7bfd662fb.jpg', location.href)">分享活动，领30元红包</a>
```

此时，如果用户点击了**<u>分享活动，领30元红包</u>**这个标签，那么在控制台会打印出所有参数![](http://ww2.sinaimg.cn/large/006tNc79ly1fff18hle74j31ak0hiah2.jpg)

上面的代码实现了OC方法替换JS实现。它十分灵活，主要依赖这些Api。

```objective-c
@interface JSContext (SubscriptSupport)
/*!
@method
@abstract Get a particular property on the global object.
@result The JSValue for the global object's property.
*/
- (JSValue *)objectForKeyedSubscript:(id)key;
/*!
@method
@abstract Set a particular property on the global object.
*/
- (void)setObject:(id)object forKeyedSubscript:(NSObject <NSCopying> *)key;
```

`self.jsContext[@"yourMethodName"] = your block;`这样写不仅可以在有`yourMethodName`方法时替换该JS方法为OC实现，还会在g该方法没有时，添加方法。简而言之，**有则替换，无则添加**。



那如果我想写一个有两个参数，一个返回值的js方法，oc应该怎么替换呢？

js中

```javascript
//该方法传入两个整数，求和，并返回结果
function testAddMethod(a, b) {
 	//需要OC实现a+b，并返回
  	return a + b;
}
//js调用
console.log(testAddMethod(1, 5));	//output  6
```



oc直接替换该方法

```objective-c
self.jsContext[@"testAddMethod"] = ^NSInteger(NSInteger a, NSInteger b) {
      return a + b;
};
```

那么当在js调用

```javascript
//js调用
console.log(testAddMethod(1, 5));	//output  6， 方法为 a + b
```



如果oc替换该方法为两数相乘

```objective-c
self.jsContext[@"testAddMethod"] = ^NSInteger(NSInteger a, NSInteger b) {
      return a * b;
};
```

再次调用js

```javascript
console.log(testAddMethod(1, 5));	//output  5，该方法变为了 a * b。
```



举一反三，调用方法原实现，并且在原结果上乘以10。

```objective-c
//调用方法的本来实现，给原结果乘以10
JSValue *value = self.jsContext[@"testAddMethod"];
self.jsContext[@"testAddMethod"] = ^NSInteger(NSInteger a, NSInteger b) {
    JSValue *resultValue = [value callWithArguments:[JSContext currentArguments]];
    return resultValue.toInt32 * 10;
};
```

再次调用js

```javascript
console.log(testAddMethod(1, 5));	//output  60，该方法变为了(a + b) * 10
```



上面的方法，都是同步函数，如果我想实现JS调用OC的方法，并且异步接收回调，那么该怎么做呢？比如h5中有一个分享按钮，用户点击之后，调用native分享（微信分享、微博分享等），在native分享成功或者失败时，回调h5页面，告诉其分享结果，h5页面刷新对应的UI，显示分享成功或者失败。

这个问题，需要对js有一定了解。下面上js代码。

```javascript
//声明
function share(shareData) {
    var title = shareData.title;
    var imgUrl = shareData.imgUrl;
    var link = shareData.link;
    var result = shareData.result;
  	//do something
    //这里模拟异步操作
    setTimeout(function(){
   	   //2s之后，回调true分享成功
       result(true);
    }, 2000);
}

//调用的时候需要这么写
share({
  	title: "title", 
 	imgUrl: "http://img.dd.com/xxx.png", 
 	link: location.href, 
 	result: function(res) {	//函数作为参数
         console.log(res ? "success" : "failure");
	}
});
```

从封装的角度上讲，js的`share`方法的参数是一个`对象`，该对象包含了几个必要的字段，以及一个回调函数，这个回调函数有点像oc的`block`，**调用者**把一个`function`传入一个`function`当作参数，在适当时候，方法内**实现者**调用该`function`，实现对**调用者**的异步回调。那么如果此时OC来实现`share`方法，该怎么做呢？其实大概是这样的：

```objective-c
//异步回调
self.jsContext[@"share"] = ^(JSValue *shareData) {	//首先这里要注意，回调的参数不能直接写NSDictionary类型，为何呢？
    //仔细看，打印出的确实是一个NSDictionary，但是result字段对应的不是block而是一个NSDictionary  
  	NSLog(@"%@", [shareData toObject]); 	
    //获取shareData对象的result属性，这个JSValue对应的其实是一个javascript的function。
    JSValue *resultFunction = [shareData valueForProperty:@"result"];
    //回调block，将js的function转换为OC的block
    void (^result)(BOOL) = ^(BOOL isSuccess) {
        [resultFunction callWithArguments:@[@(isSuccess)]];
    };
    //模拟异步回调
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSLog(@"回调分享成功");
        result(YES);
    });
};
```

其中一些坑，已经在代码的注释写的比较清楚了，这里要注意`JavaScript`的`function`和`Objective-C`的`block`的转换。

从上面的一些探讨和尝试来看，足以证明`JavaScriptCore`的强大，这里不再展开，小伙伴们可以自行探索。

## UIWebView的Cookie管理

### Cookie简介

说到`Cookie`，或许有些小伙伴会比较陌生，有些小伙伴会比较熟悉。如果项目中，所有页面都是纯原生来实现的话，一般`Cookie`这个东西或许我们永远也不会接触到。但是，这里还是要说一下`Cookie`，因为它真的很重要，由它产生的一些坑也很多。

`Cookie`在Web利用的最多的地方，是用来记录各种状态。比如你在`Safari`中打开百度，然后登陆自己的账号，之后打开所有百度相关的页面，都会是登陆状态，而且当你关了电脑，下次开机再次打开`Safari`打开百度，会发现还是登陆状态，其实这个就利用了`Cookie`。`Cookie`中记录了你百度账号的一些信息、有效期等，也维持了跨域请求时登录状态的统计性。![](http://ww3.sinaimg.cn/large/006tNc79ly1fff5jbzd4cj31kw0jk11w.jpg)可以看到`Cookie`的域各不相同，有效期也各不相同，一般`.baidu.com`这样的域的`Cookie`就是为了跨域时，可以维持一些状态。

那么在App中，Cookie最常用的就是维持登录状态了。一般Native端都有自己的一套完整登录注册逻辑，一般大部分页面都是原生实现的。当然，也会有一些页面是h5来实现的，虽然h5页面在App中通过`WebView`加载或多或少都会有点性能问题，感觉不流畅或者体验不好，但是它的灵活性是Native App无法比拟的。那么由此，便产生了一种需求，当Native端用户是登录状态的，打开一个h5页面，h5也要维持用户的登录状态。

这个需求看似简单，如何实现呢？一般的解决方案是Native保存登录状态的Cookie，在打开h5页面中，把Cookie添加上，以此来维持登录状态。其实坑还是有很多的，比如用户登录或者退出了，h5页面的登录状态也变了，需要刷新，什么时候刷新？`WKWebView`中`Cookie`丢失问题？这里简单说下`UIWebView`的`Cookie`管理，后面的章节再介绍`WKWebView`。

### Cookie管理

`UIWebView`的`Cookie`管理很简单，一般不需要我们手动操作`Cookie`，因为所有`Cookie`都会被`[NSHTTPCookieStorage sharedHTTPCookieStorage]`这个单例管理，而且`UIWebView`会自动同步`CookieStorage`中的Cookie，所以只要我们在Native端，正常登陆退出，h5在适当时候刷新，就可以正确的维持登录状态，不需要做多余的操作。

可能有一些情况下，我们需要在访问某个链接时，添加一个固定`Cookie`用来做区分，那么就可以通过`header`来实现

```objective-c
NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"http://www.baidu.com"]];
[request addValue:@"customCookieName=1314521;" forHTTPHeaderField:@"Set-Cookie"];
[self.webView loadRequest:request];
```

也可以主动操作`NSHTTPCookieStorage`，添加一个自定义`Cookie`

```objective-c
NSHTTPCookie *cookie = [NSHTTPCookie cookieWithProperties:@{
    NSHTTPCookieName: @"customCookieName", 
    NSHTTPCookieValue: @"1314521", 
    NSHTTPCookieDomain: @".baidu.com",
    NSHTTPCookiePath: @"/"
}];
[[NSHTTPCookieStorage sharedHTTPCookieStorage] setCookie:cookie];	//Cookie存在则覆盖，不存在添加
```

还有一些常用的方法，如读取所有`Cookie`

```objective-c
NSArray *cookies = [NSHTTPCookieStorage sharedHTTPCookieStorage].cookies;
```

`Cookie`转换成`HTTPHeaderFields`，并添加到`request`的`header`中

```objective-c
//Cookies数组转换为requestHeaderFields
NSDictionary *requestHeaderFields = [NSHTTPCookie requestHeaderFieldsWithCookies:cookies];
//设置请求头
request.allHTTPHeaderFields = requestHeaderFields;
```

整体来说`UIWebView`的`Cookie`管理比较简单，小伙伴们可以自己写个demo测试一下，发挥你们的想象。

# 未完待续

关于`UIWebView`的介绍，以及使用`UIWebView`进行JS与OC的交互，`Cookie`的管理，就先简单介绍到这里。如果有小伙伴对于[WebViewJavascriptBridge](https://github.com/marcuswestin/WebViewJavascriptBridge)比较感兴趣，可以留言，根据留言我考虑一下写一篇文章，分析它的详细实现。

另外，后续将为您介绍`WKWebView`的用法，一些OC与JS交互，Cookie管理、如何在`Safari`中调试以及一些不为人知的坑等，敬请期待~

To be continued...
