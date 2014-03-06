package com.utils 
{
	import com.net.PhpNet;
	
	import flash.display.Loader;
	import flash.display.LoaderInfo;
	import flash.events.Event;
	import flash.events.IOErrorEvent;
	import flash.events.ProgressEvent;
	import flash.net.FileFilter;
	import flash.net.FileReference;
	import flash.net.FileReferenceList;
	import flash.net.URLRequest;
	import flash.utils.ByteArray;
	import flash.utils.Dictionary;

	/**
	 * 整合磁盘素材的导入 获取素材资源到内存 
	 * 将已知内存中的素材导出到硬盘中存储
	 * @author GY
	 */	
	public class UpLoadManager
	{
		/**
		 * 整合素材浏览管理器
		 */		
//		private static var fileRefer:FileReference;
		/**
		 * 素材加载完成后的回调函数
		 */		
		private static var loadCallBack:Function;
		public static const imageFilter:Array = [new FileFilter("PNG,JPG,GIF图片","*.png;*.jpg;*.gif")];
		public static const meshFilter:Array = [new FileFilter("模型文件xml,3ds,obj,zip","*.xml;*.3ds;*.obj;*.zip")];
		public static const mtlFilter:Array = [new FileFilter("mtl配置文件xml,mtl,zip","*.xml;*.mtl;*.zip")];
//		private static var xmlFilter:FileFilter = new FileFilter("xml配置文件","*.xml");
		private static var fileList:Vector.<FileReferenceList> = new Vector.<FileReferenceList>;
		
		/**
		 * 浏览文件 
		 * @param onSelect 选中后回调(文件名)
		 * @param onProgress 上传后回调(百分比)
		 * @param key 上传的附带参数
		 */		
		public static function browse(onSelect:Function,onProgress:Function = null,filter:Array = null,key:String = ''):void
		{
			if(!fileList)fileList = new Vector.<FileReferenceList>();
			//将回调函数临时存储起来 需要调用的时候使用
			saveFile(onSelect,onProgress,filter,key);
		}
		
		private static var fileDic:Dictionary;
		private static var funcDic:Dictionary;
		private static function saveFile(onSelect:Function,onProgress:Function,filter:Array,key:String):void
		{
			if(fileDic == null)fileDic = new Dictionary(true);
			if(funcDic == null)funcDic = new Dictionary(true);
			if(fileDic[onSelect] != null){
				var file:FileReferenceList = fileDic[onSelect];
			}else{
				fileDic[onSelect] = file = new FileReferenceList();
				fileList.push(file);
				funcDic[file] = new FunctionVo(onSelect,onProgress,key);
			}
			file.addEventListener(Event.SELECT,fileSelect);
			file.addEventListener(Event.CANCEL,fileCancel);
			file.browse(filter);
		}
		
		private static function fileCancel(e:Event):void
		{
			var file:FileReferenceList = e.target as FileReferenceList;
			file.removeEventListener(Event.CANCEL,fileCancel);
			var fvo:FunctionVo = funcDic[file];
			if(!fvo.isSelect){
				fileOver(file);
				trace('取消选择');
			}
		}
		public static const DEFAULT_ADDRESS:String = PhpNet.WWW_ROOT + 'upload.php';
		private static var onComplete:Function;
		private static var upLoadDic:Dictionary = new Dictionary(true);
		public static function upLoad(url:String,
									  onComplete:Function = null):void{
			UpLoadManager.onComplete = onComplete;
			for each (var file:FileReferenceList in fileList) 
			{
				var fvo:FunctionVo = funcDic[file];
				//'?kind=audi&type=s3'
				if(!fvo.isSelect)continue;//没有选中文件
				for each(var fr:FileReference in file.fileList){
					fr.upload(new URLRequest(url + fvo.key));
					fr.addEventListener(Event.COMPLETE, onUploadCompleteHandler);
					if(fvo.onProgress != null)
						fr.addEventListener(ProgressEvent.PROGRESS, onProgresshandler);
					fr.addEventListener(IOErrorEvent.IO_ERROR, ioErrorHandler);
					var pvo:ProgressVo = new ProgressVo();
					pvo.file = file;
					upLoadDic[fr] = pvo;
				}
			}
//			fileRefer.addEventListener(DataEvent.UPLOAD_COMPLETE_DATA, onUploadCompleteHandler);
		}
		/**
		 * 将所有需要上传的文件全部取消上传回话
		 */		
		public static function clear():void{
			onComplete = null;
			if(fileList == null || fileList.length == 0)return;
			for (var i:int = fileList.length - 1; i >= 0; i--) 
			{
				fileOver(fileList[i]);
			}
		}
		private static function ioErrorHandler(e:IOErrorEvent):void
		{
			trace('链接错误:' + e);
//			fileOver(e.target as FileReference);
		}
		
		private static function onProgresshandler(e:ProgressEvent):void
		{
			var fr:FileReference = e.target as FileReference;
			fr.removeEventListener(ProgressEvent.PROGRESS, onProgresshandler);
			var pvo:ProgressVo = upLoadDic[fr];//获取到加载片
			pvo.bytesLoaded = e.bytesLoaded;
			pvo.bytesTotal = e.bytesTotal;
			excuteProgress(pvo.file);
		}
		/**
		 * 显示上传百分比
		 * @param file
		 */		
		private static function excuteProgress(file:FileReferenceList):void{
			var fvo:FunctionVo = funcDic[file];
			var bytesLoaded:Number = 0;
			var bytesTotal:Number = 0;
			for each (var fr:FileReference in file.fileList) 
			{
				var pvo:ProgressVo = upLoadDic[fr];
				if(pvo == null)continue;
				bytesLoaded += pvo.bytesLoaded;
				bytesTotal += pvo.bytesTotal;
			}
			fvo.onProgress(int(bytesLoaded / bytesTotal * 100));
		}
		
		private static function onUploadCompleteHandler(e:Event):void
		{
			var fr:FileReference = e.target as FileReference;
			fr.removeEventListener(Event.COMPLETE, onUploadCompleteHandler);
			trace('上传完成' + fr.name);
			var pvo:ProgressVo = upLoadDic[fr];
//			pvo.bytesLoaded = pvo.bytesTotal;
//			return;
			delete upLoadDic[fr];//上传完成就删掉
			if(checkOver(pvo.file)){//全部上传完毕
				fileOver(pvo.file);
			}
		}
		
		private static function checkOver(file:FileReferenceList):Boolean{
			var loaderCount:int;
			for each (var fr:FileReference in file.fileList) 
			{
				var pvo:ProgressVo = upLoadDic[fr];
				if(pvo == null)continue;
				loaderCount ++;
			}
			return loaderCount == 0;//没有任何剩余资源了
		}
		
		private static function fileOver(file:FileReferenceList):void
		{
			var fvo:FunctionVo = funcDic[file];
			delete funcDic[file];
			delete fileDic[fvo.onSelect];
			var index:int = fileList.indexOf(file);
			if(index >= 0){
				fileList.splice(index,1);
			}
			if(fileList.length == 0){
				if(onComplete != null)onComplete();
				onComplete = null;
			}
		}
		
		/**
		 * 如果有选项选择了 侦听加载完成事件
		 * @param e
		 */		
		private static function fileSelect(e:Event):void
		{
			var file:FileReferenceList = e.target as FileReferenceList;
			file.removeEventListener(Event.SELECT,fileSelect);
			var fvo:FunctionVo = funcDic[file];
			fvo.isSelect = true;
			if(fvo.onSelect != null){
				var nameList:Array = [];//名字数组
				for each(var fr:FileReference in file.fileList){
					nameList.push(fr.name);
				}
				fvo.onSelect(nameList);//返回一个名字数组
			}
		}		
		/**
		 * 获取二进制格式的数据
		 * @param e
		 */		
//		private static function loadComplete(e:Event):void
//		{
//			var by:ByteArray = fileRefer.data;
////			trace(fileRefer.data);
////			var source:String = fileRefer.data
//			if(fileRefer.type == '.png' || fileRefer.type == '.jpg'){
//				var loader:Loader = new Loader();
//				loader.loadBytes(by);
//				//将二进制数据转换为视图 也是异步的
//				loader.contentLoaderInfo.addEventListener(Event.COMPLETE,loadImage);
//			}else if(fileRefer.type == '.xml'){
//				loadCallBack(by,fileRefer.name);
//			}else{
//				loadCallBack(by,fileRefer.name);
//			}
//			//contentLoaderInfo加载信息类进行素材加载
//		}		
		/**
		 * 加载完成后 从content属性中拿到素材后回调
		 * @param e
		 */		
//		private static function loadImage(e:Event):void
//		{
//			var info:LoaderInfo = e.target as LoaderInfo;
//			//先将侦听器移除 节省内存
//			info.removeEventListener(Event.COMPLETE,loadImage);
//			//取出编码好的素材在内存中
//			var bitmap:Bitmap = info.content as Bitmap;
//			//拿到加工完后的产品 进行回调
//			loadCallBack(bitmap,fileRefer.name);
//			//fileRefer.name存储目标文件名 当切割完的时候 
//			//保存的文件名前缀即fileRefer.name
//		}		
//		
//		private static var fileStream:FileStream;
//		/**
//		 * 保存图片切片
//		 * @param sheetList 切片列表
//		 * @param name 需要保存文件的前缀名
//		 */		
//		public static function saveSheetMatrix(sheetList:Vector.<Vector.<BitmapData>>,
//										 name:String):void{
//			if(!fileStream)fileStream = new FileStream();
//			for (var i:int = 0; i < sheetList.length; i++) 
//			{
//				for (var j:int = 0; j < sheetList[i].length; j++) 
//				{
//					var file:File = File.desktopDirectory.resolvePath(
//						name + "/" + name + '_' + i + '_' + j + ".png");
//					var by:ByteArray = PNGEncoder.encode(sheetList[i][j]);
//					fileStream.open(file,FileMode.WRITE);
//					fileStream.writeBytes(by);
//				}
//			}
//			fileStream.close();
//		}
//		
//		public static function saveSheetList(sheetList:Vector.<BitmapData>,
//											   name:String):void{
//			if(!fileStream)fileStream = new FileStream();
//			var length:int = sheetList.length;
//			for (var i:int = 0; i < length; i++) 
//			{
//				var file:File = File.desktopDirectory.resolvePath(
//					name + "/" + name + '_' + i + ".png");
//				var by:ByteArray = PNGEncoder.encode(sheetList[i]);
//				fileStream.open(file,FileMode.WRITE);
//				fileStream.writeBytes(by);
//			}
//			fileStream.close();
//		}
//		
//		/**
//		 * 保存图片切片
//		 * @param sheetList 切片列表
//		 * @param name 需要保存文件的前缀名
//		 */		
//		public static function saveConfigSheet(sheetList:Vector.<BitmapData>,
//										 config:XML,name:String):void{
//			if(!fileStream)fileStream = new FileStream();
//			var xmlList:XMLList = config.tx;
//			for (var i:int = 0; i < sheetList.length; i++) 
//			{
//				var fileName:String = xmlList[i].@name;
//				var file:File = File.desktopDirectory.resolvePath(
//						name + "/" + fileName);
//					var by:ByteArray = PNGEncoder.encode(sheetList[i]);
//					fileStream.open(file,FileMode.WRITE);
//					fileStream.writeBytes(by);
//			}
//			fileStream.close();
//		}
		
	}
}
import flash.net.FileReferenceList;

class FunctionVo{
	public var onSelect:Function;
	public var onProgress:Function;
	public var key:String;
	public var isSelect:Boolean;//是否已经选过文件了
	public function FunctionVo(onSelect:Function,onProgress:Function,key:String){
		this.onProgress = onProgress;
		this.onSelect = onSelect;
		this.key = key;
	}
}
class ProgressVo{
	public var file:FileReferenceList;//目标文件列表
	public var bytesLoaded:Number = 0;
	public var bytesTotal:Number = 0;
}


