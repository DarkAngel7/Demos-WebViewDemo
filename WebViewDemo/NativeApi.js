/**
 * Native为H5提供的Api接口
 *
 * @type {js对象}
 */
var DANativeApi = (function() {

	var NativeApi = {
		/**
		 * 分享
		 * @param  {js对象} shareInfo 分享信息和回调
		 * @return {void}           无同步返回值，异步返回分享结果 true or false
		 */
		share: function(shareInfo) {
			if (shareInfo == undefined || shareInfo == null || typeof(shareInfo) !== "object") {
				alert("参数" + JSON.stringify(shareInfo) + "不合法");
			} else {
				alert("分享的参数为" + JSON.stringify(shareInfo));
			}
			//调用native端
			_nativeShare(shareInfo);
		},
		/**
		 * 从通讯录选择联系人
		 * @return {void} 无同步返回值，异步返回选择的结果
		 */
		choosePhoneContact: function(param) {
			//具体是否需要判断
			//调用native端
			_nativeChoosePhoneContact(param);
		}
	}

	//下面是一些私有函数
	/**
	 * Native端实现，适用于WKWebView，UIWebView如何实现，小伙伴自己动脑筋吧~
	 * @param  {js对象} shareInfo 分享的信息和回调
	 * @return {void}           无同步返回值，异步返回
	 */
	function _nativeShare(shareInfo) {
		//用于WKWebView，因为WKWebView并没有办法把js function传递过去，因此需要特殊处理一下
		//把js function转换为字符串，oc端调用时 (<js function string>)(true); 即可
		//如果有回调函数，且为function
		var callbackFunction = shareInfo.result;
		if (callbackFunction != undefined && callbackFunction != null && typeof(callbackFunction) === "function") {
			shareInfo.result = callbackFunction.toString();
		}
		//js -> oc 
		// 至于Android端，也可以，比如 window.jsInterface.nativeShare(JSON.stringify(shareInfo));
		window.webkit.messageHandlers.nativeShare.postMessage(shareInfo);
	}
	/**
	 * Native端实现选择联系人，并异步返回结果
	 * @param  {[type]} param [description]
	 * @return {[type]}       [description]
	 */
	function _nativeChoosePhoneContact(param) {
		var callbackFunction = param.completion;
		if (callbackFunction != undefined && callbackFunction != null && typeof(callbackFunction) === "function") {
			param.completion = callbackFunction.toString();
		}
		//js -> oc 
		window.webkit.messageHandlers.nativeChoosePhoneContact.postMessage(param);
	}

	//闭包，把Api对象返回
	return NativeApi;
})();

/*

//调用时，分享
DANativeApi.share({
	title: document.title,
	desc: "",
	url: location.href,
	imgUrl: "",
	result: function(res) {
		// body...
		alert("分享结果为：" + JSON.stringify(res));
	}
});

//选择联系人
DANativeApi.choosePhoneContact({
	completion: function(res) {
		alert("选择联系人的结果为：" + JSON.stringify(res));
	}
});
 */
