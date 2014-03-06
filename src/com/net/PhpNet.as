package com.net
{
	import flash.events.AsyncErrorEvent;
	import flash.events.Event;
	import flash.events.IOErrorEvent;
	import flash.events.NetStatusEvent;
	import flash.events.SecurityErrorEvent;
	import flash.net.NetConnection;
	import flash.net.Responder;

	public class PhpNet
	{
//		private static var address:String = "http://localhost/amfphp-2.1.1/Amfphp/";
		public static var WWW_ROOT:String = "http://idoooo1.w116.mc-test.com/";//
//		public static const WWW_ROOT:String = "http://localhost/";//
		
		private static var address:String = WWW_ROOT + "amfphp-2.1.1/Amfphp/";
		private static var responder:Responder;//服务器响应实例
		private static var nc:NetConnection;
		private static var isSend:Boolean;
		private static var msgList:Vector.<Array>;
		
		/**
		 * 改变域名位置
		 */		
		public static function changeServerRoot(root:String,phpRoot:String = "amfphp-2.1.1/Amfphp/"):void{
			WWW_ROOT = root;
			address = WWW_ROOT + phpRoot;// + "amfphp-2.1.1/Amfphp/";
		}
		private static var onComplete:Function;
		public static function addCompleteEvent(onComplete:Function):void{
			PhpNet.onComplete = onComplete;
		}
		private static var onError:Function;
		public static function addErrorEvent(onError:Function):void{
			PhpNet.onError = onError;
		}
		/**
		 * 
		 * @param command
		 * @param onResult({faultId:错误信息,data:发送成功的数据});
		 * @param args
		 */		
		public static function call(command:String,onResult:Function,...args):void{
			if(nc == null)createConnect();
			saveMsg(command,onResult,args);
		}
		
		private static function saveMsg(command:String,onResult:Function,args:Array):void
		{
			if(msgList == null)msgList = new Vector.<Array>();
			var phpFunc:PhpFunction = new PhpFunction(onResult,onPost);
			args.unshift(command,new Responder(phpFunc.onResult,phpFunc.onFault));
			msgList.push(args);
			postMsg();
		}
//		private static var currentMsg:PhpFunction;
		private static function postMsg():void{
			if(!isSend && msgList.length > 0){
				nc.call.apply(null,msgList.shift());//开始发送服务器进行测试
				isSend = true;
			}
		}
		
		private static function createConnect():void
		{
			nc = new NetConnection();
//			responder = new Responder(onResult, onFault);
			nc.connect(address);
			nc.addEventListener(NetStatusEvent.NET_STATUS,onNet);
			nc.addEventListener(IOErrorEvent.IO_ERROR,onNetError);//连接不上
			nc.addEventListener(SecurityErrorEvent.SECURITY_ERROR,onNetError);//安全问题不上
			nc.addEventListener(AsyncErrorEvent.ASYNC_ERROR,onNetError);//异步调度错误
		}
		
		private static function onNetError(e:Event = null):void
		{
			if(onError != null){
				onError();
				onError = null;
			}
			isSend = false;
		}
		
		private static function onNet(e:NetStatusEvent):void
		{
			trace('网络连接有问题:' + e.info.code);
			onNetError();
//			next();
		}	
		
		private static function onPost():void{
			next();
		}
		
		private static function next():void{
			isSend = false;
			if(msgList.length == 0){
				trace('数据全部接收完毕');
				if(onComplete != null){
					onComplete();
					onComplete = null;
				}
			}else{
				postMsg();
			}
		}
	}
}
class PhpFunction{
	public var callBack:Function;//faultId:错误信息 data:发送成功的数据
	public var onPost:Function;//提交成功后触发
	
	public function PhpFunction(callBack:Function,onPost:Function){
		this.callBack = callBack;
		this.onPost = onPost;
	}
	public function onResult(result:Object):void{
		if(callBack != null)callBack({data:result});//先发送数据给客户端
		if(onPost != null)onPost();//再执行下一轮
	}
	public function onFault(fault:Object):void{
		if(callBack != null)callBack({faultId:fault.faultString});
		if(onPost != null)onPost();
//		trace(String(fault.faultString));
	}
	
}


