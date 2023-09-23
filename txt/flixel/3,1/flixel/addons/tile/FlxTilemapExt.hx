package flixel.addons.tile;

import flash.display.BitmapData;
import flash.geom.Matrix;
import flash.geom.Point;
import flash.geom.Rectangle;
import flixel.addons.tile.FlxTilemapExt;
import flixel.addons.tile.FlxTileSpecial;
import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxObject;
import flixel.system.layer.DrawStackItem;
import flixel.tile.FlxTile;
import flixel.tile.FlxTilemap;
import flixel.tile.FlxTilemapBuffer;
import flixel.util.FlxMath;
import flixel.util.FlxPoint;


/**
 * Extended <code>FlxTilemap</code> class that provides collision detection against slopes
 * Based on the original by Dirk Bunk.
 * ---
 * Also add support to flipped / rotated tiles.
 * @author Peter Christiansen
 * @author MrCdK
 * @link https://github.com/TheTurnipMaster/SlopeDemo
 */
class FlxTilemapExt extends FlxTilemap
{
	inline static public var SLOPE_FLOOR_LEFT:Int = 0;
	inline static public var SLOPE_FLOOR_RIGHT:Int = 1;
	inline static public var SLOPE_CEIL_LEFT:Int = 2;
	inline static public var SLOPE_CEIL_RIGHT:Int = 3;
	
	// Slope related variables
	private var _snapping:Int = 2;
	private var _slopePoint:FlxPoint;
	private var _objPoint:FlxPoint;
	
	private var _slopeFloorLeft:Array<Int>;
	private var _slopeFloorRight:Array<Int>;
	private var _slopeCeilLeft:Array<Int>;
	private var _slopeCeilRight:Array<Int>;
	private var gentleSlopeFloorLeft:Array<Int>;
	private var gentleSlopeFloorRight:Array<Int>;
	
	// Animated and flipped tiles related variables
	private var MATRIX:Matrix;
	private var _specialTiles:Array<FlxTileSpecial>;
	
	// Alpha stuff
	#if flash
	private var _flashAlpha:BitmapData;
	private var _flashAlphaPoint:Point;
	#end
	public var alpha(default, set):Float = 1.0;
	
	public function set_alpha(alpha:Float):Float 
	{
		this.alpha = alpha;
		#if flash
		if (_tileWidth == 0 || _tileHeight == 0) 
		{
			throw "You can't set the alpha of the tilemap before loading it";
		}
		var alphaCol:Int = (Math.floor(alpha * 255) << 24);
		_flashAlpha = new BitmapData(_tileWidth, _tileHeight, true, alphaCol);
		_flashAlphaPoint = new Point(0, 0);
		#end
		
		return alpha;
	}
	
	public function new()
	{
		super();
		
		_slopePoint = new FlxPoint();
		_objPoint = new FlxPoint();
		
		_slopeFloorLeft = new Array<Int>();
		_slopeFloorRight = new Array<Int>();
		_slopeCeilLeft = new Array<Int>();
		_slopeCeilRight = new Array<Int>();
		
	  gentleSlopeFloorLeft = new Array<Int>();
	 gentleSlopeFloorRight = new Array<Int>();
	
		// Flipped/rotated tiles variables
		_specialTiles = null;
		MATRIX = new Matrix();
	}
	
	override public function destroy():Void 
	{
		_slopePoint = null;
		_objPoint = null;
		
		_slopeFloorLeft = null;
		_slopeFloorRight = null;
		_slopeCeilLeft = null;
		_slopeCeilRight = null;
		
		super.destroy();
		
		if (_specialTiles != null) 
		{
			for (t in _specialTiles) 
			{
				if (t != null)
				{
					t.destroy();
				}
			}
		}
		_specialTiles = null;
		MATRIX = null;
		
		#if flash
		if (_flashAlpha != null)
		{
			_flashAlpha.dispose();
		}
		_flashAlpha = null;
		_flashAlphaPoint = null;
		#end
	}
	
	override public function update():Void 
	{
		super.update();
		if (_specialTiles != null && _specialTiles.length > 0) 
		{
			for (t in _specialTiles) 
			{
				if (t != null && t.hasAnimation()) 
				{
					t.update();
				}
			}
		}
	}
	
	/**
	 * THIS IS A COPY FROM <code>FlxTilemap</code> BUT IT DEALS WITH FLIPPED AND ROTATED TILES
	 * Internal function that actually renders the tilemap to the tilemap buffer.  Called by draw().
	 * @param	Buffer		The <code>FlxTilemapBuffer</code> you are rendering to.
	 * @param	Camera		The related <code>FlxCamera</code>, mainly for scroll values.
	 */
	override private function drawTilemap(Buffer:FlxTilemapBuffer, Camera:FlxCamera):Void 
	{
		#if flash
		Buffer.fill();
		#else
		
		_helperPoint.x = x - Camera.scroll.x * scrollFactor.x; //copied from getScreenXY()
		_helperPoint.y = y - Camera.scroll.y * scrollFactor.y;
		
		var tileID:Int;
		var drawX:Float;
		var drawY:Float;
		
		#if !js
		var drawItem:DrawStackItem = Camera.getDrawStackItem(cachedGraphics, false, 0);
		#else
		var drawItem:DrawStackItem = Camera.getDrawStackItem(cachedGraphics, false);
		#end
		var currDrawData:Array<Float> = drawItem.drawData;
		var currIndex:Int = drawItem.position;
		#end
		
		// Copy tile images into the tile buffer
		_point.x = (Camera.scroll.x * scrollFactor.x) - x; //modified from getScreenXY()
		_point.y = (Camera.scroll.y * scrollFactor.y) - y;
		var screenXInTiles:Int = Math.floor(_point.x / _tileWidth);
		var screenYInTiles:Int = Math.floor(_point.y / _tileHeight);
		var screenRows:Int = Buffer.rows;
		var screenColumns:Int = Buffer.columns;
		
		// Bound the upper left corner
		if (screenXInTiles < 0)
		{
			screenXInTiles = 0;
		}
		if (screenXInTiles > widthInTiles - screenColumns)
		{
			screenXInTiles = widthInTiles - screenColumns;
		}
		if (screenYInTiles < 0)
		{
			screenYInTiles = 0;
		}
		if (screenYInTiles > heightInTiles - screenRows)
		{
			screenYInTiles = heightInTiles - screenRows;
		}
		
		var rowIndex:Int = screenYInTiles * widthInTiles + screenXInTiles;
		_flashPoint.y = 0;
		var row:Int = 0;
		var column:Int;
		var columnIndex:Int;
		var tile:FlxTile;
		var special:FlxTileSpecial;

		#if !FLX_NO_DEBUG
		var debugTile:BitmapData;
		#end 
		
		var isSpecial = false;
		
		while (row < screenRows)
		{
			columnIndex = rowIndex;
			column = 0;
			_flashPoint.x = 0;
			
			while (column < screenColumns)
			{
				#if flash
				_flashRect = _rects[columnIndex];
				
				if (_flashRect != null)
				{
					if (_specialTiles != null && _specialTiles[columnIndex] != null) 
					{
						special = _specialTiles[columnIndex];
						isSpecial = special.isSpecial();
						if (isSpecial) 
						{
							Buffer.pixels.copyPixels(
								special.getBitmapData(_tileWidth, _tileHeight, _flashRect, cachedGraphics.bitmap),
								special.tileRect,
								_flashPoint, _flashAlpha, _flashAlphaPoint, true);
							
							Buffer.dirty = (special.dirty || Buffer.dirty);
						}
					} 
					
					if (!isSpecial) 
					{
						Buffer.pixels.copyPixels(cachedGraphics.bitmap, _flashRect, _flashPoint, _flashAlpha, _flashAlphaPoint, true);
					} 
					else 
					{
						isSpecial = false;
					}
					
					#if !FLX_NO_DEBUG
					if (FlxG.debugger.visualDebug && !ignoreDrawDebug) 
					{
						tile = _tileObjects[_data[columnIndex]];
						
						if (tile != null)
						{
							if (tile.allowCollisions <= FlxObject.NONE)
							{
								// Blue
								debugTile = _debugTileNotSolid; 
							}
							else if (tile.allowCollisions != FlxObject.ANY)
							{
								// Pink
								debugTile = _debugTilePartial; 
							}
							else
							{
								// Green
								debugTile = _debugTileSolid; 
							}
							
							Buffer.pixels.copyPixels(debugTile, _debugRect, _flashPoint, null, null, true);
						}
					}
					#end
				}
				#else
				tileID = _rectIDs[columnIndex];
				
				if (tileID != -1)
				{
					if (_specialTiles != null) 
					{
						special = _specialTiles[columnIndex];
					} 
					else 
					{
						special = null;
					}
					
					MATRIX.identity();
					
					if (special != null && special.isSpecial()) 
					{
						MATRIX = special.getMatrix(_tileWidth, _tileHeight);
						tileID = special.getCurrentTileId() - _startingIndex;
					}
					
					drawX = _helperPoint.x + (columnIndex % widthInTiles) * _tileWidth;
					drawY = _helperPoint.y + Math.floor(columnIndex / widthInTiles) * _tileHeight;
					
					drawX += MATRIX.tx;
					drawY += MATRIX.ty;
					
					#if !js
					currDrawData[currIndex++] = Math.floor(drawX) + 0.01;
					currDrawData[currIndex++] = Math.floor(drawY) + 0.01;
					#else
					currDrawData[currIndex++] = Math.floor(drawX);
					currDrawData[currIndex++] = Math.floor(drawY);
					#end
					currDrawData[currIndex++] = tileID;
					
					
					currDrawData[currIndex++] = MATRIX.a; 
					currDrawData[currIndex++] = MATRIX.b;
					currDrawData[currIndex++] = MATRIX.c;
					currDrawData[currIndex++] = MATRIX.d; 
					
					#if !js
					// Alpha
					currDrawData[currIndex++] = alpha; 
					#end
				}
				#end
				
				_flashPoint.x += _tileWidth;
				column++;
				columnIndex++;
			}
			
			rowIndex += widthInTiles;
			_flashPoint.y += _tileHeight;
			row++;
		}
		
		#if !flash
		drawItem.position = currIndex;
		#end
		
		Buffer.x = screenXInTiles * _tileWidth;
		Buffer.y = screenYInTiles * _tileHeight;
	}
	
	/**
	 * Set the special tiles (rotated or flipped)
	 * @param	tiles	An <code>Array</code> with all the <code>FlxTileSpecial</code>
	 */
	public function setSpecialTiles(tiles:Array<FlxTileSpecial>):Void 
	{
		_specialTiles = new Array<FlxTileSpecial>();

		#if flash
		var animIds:Array<Int>;
		#end
		var t:FlxTileSpecial;
		for (i in 0...tiles.length) 
		{
			t = tiles[i];
			if (t != null && t.isSpecial()) 
			{
				_specialTiles[i] = t;
				
				#if flash
				// Update the tile animRects with the animation
				if (t.hasAnimation()) 
				{
					animIds = t.getAnimationTilesId();
					if (animIds != null) 
					{
						var rectangles:Array<Rectangle> = new Array<Rectangle>();
						var rectangle:Rectangle;
						for (id in animIds) 
						{
							rectangle = getRectangleFromTileset(id);
							if (rectangle != null) 
							{
								rectangles.push(rectangle);
							}
						}
						if (rectangles.length > 0) 
						{
							t.setAnimationRects(rectangles);
						}
					}
				}				
				#end
			} 
			else 
			{
				_specialTiles[i] = null;
			}
		}
	}
	
	private function getRectangleFromTileset(id:Int):Rectangle 
	{
		// Copied from FlxTilemap updateTile()
		var tile:FlxTile = _tileObjects[id];
		if (tile != null) 
		{
			var rx:Int = (id - _startingIndex) * (_tileWidth + region.spacingX);
			var ry:Int = 0;
		
			if (Std.int(rx) >= region.width)
			{
				ry = Std.int(rx / region.width) * (_tileHeight + region.spacingY);
				rx %= region.width;
			}
			
			return new Rectangle(rx + region.startX, ry + region.startY, _tileWidth, _tileHeight);
		}
		return null;
	}
	
	/**
	 * THIS IS A COPY FROM <code>FlxTilemap</code>
	 * I've only swapped lines 386 and 387 to give DrawTilemap() a chance to set the buffer dirty
	 * ---
	 * Draws the tilemap buffers to the cameras.
	 */
	override public function draw():Void
	{
		if (cameras == null)
		{
			cameras = FlxG.cameras.list;
		}
		
		var camera:FlxCamera;
		var buffer:FlxTilemapBuffer;
		var i:Int = 0;
		var l:Int = cameras.length;
		
		while (i < l)
		{
			camera = cameras[i];
			
			if (!camera.visible || !camera.exists)
			{
				continue;
			}
			
			if (_buffers[i] == null)
			{
				_buffers[i] = new FlxTilemapBuffer(_tileWidth, _tileHeight, widthInTiles, heightInTiles, camera);
				_buffers[i].forceComplexRender = forceComplexRender;
			}
			
			buffer = _buffers[i++];
			
			#if flash
			if (!buffer.dirty)
			{
				// Copied from getScreenXY()
				_point.x = x - (camera.scroll.x * scrollFactor.x) + buffer.x; 
				_point.y = y - (camera.scroll.y * scrollFactor.y) + buffer.y;
				buffer.dirty = (_point.x > 0) || (_point.y > 0) || (_point.x + buffer.width < camera.width) || (_point.y + buffer.height < camera.height);
			}
			
			if (buffer.dirty)
			{
				buffer.dirty = false;
				drawTilemap(buffer, camera);
			}
			
			// Copied from getScreenXY()
			_flashPoint.x = x - (camera.scroll.x * scrollFactor.x) + buffer.x; 
			_flashPoint.y = y - (camera.scroll.y * scrollFactor.y) + buffer.y;
			buffer.draw(camera, _flashPoint);
			
			#else
			drawTilemap(buffer, camera);
			#end
			
			#if !FLX_NO_DEBUG
			FlxBasic._VISIBLECOUNT++;
			#end
		}
	}

	/**
	 * THIS IS A COPY FROM <code>FlxTilemap</code> BUT IT SOLVES SLOPE COLLISION TOO
	 * Checks if the Object overlaps any tiles with any collision flags set,
	 * and calls the specified callback function (if there is one).
	 * Also calls the tile's registered callback if the filter matches.
	 *
	 * @param 	Object 				The <code>FlxObject</code> you are checking for overlaps against.
	 * @param 	Callback 			An optional function that takes the form "myCallback(Object1:FlxObject,Object2:FlxObject)", where Object1 is a FlxTile object, and Object2 is the object passed in in the first parameter of this method.
	 * @param 	FlipCallbackParams 	Used to preserve A-B list ordering from FlxObject.separate() - returns the FlxTile object as the second parameter instead.
	 * @param 	Position 			Optional, specify a custom position for the tilemap (useful for overlapsAt()-type funcitonality).
	 *
	 * @return Whether there were overlaps, or if a callback was specified, whatever the return value of the callback was.
	 */
	override public function overlapsWithCallback(Object:FlxObject, ?Callback:FlxObject->FlxObject->Bool, FlipCallbackParams:Bool = false, ?Position:FlxPoint):Bool
	{
		var results:Bool = false;
		
		var X:Float = x;
		var Y:Float = y;
		
		if (Position != null)
		{
			X = Position.x;
			Y = Position.y;
		}
		
		//Figure out what tiles we need to check against
		var selectionX:Int = Math.floor((Object.x - X) / _tileWidth);
		var selectionY:Int = Math.floor((Object.y - Y) / _tileHeight);
		var selectionWidth:Int = selectionX + (Math.ceil(Object.width / _tileWidth)) + 1;
		var selectionHeight:Int = selectionY + Math.ceil(Object.height / _tileHeight) + 1;
		
		//Then bound these coordinates by the map edges
		if (selectionX < 0)
		{
			selectionX = 0;
		}
		if (selectionY < 0)
		{
			selectionY = 0;
		}
		if (selectionWidth > widthInTiles)
		{
			selectionWidth = widthInTiles;
		}
		if (selectionHeight > heightInTiles)
		{
			selectionHeight = heightInTiles;
		}
		
		// Then loop through this selection of tiles and call FlxObject.separate() accordingly
		var rowStart:Int = selectionY * widthInTiles;
		var row:Int = selectionY;
		var column:Int;
		var tile:FlxTile;
		var overlapFound:Bool;
		var deltaX:Float = X - last.x;
		var deltaY:Float = Y - last.y;
		
		while (row < selectionHeight)
		{
			column = selectionX;
			
			while (column < selectionWidth)
			{
				overlapFound = false;
				tile = _tileObjects[_data[rowStart + column]];
				
				if (tile.allowCollisions != 0)
				{
					tile.x = X + column * _tileWidth;
					tile.y = Y + row * _tileHeight;
					tile.last.x = tile.x - deltaX;
					tile.last.y = tile.y - deltaY;
					
					if (Callback != null)
					{
						if (FlipCallbackParams)
						{
							overlapFound = Callback(Object, tile);
						}
						else
						{
							overlapFound = Callback(tile, Object);
						}
					}
					else
					{
						overlapFound = (Object.x + Object.width > tile.x) && (Object.x < tile.x + tile.width) && (Object.y + Object.height > tile.y) && (Object.y < tile.y + tile.height);
					}
					
					// Solve slope collisions if no overlap was found
					/*
					if (overlapFound
						|| (!overlapFound && (tile.index == SLOPE_FLOOR_LEFT || tile.index == SLOPE_FLOOR_RIGHT || tile.index == SLOPE_CEIL_LEFT || tile.index == SLOPE_CEIL_RIGHT)))
					*/
					
					// New generalized slope collisions
					if (overlapFound || (!overlapFound && checkArrays(tile.index)))
					{
						if ((tile.callbackFunction != null) && ((tile.filter == null) || Std.is(Object, tile.filter)))
						{
							tile.mapIndex = rowStart + column;
							tile.callbackFunction(tile, Object);
						}
						results = true;
					}
				}
				else if ((tile.callbackFunction != null) && ((tile.filter == null) || Std.is(Object, tile.filter)))
				{
					tile.mapIndex = rowStart + column;
					tile.callbackFunction(tile, Object);
				}
				column++;
			}
			
			rowStart += widthInTiles;
			row++;
		}
		
		return results;
	}
	
	/**
	 * Sets the tiles that are treated as "clouds" or blocks that are only solid from the top.
	 * 
	 * @param 	Clouds	An array containing the numbers of the tiles to be treated as clouds.
	 */
	public function setClouds(?Clouds:Array<Int>):Void
	{
		if (Clouds != null)
		{
			for (i in 0...(Clouds.length))
			{
				setTileProperties(Clouds[i], FlxObject.CEILING);			
			}
		}
	}
	
	/**
	 * Sets the slope arrays, which define which tiles are treated as slopes.
	 * 
	 * @param 	LeftFloorSlopes 	An array containing the numbers of the tiles to be treated as left floor slopes.
	 * @param 	RightFloorSlopes	An array containing the numbers of the tiles to be treated as right floor slopes.
	 * @param 	LeftCeilSlopes		An array containing the numbers of the tiles to be treated as left ceiling slopes.
	 * @param 	RightCeilSlopes		An array containing the numbers of the tiles to be treated as right ceiling slopes.
	 */
	public function setSlopes(?LeftFloorSlopes:Array<Int>, ?RightFloorSlopes:Array<Int>, ?LeftCeilSlopes:Array<Int>, ?RightCeilSlopes:Array<Int>):Void
	{
		if (LeftFloorSlopes != null)
		{
			_slopeFloorLeft = LeftFloorSlopes;
		}
		if (RightFloorSlopes != null)
		{
			_slopeFloorRight = RightFloorSlopes;
		}
		if (LeftCeilSlopes != null)
		{
			_slopeCeilLeft = LeftCeilSlopes;
		}
		if (RightCeilSlopes != null)
		{
			_slopeCeilRight = RightCeilSlopes;
		}
		
		setSlopeProperties();
	}
	
	/**
	 * Bounds the slope point to the slope
	 * 
	 * @param 	Slope 	The slope to fix the slopePoint for
	 */
	private function fixSlopePoint(Slope:FlxTile):Void
	{
		_slopePoint.x = FlxMath.bound(_slopePoint.x, Slope.x, Slope.x + _tileWidth);
		_slopePoint.y = FlxMath.bound(_slopePoint.y, Slope.y, Slope.y + _tileHeight);
	}
	

	private function onCollideFloorSlope(slope:FlxObject, obj:FlxObject,is_lo_22:Bool	):Void
	{
		//set the object's touching flag
		obj.touching = FlxObject.FLOOR;
		obj.touching_floor_slope = true;
		
		//adjust the object's velocity
		obj.velocity.y = 0;
		
		//reposition the object
		obj.y = _slopePoint.y - obj.height;
		if (obj.y < slope.y - obj.height) { obj.y = slope.y - obj.height; };
		// TODO what if walking down big slope ugh
		if (is_lo_22 && _slopePoint.y <= slope.y + 8) {
			obj.y = slope.y - obj.height + 8;
		}
	}	
	
	/**
	 * Is called if an object collides with a ceiling slope
	 * 
	 * @param 	Slope 	The ceiling slope
	 * @param 	Object 	The object that collides with that slope
	 */
	private function onCollideCeilSlope(Slope:FlxObject, Object:FlxObject):Void
	{
		// Set the object's touching flag
		Object.touching = FlxObject.CEILING;
		
		// Adjust the object's velocity
		Object.velocity.y = 0;
		
		// Reposition the object
		Object.y = _slopePoint.y;
		
		if (Object.y > Slope.y + _tileHeight) 
		{ 
			Object.y = Slope.y + _tileHeight; 
		}
	}
	
	/**
	 * Solves collision against a left-sided floor slope
	 * 
	 * @param 	Slope 	The slope to check against
	 * @param 	Object 	The object that collides with the slope
	 */
	private function solveCollisionSlopeFloorLeft(slope:FlxObject, obj:FlxObject):Void
	{
		//calculate the corner point of the object
		//_objPoint.x = FlxU.floor(obj.x + obj.width + _snapping);
		_objPoint.x = Math.floor(obj.x + obj.width );
		_objPoint.y = Math.floor(obj.y + obj.height);
		
		//calculate position of the point on the slope that the object might overlap
		//this would be one side of the object projected onto the slope's surface
		
		// _SLOPEPOINT will be the new position of the obj's corner
		_slopePoint.x = _objPoint.x;
		var i:Int;
		var found:Bool = false;
		var is_22_lo:Bool = false;
		var ft:FlxTile = cast(slope, FlxTile);
		for (i in 0...(gentleSlopeFloorLeft.length)) {
			if (Math.abs(gentleSlopeFloorLeft[i]) == ft.index) {
				if (gentleSlopeFloorLeft[i] > 0) { // high 
					_slopePoint.y = (slope.y + _tileHeight) - (_slopePoint.x - slope.x) / 2 - _tileHeight / 2 + 1;
					_slopePoint.y = Math.floor(_slopePoint.y);
					
					found  = true;
					obj._minslopebump = 8;
					break;
				} else {// low
					// Hack, if player velocity is < 0 don't collide 
					if (obj.velocity.y < 0) return;
					_slopePoint.y = (slope.y + _tileHeight) - (_slopePoint.x - slope.x) / 2; //change
					_slopePoint.y = Math.floor(_slopePoint.y);
					is_22_lo = true;
					found = true;
					break;
				}
			}
		}
		if (!found)
		_slopePoint.y = (slope.y + _tileHeight) - (_slopePoint.x - slope.x); //change
		
		//fix the slope point to the slope tile
		fixSlopePoint(cast(slope, FlxTile));
		
		// Only snap if we are moving down it and not jumping
		
		var ysnap:Int = (obj.velocity.x < 0 && obj.velocity.y > 0) ? 4 : 0;
		_snapping = 0;
		if (_objPoint.y < slope.y) {
			return;
		}
		if (_slopePoint.y - slope.y >= 1) _slopePoint.y -- ;
		//check if the object is inside the slope
		if (_objPoint.x > slope.x  && _objPoint.x < slope.x + _tileWidth + obj.width + _snapping && _objPoint.y >= _slopePoint.y - ysnap && _objPoint.y <= slope.y + _tileHeight)
		{
			//call the collide function for the floor slope
			if (is_22_lo && obj._minslopebump == 0) {
				onCollideFloorSlope(slope, obj, is_22_lo);
			} else if (!is_22_lo){ 
				onCollideFloorSlope(slope, obj, is_22_lo);
			}
			obj.touching |= FlxObject.RIGHT;
		}
		_snapping = 2;
		
		
	}
	
	/**
	 * Solves collision against a right-sided floor slope
	 * 
	 * @param 	Slope 	The slope to check against
	 * @param 	Object 	The object that collides with the slope
	 */
	private function solveCollisionSlopeFloorRight(slope:FlxObject, obj:FlxObject):Void
	{
		//calculate the corner point of the object
		_objPoint.x = Math.floor(obj.x);
		_objPoint.y = Math.floor(obj.y + obj.height);
		
		//calculate position of the point on the slope that the object might overlap
		//this would be one side of the object projected onto the slope's surface
		_slopePoint.x = _objPoint.x;
		
		var i:Int;
		var is_22_low:Bool = false;
		var found:Bool = false;
		var ft:FlxTile = cast(slope, FlxTile);
		for (i in 0...(gentleSlopeFloorRight.length)) {
			if (Math.abs(gentleSlopeFloorRight[i]) == ft.index) {
				if (gentleSlopeFloorRight[i] > 0) { // high 
					//_slopePoint.y = (slope.y + _tileHeight) - (_slopePoint.x - slope.x) / 2 - _tileHeight / 2 + 1;
					_slopePoint.y = (slope.y) + (_slopePoint.x - slope.x) / 2;
					_slopePoint.y = Math.floor(_slopePoint.y);
					obj._minslopebump = 8;
					found  = true;
					break;
				} else {// low
					// same hack as slopeleft
					if (obj.velocity.y < 0) return;
					_slopePoint.y = (slope.y) + (_slopePoint.x - slope.x) / 2 + _tileHeight / 2;
					_slopePoint.y = Math.floor(_slopePoint.y);
					is_22_low = true;
					found = true;
					break;
				}
			}
		}
		if (!found) // then it's a 45 deg slope
		//_slopePoint.y = (slope.y + _tileHeight) - (slope.x - _slopePoint.x + _tileWidth);
		_slopePoint.y = (slope.y) + (_slopePoint.x - slope.x);
		
		//fix the slope point to the slope tile
		fixSlopePoint(cast(slope, FlxTile));
		
		// Expand snap-space of the tile if we're walking down it to allow jumping/prevent awkward bumping
		var ysnap:Int = (obj.velocity.x > 0 && obj.velocity.y > 0) ? 4 : 0;
		_snapping = 0;
		//check if the object is inside the slope
		if (_objPoint.x > slope.x - obj.width  && _objPoint.x < slope.x + _tileWidth + _snapping && _objPoint.y >= _slopePoint.y - ysnap && _objPoint.y <= slope.y + _tileHeight)
		{
			//call the collide function for the floor slope		
			if (is_22_low && obj._minslopebump == 0) {
				onCollideFloorSlope(slope, obj, is_22_low);
			} else if (!is_22_low){
				onCollideFloorSlope(slope, obj, is_22_low);
			}
			obj.touching |= FlxObject.LEFT;
		}
		_snapping = 2;
	}
	
	/**
	 * Solves collision against a left-sided ceiling slope
	 * 
	 * @param 	Slope 	The slope to check against
	 * @param 	Obj 	The object that collides with the slope
	 */
	private function solveCollisionSlopeCeilLeft(Slope:FlxObject, Obj:FlxObject):Void
	{
		// Calculate the corner point of the object
		_objPoint.x = Math.floor(Obj.x + Obj.width + _snapping);
		_objPoint.y = Math.ceil(Obj.y);
		
		// Calculate position of the point on the slope that the object might overlap
		// this would be one side of the object projected onto the slope's surface
		_slopePoint.x = _objPoint.x;
		_slopePoint.y = (Slope.y) + (_slopePoint.x - Slope.x);
		
		// Fix the slope point to the slope tile
		fixSlopePoint(cast(Slope, FlxTile));
		
		// Check if the object is inside the slope
		if (_objPoint.x > Slope.x + _snapping && _objPoint.x < Slope.x + _tileWidth + Obj.width + _snapping && _objPoint.y <= _slopePoint.y && _objPoint.y >= Slope.y)
		{
			// Call the collide function for the floor slope
			onCollideCeilSlope(Slope, Obj);
		}
	}
	
	/**
	 * Solves collision against a right-sided ceiling slope
	 * 
	 * @param 	Slope 	The slope to check against
	 * @param 	Obj 	The object that collides with the slope
	 */
	private function solveCollisionSlopeCeilRight(Slope:FlxObject, Obj:FlxObject):Void
	{
		// Calculate the corner point of the object
		_objPoint.x = Math.floor(Obj.x - _snapping);
		_objPoint.y = Math.ceil(Obj.y);
		
		// Calculate position of the point on the slope that the object might overlap
		// this would be one side of the object projected onto the slope's surface
		_slopePoint.x = _objPoint.x;
		_slopePoint.y = (Slope.y) + (Slope.x - _slopePoint.x + _tileWidth);
		
		// Fix the slope point to the slope tile
		fixSlopePoint(cast(Slope, FlxTile));
		
		// Check if the object is inside the slope
		if (_objPoint.x > Slope.x - Obj.width - _snapping && _objPoint.x < Slope.x + _tileWidth + _snapping && _objPoint.y <= _slopePoint.y && _objPoint.y >= Slope.y)
		{
			// Call the collide function for the floor slope
			onCollideCeilSlope(Slope, Obj);
		}
	}
	
	/**
	 * Internal helper function for setting the tiles currently held in the slope arrays to use slope collision.
	 * Note that if you remove items from a slope, this function will not unset the slope property.
	 */
	private function setSlopeProperties():Void
	{
		for (i in 0..._slopeFloorLeft.length)
		{
			setTileProperties(_slopeFloorLeft[i], FlxObject.RIGHT | FlxObject.FLOOR, solveCollisionSlopeFloorLeft);			
		}
		for (i in 0..._slopeFloorRight.length)
		{
			setTileProperties(_slopeFloorRight[i], FlxObject.LEFT | FlxObject.FLOOR, solveCollisionSlopeFloorRight);
		}
		for (i in 0..._slopeCeilLeft.length)
		{
			setTileProperties(_slopeCeilLeft[i], FlxObject.RIGHT | FlxObject.CEILING, solveCollisionSlopeCeilLeft);			
		}
		for (i in 0..._slopeCeilRight.length)
		{
			setTileProperties(_slopeCeilRight[i], FlxObject.LEFT | FlxObject.CEILING, solveCollisionSlopeCeilRight);
		}
	}
	public function setGentleSlopeProperties(left:Array<Int>,right:Array<Int>):Void
	{
		gentleSlopeFloorLeft = left;
		gentleSlopeFloorRight = right;
		var i:Int;
		for (i in 0...(left.length)) {
			if (left[i] < 0) {
				_tileObjects[Math.floor(Math.abs(left[i]))].isLowSlope = true;
			}
		}
		for (i in 0... (right.length)) {
			if (right[i] < 0) {
				_tileObjects[Math.floor(Math.abs(right[i]))].isLowSlope = true;
			}
		}
	}
	
	
	/**
	 * Internal helper function for comparing a tile to the slope arrays to see if a tile should be treated as a slope.
	 * 
	 * @param 	TileIndex	The Tile Index number of the Tile you want to check.
	 * @return	Returns true if the tile is listed in one of the slope arrays. Otherwise returns false.
	 */
	private function checkArrays(TileIndex:Int):Bool
	{
		for (i in 0..._slopeFloorLeft.length)
		{
			if (_slopeFloorLeft[i] == TileIndex)
			{
				return true;
			}
		}	
		for (i in 0..._slopeFloorRight.length)
		{
			if (_slopeFloorRight[i] == TileIndex)
			{
				return true;
			}
		}	
		for (i in 0..._slopeCeilLeft.length)
		{
			if (_slopeCeilLeft[i] == TileIndex)
			{
				return true;
			}
		}	
		for (i in 0..._slopeCeilRight.length)
		{
			if (_slopeCeilRight[i] == TileIndex)
			{
				return true;
			}
		}	
		
		return false;
	}
}