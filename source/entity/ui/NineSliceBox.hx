package entity.ui;

import flash.display.BitmapData;
import flash.display.Sprite;
import flash.geom.Matrix;
import flash.geom.Point;
import flash.geom.Rectangle;
import flixel.FlxSprite;
import flixel.math.FlxPoint;
import flixel.math.FlxRect;
import haxe.Log;
import openfl.Assets;

/**
 * @author Lars Doucet, Melos Han-Tani
 */
class NineSliceBox extends FlxSprite
{
	private static var bitmapsCreated:Int = 0; // for debug

	private static var _canvas:Sprite;	//drives the 9-slice drawing
	private var _bmpCanvas:BitmapData;
	
	private static var useSectionCache:Bool = true;
	private static var sectionCache:Map<String,BitmapData>;
	
	//private var _slice9:String = "";
	private var _slice9:Array<Int> = null;
	
	private var _tile:Int = TILE_NONE;			//tile neither
	private var _smooth:Bool = false;
	private var _asset_id:String = "";
	
	private var _raw_pixels:BitmapData;
	
	//for internal static use
	private static var _staticPoint:Point = new Point();
	private static var _staticRect:Rectangle = new Rectangle();
	private static var _staticRect2:Rectangle = new Rectangle();
	
	private static var _staticPointZero:Point = new Point(0, 0);	//ALWAYS 0,0
	private static var _staticMatrix:Matrix = new Matrix();
	
	private static var _staticFlxRect:FlxRect = new FlxRect(0, 0, 0, 0);
	private static var _staticFlxRect2:FlxRect = new FlxRect(0, 0, 0, 0);
	
	//specialty smoothing modes	
	public static inline var TILE_NONE:Int = 0x00;
	public static inline var TILE_BOTH:Int = 0x11;
	public static inline var TILE_H:Int = 0x10;
	public static inline var TILE_V:Int = 0x01;
	
	//rectangle map
	private static var _staticRects:Map<String,FlxRect>;
	
	/** 
	 * @param	X	X position of final sprite
	 * @param	Y	Y position of final sprite
	 * @param	Graphic	Asset
	 * @param	Rect	Width/Height of the final scaled sprite
	 * @param	slice9	[x1,y1,x2,y2] : 2 points (top left of interior, bottom right of interior + 1 pixel)
	 * @param	tile	Whether to tile the middle pieces or stretch them (default is false --> stretch)
	 * @param	smooth	When stretching, whether to smooth middle pieces (default false)
	 * @param 	id	if Graphic is a BitmapData, manually specify its original source id, if any
	 * @param   ratio	Resize ratio to force, if desired (W/H)
	 * @param
	 */
	
	public function new(X:Float, Y:Float, Graphic:Dynamic, Rect:Rectangle, Slice9:Array<Int>=null, Tile:Int=TILE_NONE, Smooth:Bool=false, Id:String="",Ratio:Float=-1,Resize_point=null) 
	{
		super(X, Y, null);
		
		_slice9 = Slice9;
		_tile = Tile;
		_smooth = Smooth;
				
		_asset_id = "";
		
		if(Std.is(Graphic,String)){
			_asset_id = Graphic;
			_raw_pixels = null;
		}else if (Std.is(Graphic, BitmapData)) {
			_asset_id = Id;
			_raw_pixels = cast Graphic;
		}
		
		resize_ratio = Ratio;
		if (Resize_point != null) {
			resize_point = Resize_point;
		}
		
		resize(Rect.width, Rect.height);
	}
	
	private var is_cut:Bool = false;
	private var cut_bottom:Bool = false;
	private var cut_paste_Pixels:Array<Int>;
	// cx = chunk x starting, then width and height. starst from bottom
	private var cut_paste_metadata:Array<Int>;
	public function cut_bottom_chunk(cx:Int, cw:Int, ch:Int,is_top:Bool=true):Void {
		if (is_cut) {
			return;
		}
		cut_paste_Pixels = new Array<Int>();
		cut_paste_metadata = [cx, cw, ch];
		
		for (_y in 1...ch+1) {
			for (_x in cx...cx + cw) {
				if (is_top == true) {
					// Cut from bottom left, going right, then up
					cut_paste_Pixels.push(this.pixels.getPixel32(_x, Std.int(height) - _y));
					this.pixels.setPixel32(_x, Std.int(height) - _y, 0x00000000);
					cut_bottom = true;
				} else {
					// Cut from top left, going right, then down
					cut_paste_Pixels.push(this.pixels.getPixel32(_x,_y-1));
					this.pixels.setPixel32(_x, _y-1, 0x00000000);
					cut_bottom = false;
				}
			}
		}
		is_cut = true;
	}
	public function paste_bottom_chunk(is_top:Bool=true):Void {
		if (!is_cut) {
			return;	
		}
		
		if (cut_bottom) {
			is_top = true;
		} else {
			is_top = false;
		}
		is_cut = false;
		var cx:Int = cut_paste_metadata[0];
		var cw:Int = cut_paste_metadata[1];
		var ch:Int = cut_paste_metadata[2];
		for (_y in 1...ch+1) {
			for (_x in cx...cx + cw) {
				if (is_top == true) {
					this.pixels.setPixel32(_x, Std.int(height) - _y, cut_paste_Pixels.shift());
				} else {
					this.pixels.setPixel32(_x, _y-1, cut_paste_Pixels.shift());
				}
			}
		}
	}
	
	public var resize_ratio(default, set):Float;
	private function set_resize_ratio(r:Float):Float { resize_ratio = r; return r;}

	public var resize_point(default, set):FlxPoint;
	private function set_resize_point(r:FlxPoint):FlxPoint { 
		if (r != null) { 
			resize_point = new FlxPoint(0, 0);
			resize_point.x = r.x;
			resize_point.y = r.y;
		}
		return resize_point; 
	}
	
	public function resize(w:Float, h:Float):Void {
		
		var old_width:Float = width;
		var old_height:Float = height;
		
		if(resize_ratio > 0){
			var effective_ratio:Float = (w / h);
			if (Math.abs(effective_ratio - resize_ratio) > 0.0001) {
				h = w * (1 / resize_ratio);
			}
		}
		
		if (_slice9 == null || _slice9 == []) {
			_slice9 = [4, 4, 7, 7];
		}
		
		if(_canvas == null){
			_canvas = new Sprite();
		}
		_canvas.graphics.clear();
		
		_bmpCanvas = new BitmapData(Std.int(w), Std.int(h));
		
		_staticFlxRect.x = 0;
		_staticFlxRect.y = 0;
		_staticFlxRect.width = w;
		_staticFlxRect.height = h;
		paintScale9(_bmpCanvas, _asset_id, _slice9, _staticFlxRect, _tile, _smooth, _raw_pixels);
		
		var iw:Int = Std.int(w); 
		if (iw < 1) { 
			iw = 1;
		}
		var ih:Int = Std.int(h); 
		if (ih < 1) { 
			ih = 1;
		}
		
		//for caching purposes:		
		var key:String = _asset_id + "_" + _slice9.join(",") + "_" + iw + "x" + ih + "_"+_tile+"_"+_smooth;
		
		myLoadGraphic(_bmpCanvas, false, _bmpCanvas.width, _bmpCanvas.height, false, key);
		
		var diff_w:Float = width - old_width;
		var diff_h:Float = height - old_height;
		
		if(resize_point != null){
			var delta_x:Float = diff_w * resize_point.x;
			var delta_y:Float = diff_h * resize_point.y;
			x -= delta_x;
			y -= delta_y;
		}
	}
	
	public static inline function getRectFromString(str:String):Rectangle{
		var coords:Array<String> = str.split(",");
		var rect:Rectangle = null;
		if(coords != null && coords.length == 4){
			var x_:Int = Std.parseInt(coords[0]);
			var y_:Int = Std.parseInt(coords[1]);
			var w_:Int = Std.parseInt(coords[2]);
			var h_:Int = Std.parseInt(coords[3]);
			rect = new Rectangle(x_,y_,w_,h_);
		}
		return rect;
	}
	
	public static inline function getRectIntsFromString(str:String):Array<Int>{
		var coords:Array<String> = str.split(",");
		if(coords != null && coords.length == 4){
			var x1:Int = Std.parseInt(coords[0]);
			var y1:Int = Std.parseInt(coords[1]);
			var x2:Int = Std.parseInt(coords[2]);
			var y2:Int = Std.parseInt(coords[3]);
			return [x1, y1, x2, y2];
		}
		return null;
	}
		
	
	//These functions were borrowed from:
	//https://github.com/ianharrigan/YAHUI/blob/master/src/yahui/style/StyleHelper.hx
	
	/**
	 * Does the actual drawing for a 9-slice scaled graphic
	 * @param	g the graphics object for drawing to (ie, sprite.graphic)
	 * @param	assetID id of bitmapdata asset you are scaling
	 * @param	scale9 int array defining 2 points that define the grid as [x1,y1,x2,y2] (upper-interior-left, lower-interior-right)
	 * @param	rc rectangle object defining how big you want to scale it to
	 * @param	tile if a bit is false, scale those pieces, if true, tile them (default both false)
	 * @param 	smooth whether to smooth when scaling or not (default false)
	 * @param 	raw raw pixels supplied, if any
	 */
	
	public static function paintScale9(g:BitmapData, assetID:String, scale9:Array<Int>, rc:FlxRect, tile:Int=TILE_NONE, smooth:Bool = false, ?raw:BitmapData):Void {
		if (scale9 != null) { // create parts
			
			var w:Int;
			var h:Int;
			if (raw == null) {
				w = Assets.getBitmapData(assetID).width;
				h = Assets.getBitmapData(assetID).height;
			}else {
				w = raw.width;
				h = raw.height;
			}
			
			var x1:Int = scale9[0];
			var y1:Int = scale9[1];
			var x2:Int = scale9[2];
			var y2:Int = scale9[3];

			if (_staticRects == null) {
				_staticRects = new Map<String,FlxRect>();
				_staticRects.set("top.left", new FlxRect(0,0,0,0));
				_staticRects.set("top", new FlxRect(0,0,0,0));
				_staticRects.set("top.right", new FlxRect(0,0,0,0));
				_staticRects.set("left", new FlxRect(0,0,0,0));
				_staticRects.set("middle", new FlxRect(0,0,0,0));
				_staticRects.set("right", new FlxRect(0,0,0,0));
				_staticRects.set("bottom.left", new FlxRect(0,0,0,0));
				_staticRects.set("bottom", new FlxRect(0,0,0,0));
				_staticRects.set("bottom.right", new FlxRect(0,0,0,0));
			}
			
			_staticRects.get("top.left").set(0, 0, x1, y1);
			_staticRects.get("top").set(x1, 0, x2-x1, y1);
			_staticRects.get("top.right").set(x2, 0, w-x2, y1);
			
			_staticRects.get("left").set(0, y1, x1, y2-y1);
			_staticRects.get("middle").set(x1, y1, x2-x1, y2-y1);
			_staticRects.get("right").set(x2, y1, w-x2, y2-y1);
			
			_staticRects.get("bottom.left").set(0, y2, x1, h-y2);
			_staticRects.get("bottom").set(x1, y2, x2-x1, h-y2);
			_staticRects.get("bottom.right").set(x2, y2, w-x2, h-y2);
			
			/*var rects:Map<String,FlxRect> = new Map<String,FlxRect>();

			rects.set("top.left", FlxRect.get(0, 0, x1, y1));
			rects.set("top", FlxRect.get(x1, 0, x2 - x1, y1));
			rects.set("top.right", FlxRect.get(x2, 0, w - x2, y1));

			rects.set("left", FlxRect.get(0, y1, x1, y2 - y1));
			rects.set("middle", FlxRect.get(x1, y1, x2 - x1, y2 - y1));
			rects.set("right", FlxRect.get(x2, y1, w - x2, y2 - y1));

			rects.set("bottom.left", FlxRect.get(0, y2, x1, h - y2));
			rects.set("bottom", FlxRect.get(x1, y2, x2 - x1, h - y2));
			rects.set("bottom.right", FlxRect.get(x2, y2, w - x2, h - y2));
			*/
			
			paintCompoundBitmap(g, assetID, _staticRects, rc, tile, smooth, raw);
		}
	}

	public static function paintCompoundBitmap(g:BitmapData, assetID:String, sourceRects:Map<String,FlxRect>, targetRect:FlxRect, tile:Int=TILE_NONE, smooth:Bool = false, raw:BitmapData=null):Void {
		var fillcolor = #if (neko) { rgb:0x00FFFFFF, a:0 }; #else 0x00FFFFFF; #end
		
		targetRect.x = Std.int(targetRect.x);
		targetRect.y = Std.int(targetRect.y);
		targetRect.width = Std.int(targetRect.width);
		targetRect.height = Std.int(targetRect.height);
		
		// top row
		var tl:FlxRect = sourceRects.get("top.left");
		if (tl != null) {
			_staticFlxRect2.set(0, 0, tl.width, tl.height);
			paintBitmapSection(g, assetID, tl, _staticFlxRect2,null,TILE_NONE,smooth,raw);
		}

		var tr:FlxRect = sourceRects.get("top.right");
		if (tr != null) {
			_staticFlxRect2.set(targetRect.width - tr.width, 0, tr.width, tr.height);
			paintBitmapSection(g, assetID, tr, _staticFlxRect2,null,TILE_NONE,smooth,raw);
		}

		var t:FlxRect = sourceRects.get("top");
		if (t != null) {
			_staticFlxRect2.set(tl.width, 0, (targetRect.width - tl.width - tr.width), t.height);
			paintBitmapSection(g, assetID, t, _staticFlxRect2,null,(tile & 0x10),smooth,raw);
		}

		// bottom row
		var bl:FlxRect = sourceRects.get("bottom.left");
		if (bl != null) {
			_staticFlxRect2.set(0, targetRect.height - bl.height, bl.width, bl.height);
			paintBitmapSection(g, assetID, bl, _staticFlxRect2,null,TILE_NONE,smooth,raw);
		}

		var br:FlxRect = sourceRects.get("bottom.right");
		if (br != null) {
			_staticFlxRect2.set(targetRect.width - br.width, targetRect.height - br.height, br.width, br.height);
			paintBitmapSection(g, assetID, br, _staticFlxRect2,null,TILE_NONE,smooth,raw);
		}

		var b:FlxRect = sourceRects.get("bottom");
		if (b != null) {
			_staticFlxRect2.set(bl.width, targetRect.height - b.height, (targetRect.width - bl.width - br.width), b.height);
			paintBitmapSection(g, assetID, b, _staticFlxRect2,null,(tile & 0x10),smooth,raw);
		}

		// middle row
		var l:FlxRect = sourceRects.get("left");
		if (l != null) {
			_staticFlxRect2.set(0, tl.height, l.width, (targetRect.height - tl.height - bl.height));
			paintBitmapSection(g, assetID, l, _staticFlxRect2,null,(tile & 0x01),smooth,raw);
		}

		var r:FlxRect = sourceRects.get("right");
		if (r != null) {
			_staticFlxRect2.set(targetRect.width - r.width, tr.height, r.width, (targetRect.height - tl.height - bl.height));
			paintBitmapSection(g, assetID, r, _staticFlxRect2,null,(tile & 0x01),smooth,raw);
		}

		var m:FlxRect = sourceRects.get("middle");
		if (m != null) {
			_staticFlxRect2.set(l.width, t.height, (targetRect.width - l.width - r.width), (targetRect.height - t.height - b.height));
			paintBitmapSection(g, assetID, m, _staticFlxRect2,null,tile,smooth,raw);
		}
	}

	public static function paintBitmapSection(g:BitmapData, assetId:String, src:FlxRect, dst:FlxRect, srcData:BitmapData = null, tile:Int = TILE_NONE, smooth:Bool = false, raw:BitmapData=null):Void {
		if (srcData == null) {
			if (raw != null) {
				srcData = raw;
			}else{
				srcData = Assets.getBitmapData(assetId);
			}
		}

		src.x = Std.int(src.x);
		src.y = Std.int(src.y);
		src.width = Std.int(src.width);
		src.height = Std.int(src.height);
		
		dst.x = Std.int(dst.x);
		dst.y = Std.int(dst.y);
		dst.width = Std.int(dst.width);
		dst.height = Std.int(dst.height);
		
		var section:BitmapData = null;
		var cacheId:String = null;
		if (useSectionCache == true && assetId != null) {
			if (sectionCache == null) {
				sectionCache = new Map<String,BitmapData>();
			}
			cacheId = assetId + "_" + src.left + "_" + src.top + "_" + src.width + "_" + src.height + "_";
			section = sectionCache.get(cacheId);
		}

		if (section == null) {
			var fillcolor = 0x00FFFFFF;
			section = new BitmapData(Std.int(src.width), Std.int(src.height), true, fillcolor);
			
			_staticRect2.x = src.x;
			_staticRect2.y = src.y;
			_staticRect2.width = src.width;
			_staticRect2.height = src.height;
			
			section.copyPixels(srcData, _staticRect2, _staticPointZero);
			
			if (useSectionCache == true && cacheId != null) {
				sectionCache.set(cacheId, section);
			}
			bitmapsCreated++;
		}

		if (dst.width > 0 && dst.height > 0) {
			
			_staticRect2.x = dst.x;
			_staticRect2.y = dst.y;
			_staticRect2.width = dst.width;
			_staticRect2.height = dst.height;
			
			bitmapFillRect(g, _staticRect2, section, tile, smooth);
		}
	}
	
	private static function bitmapFillRect(g:BitmapData, dst:Rectangle, section:BitmapData, tile:Int=TILE_NONE, smooth_:Bool=false):Void {
		
		//Optimization TODO:
		//You can remove the extra bitmap being created by smartly figuring out
		//the necessary math for drawing directly to g rather than a temp bmp
		
		//temporary bitmap data, representing the area we want to fill
		var final_pixels:BitmapData = new BitmapData(Std.int(dst.width), Std.int(dst.height),true,0x00000000);
		
		_staticMatrix.identity();
		
		//_staticRect represents the size of the section object, after any scaling is done
		_staticRect.x = 0;
		_staticRect.y = 0;
		_staticRect.width = section.width;
		_staticRect.height = section.height;
		
		if (tile & 0x10 == 0) {							//TILE H is false
			_staticMatrix.scale(dst.width / section.width, 1.0);	//scale H
			_staticRect.width = dst.width;				//_staticRect reflects scaling
		}
		if (tile & 0x01 == 0) {							//TILE V is false
			_staticMatrix.scale(1.0, dst.height / section.height);//scale V
			_staticRect.height = dst.height;			//_staticRect reflects scaling
		}
		
		//draw the first section
		//if tiling is false, this is all that needs to be done as
		//the section's h&v will exactly equal the destination size
		//final_pixels.draw(section, _staticMatrix, null, null, null, smooth);
				
		if (section.width == dst.width && section.height == dst.height) {
			_staticPoint.x = 0;
			_staticPoint.y = 0;
			final_pixels.copyPixels(section, section.rect, _staticPoint);
		}else {
			if(smooth_){
				final_pixels.draw(section, _staticMatrix, null, null, null, true);
			}else {
				final_pixels.draw(section, _staticMatrix, null, null, null, false);
			}
		}
		
		//if we are tiling, we need to keep drawing
		if (tile != TILE_NONE) {
			
			//_staticRect currently represents rect of what we've drawn so far
			
			var th:Int = tile & 0x10;
			
			if (tile & 0x10 == 0x10) {	//TILE H is true
				
				_staticPoint.x = 0;	//drawing destination
				_staticPoint.y = 0;
				
				while (_staticPoint.x < dst.width) {		//tile across the entire width
					_staticPoint.x += _staticRect.width;	//jump to next drawing location
					
					//copy section drawn so far, re-draw at next tiling point
					final_pixels.copyPixels(final_pixels, _staticRect, _staticPoint);
					
					//NOTE:
					//This method assumes that copyPixels() will safely observe
					//buffer boundaries on all targets. If this is not true, a
					//buffer overflow vunerability could exist here and would
					//need to be fixed by checking the boundary size and using
					//a custom-sized final call to fill in the last few pixels
				}
			}
			if (tile & 0x01 == 0x01) {	//TILE V is true
				
				_staticPoint.x = 0;	//drawing destination
				_staticPoint.y = 0;
				
				//assume that the entire width has been spanned by now
				_staticRect.width = final_pixels.width;	
				
				while (_staticPoint.y < dst.height) {		//tile across the entire height
					_staticPoint.y += _staticRect.height;	//jump to next drawing location
					
					//copies section drawn so far, like above, but starts with 
					//the entire first row of drawn pixels
					final_pixels.copyPixels(final_pixels, _staticRect, _staticPoint);
					
					//NOTE: 
					//See note above, same thing applies here.
				}
			}
		}
		
		//set destination point
		_staticPoint.x = dst.x;
		_staticPoint.y = dst.y;
		
		//copy the final filled area to the original target bitmap data
		g.copyPixels(final_pixels, final_pixels.rect, _staticPoint);
		
		//now that the pixels have been copied, trash the temporary bitmap data:
		//final_pixels = FlxDestroyUtil.dispose(final_pixels);
		if (final_pixels != null) {
			final_pixels.dispose();
		}
	}
}

