﻿package dragonBones.textures
{
	import dragonBones.core.BaseObject;
	import dragonBones.core.DragonBones;
	
	/**
	 * @language zh_CN
	 * 贴图集数据。
	 * @see dragonBones.objects.ArmatureData
	 * @see dragonBones.Bone
	 * @see dragonBones.animation.Animation
	 * @see dragonBones.events
	 * @version DragonBones 3.0
	 */
	public class TextureAtlasData extends BaseObject
	{
		/**
		 * @private
		 */
		public var autoSearch:Boolean;
		
		/**
		 * @language zh_CN
		 * 贴图集缩放系数。
		 * @version DragonBones 4.5
		 */
		public var scale:Number;
		
		/**
		 * @private
		 */
		public var modifyScale:Number;
		
		/**
		 * @language zh_CN
		 * 贴图集名称。
		 * @version DragonBones 4.5
		 */
		public var name:String;
		
		/**
		 * @language zh_CN
		 * 贴图集图片路径。
		 * @version DragonBones 4.5
		 */
		public var imagePath:String;
		
		/**
		 * @private
		 */
		public const textures:Object = {};
		
		/**
		 * @private
		 */
		public function TextureAtlasData(self:TextureAtlasData)
		{
			super(this);
			
			if (self != this)
			{
				throw new Error(DragonBones.ABSTRACT_CLASS_ERROR);
			}
		}
		
		/**
		 * @inheritDoc
		 */
		override protected function _onClear():void
		{
			autoSearch = false;
			modifyScale = 1;
			scale = 1;
			name = null;
			imagePath = null;
			
			var i:String = null;
			
			for (i in textures)
			{
				(textures[i] as TextureData).returnToPool();
				delete textures[i];
			}
		}
		
		/**
		 * @private
		 */
		public function generateTexture():TextureData
		{
			throw new Error(DragonBones.ABSTRACT_METHOD_ERROR);
			return null;
		}
		
		/**
		 * @private
		 */
		public function addTexture(value:TextureData):void
		{
			if (value && value.name && !textures[value.name])
			{
				textures[value.name] = value;
				value.parent = this;
			}
			else
			{
				throw new ArgumentError();
			}
		}
		
		/**
		 * @private
		 */
		public function getTexture(name:String):TextureData
		{
			return textures[name] as TextureData;
		}
	}
}