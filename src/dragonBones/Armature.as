﻿package dragonBones
{
	import flash.events.Event;
	import flash.events.EventDispatcher;
	
	import dragonBones.animation.Animation;
	import dragonBones.animation.AnimationState;
	import dragonBones.animation.IAnimatable;
	import dragonBones.animation.TimelineState;
	import dragonBones.core.dragonBones_internal;
	import dragonBones.events.ArmatureEvent;
	import dragonBones.events.FrameEvent;
	import dragonBones.events.SoundEvent;
	import dragonBones.events.SoundEventManager;
	import dragonBones.objects.ArmatureData;
	import dragonBones.objects.Frame;

	use namespace dragonBones_internal;

	/**
	 * Dispatched when slot's zOrder changed
	 */
	[Event(name="zOrderUpdated", type="dragonBones.events.ArmatureEvent")]

	/**
	 * Dispatched when an animation state begins fade in (Even if fade in time is 0)
	 */
	[Event(name="fadeIn", type="dragonBones.events.AnimationEvent")]

	/**
	 * Dispatched when an animation state begins fade out (Even if fade out time is 0)
	 */
	[Event(name="fadeOut", type="dragonBones.events.AnimationEvent")]

	/**
	 * Dispatched when an animation state start to play(AnimationState may play when fade in start or end. It is controllable).
	 */
	[Event(name="start", type="dragonBones.events.AnimationEvent")]

	/**
	 * Dispatched when an animation state play complete (if playtimes equals to 0 means loop forever. Then this Event will not be triggered)
	 */
	[Event(name="complete", type="dragonBones.events.AnimationEvent")]

	/**
	 * Dispatched when an animation state complete a loop.
	 */
	[Event(name="loopComplete", type="dragonBones.events.AnimationEvent")]

	/**
	 * Dispatched when an animation state fade in complete.
	 */
	[Event(name="fadeInComplete", type="dragonBones.events.AnimationEvent")]

	/**
	 * Dispatched when an animation state fade out complete.
	 */
	[Event(name="fadeOutComplete", type="dragonBones.events.AnimationEvent")]

	/**
	 * Dispatched when an animation state enter a frame with animation frame event.
	 */
	[Event(name="animationFrameEvent", type="dragonBones.events.FrameEvent")]

	/**
	 * Dispatched when an bone enter a frame with animation frame event.
	 */
	[Event(name="boneFrameEvent", type="dragonBones.events.FrameEvent")]

	public class Armature extends EventDispatcher implements IAnimatable
	{
		/**
		 * The instance dispatch sound event.
		 */
		private static const _soundManager:SoundEventManager = SoundEventManager.getInstance();

		/**
		 * The name should be same with ArmatureData's name
		 */
		public var name:String;

		/**
		 * An object that can contain any user extra data.
		 */
		public var userData:Object;

		/** @private Set it to true when slot's zorder changed*/
		dragonBones_internal var _slotsZOrderChanged:Boolean;
		
		/** @private Store event needed to dispatch in current frame. When advanceTime execute complete, dispath them.*/
		dragonBones_internal var _eventList:Vector.<Event>;
		
		/** @private */
		dragonBones_internal var _armatureData:ArmatureData;
		
		/** @private Store slots based on slots' zOrder*/
		protected var _slotList:Vector.<Slot>;
		
		/** @private Store bones based on bones' hierarchy (From root to leaf)*/
		protected var _boneList:Vector.<Bone>;
		
		private var _delayDispose:Boolean;
		private var _lockDispose:Boolean;

		/** @private */
		protected var _display:Object;
		/**
		 * Armature's display object. It's instance type depends on render engine. For example "flash.display.DisplayObject" or "startling.display.DisplayObject"
		 */
		public function get display():Object
		{
			return _display;
		}

		/** @private */
		protected var _animation:Animation;
		/**
		 * An Animation instance
		 * @see dragonBones.animation.Animation
		 */
		public function get animation():Animation
		{
			return _animation;
		}
		
		/** @private */
		protected var _cacheFrameRate:int;
		public function get cacheFrameRate():int
		{
			return _cacheFrameRate;
		}
		public function set cacheFrameRate(value:int):void
		{
			if(_cacheFrameRate == value)
			{
				return;
			}
			_cacheFrameRate = value;
			
		}

		/**
		 * Creates a Armature blank instance.
		 * @param Instance type of this object varies from flash.display.DisplayObject to startling.display.DisplayObject and subclasses.
		 * @see #display
		 */
		public function Armature(display:Object)
		{
			super(this);
			_display = display;
			
			_animation = new Animation(this);
			
			_slotsZOrderChanged = false;
			
			_slotList = new Vector.<Slot>;
			_slotList.fixed = true;
			_boneList = new Vector.<Bone>;
			_boneList.fixed = true;
			_eventList = new Vector.<Event>;
			
			_delayDispose = false;
			_lockDispose = false;
			
			_armatureData = null;
			
			_cacheFrameRate = 0;
		}
		
		/**
		 * Cleans up any resources used by this instance.
		 */
		public function dispose():void
		{
			_delayDispose = true;
			if(!_animation || _lockDispose)
			{
				return;
			}
			
			userData = null;
			
			_animation.dispose();
			
			for each(var slot:Slot in _slotList)
			{
				slot.dispose();
			}
			
			for each(var bone:Bone in _boneList)
			{
				bone.dispose();
			}
			
			_slotList.fixed = false;
			_slotList.length = 0;
			_boneList.fixed = false;
			_boneList.length = 0;
			_eventList.length = 0;
			
			_armatureData = null;
			
			_animation = null;
			_slotList = null;
			_boneList = null;
			_eventList = null;
			
			//_display = null;
		}
		
		/**
		 * Force update bones and slots. (When bone's animation play complete, it will not update) 
		 */
		public function invalidUpdate(boneName:String = null):void
		{
			var bone:Bone;
			if(boneName)
			{
				bone = getBone(boneName);
				if(bone)
				{
					bone.invalidUpdate();
				}
			}
			else
			{
				for each(bone in _boneList)
				{
					bone.invalidUpdate();
				}
			}
		}
		
		/**
		 * Update the animation using this method typically in an ENTERFRAME Event or with a Timer.
		 * @param The amount of second to move the playhead ahead.
		 */
		public function advanceTime(passedTime:Number):void
		{
			_lockDispose = true;
			
			_animation.advanceTime(passedTime);
			
			passedTime *= _animation.timeScale;    //_animation's time scale will impact childArmature
			
			var i:int = _boneList.length;
			while(i --)
			{
				_boneList[i].update();
			}
			
			i = _slotList.length;
			while(i --)
			{
				var slot:Slot = _slotList[i];
				slot.update();
				if(slot._isShowDisplay)
				{
					var childArmature:Armature = slot.childArmature;
					if(childArmature)
					{
						childArmature.advanceTime(passedTime);
					}
				}
			}
			
			if(_slotsZOrderChanged)
			{
				updateSlotsZOrder();
				
				if(this.hasEventListener(ArmatureEvent.Z_ORDER_UPDATED))
				{
					this.dispatchEvent(new ArmatureEvent(ArmatureEvent.Z_ORDER_UPDATED));
				}
			}
			
			if(_eventList.length)
			{
				for each(var event:Event in _eventList)
				{
					this.dispatchEvent(event);
				}
				_eventList.length = 0;
			}
			
			_lockDispose = false;
			if(_delayDispose)
			{
				dispose();
			}
		}

		/**
		 * Get all Slot instance associated with this armature.
		 * @param if return Vector copy
		 * @return A Vector.&lt;Slot&gt; instance.
		 * @see dragonBones.Slot
		 */
		public function getSlots(returnCopy:Boolean = true):Vector.<Slot>
		{
			return returnCopy?_slotList.concat():_slotList;
		}

		/**
		 * Retrieves a Slot by name
		 * @param The name of the Bone to retrieve.
		 * @return A Slot instance or null if no Slot with that name exist.
		 * @see dragonBones.Slot
		 */
		public function getSlot(slotName:String):Slot
		{
			var i:int = _slotList.length;
			while(i --)
			{
				if(_slotList[i].name == slotName)
				{
					return _slotList[i];
				}
			}
			return null;
		}

		/**
		 * Gets the Slot associated with this DisplayObject.
		 * @param Instance type of this object varies from flash.display.DisplayObject to startling.display.DisplayObject and subclasses.
		 * @return A Slot instance or null if no Slot with that DisplayObject exist.
		 * @see dragonBones.Slot
		 */
		public function getSlotByDisplay(display:Object):Slot
		{
			if(display)
			{
				var i:int = _slotList.length;
				while(i --)
				{
					if(_slotList[i].display == display)
					{
						return _slotList[i];
					}
				}
			}
			return null;
		}
		
		/**
		 * Add a slot to a bone as child;
		 * @param a Slot instance
		 * @see dragonBones.core.DBObject
		 */
		public function addSlot(slot:Slot, parentName:String):void
		{
			if(slot.armature)
			{
				slot.armature.removeSlot(slot);
			}
			
			var slotParent:Bone;
			if(parentName)
			{
				slotParent = getBone(parentName);
				if (!slotParent)
				{
					throw new ArgumentError();
				}
			}
			
			slot.setParent(slotParent);
			slot.setArmature(this);
			
			if(_slotList.indexOf(slot) < 0)
			{
				_slotList.fixed = false;
				_slotList[_slotList.length] = slot;
				_slotList.fixed = true;
			}
			
			_slotsZOrderChanged = true;
		}

		/**
		 * Remove a Slot instance from this Armature instance.
		 * @param The Slot instance to remove.
		 * @see dragonBones.Slot
		 */
		public function removeSlot(slot:Slot):void
		{
			if(!slot)
			{
				throw new ArgumentError();
			}
			var index:int = _slotList.indexOf(slot);
			if(index >= 0)
			{
				slot.setParent(null);
				slot.setArmature(null);
				
				_slotList.fixed = false;
				_slotList.splice(index, 1);
				_slotList.fixed = true;
			}
			else
			{
				throw new ArgumentError();
			}
		}

		/**
		 * Remove a Slot instance from this Armature instance.
		 * @param The name of the Slot instance to remove.
		 * @see dragonBones.Slot
		 */
		public function removeSlotByName(slotName:String):void
		{
			if(!slotName)
			{
				return;
			}
			
			var slot:Slot = getSlot(slotName);
			if(slot)
			{
				removeSlot(slot);
			}
		}
		
		/**
		 * Get all Bone instance associated with this armature.
		 * @param if return Vector copy
		 * @return A Vector.&lt;Bone&gt; instance.
		 * @see dragonBones.Bone
		 */
		public function getBones(returnCopy:Boolean = true):Vector.<Bone>
		{
			return returnCopy?_boneList.concat():_boneList;
		}

		/**
		 * Retrieves a Bone by name
		 * @param The name of the Bone to retrieve.
		 * @return A Bone instance or null if no Bone with that name exist.
		 * @see dragonBones.Bone
		 */
		public function getBone(boneName:String):Bone
		{
			var i:int = _boneList.length;
			while(i --)
			{
				if(_boneList[i].name == boneName)
				{
					return _boneList[i];
				}
			}
			return null;
		}

		/**
		 * Gets the Bone associated with this DisplayObject.
		 * @param Instance type of this object varies from flash.display.DisplayObject to startling.display.DisplayObject and subclasses.
		 * @return A Bone instance or null if no Bone with that DisplayObject exist..
		 * @see dragonBones.Bone
		 */
		public function getBoneByDisplay(display:Object):Bone
		{
			var slot:Slot = getSlotByDisplay(display);
			return slot?slot.parent:null;
		}
		
		/**
		 * Add a Bone instance to this Armature instance.
		 * @param A Bone instance.
		 * @param (optional) The parent's name of this Bone instance.
		 * @see dragonBones.Bone
		 */
		public function addBone(bone:Bone, parentName:String = null):void
		{
			if(!bone)
			{
				throw new ArgumentError();
			}
			
			var boneParent:Bone;
			if(parentName)
			{
				boneParent = getBone(parentName);
				if (boneParent)
				{
					if(boneParent.contains(bone))
					{
						throw new ArgumentError("An Bone cannot be added as a child to itself or one of its children (or children's children, etc.)");
					}
				}
				else
				{
					throw new ArgumentError();
				}
			}
			
			if(bone.armature)
			{
				bone.armature.removeBone(bone);
			}
			
			bone.setParent(boneParent);
			bone.setArmature(this);
			
			if(_boneList.indexOf(bone) < 0)
			{
				_boneList.fixed = false;
				_boneList[_boneList.length] = bone;
				_boneList.fixed = true;
			}
			sortBoneList();
		}

		/**
		 * Remove a Bone instance from this Armature instance.
		 * @param The Bone instance to remove.
		 * @see	dragonBones.Bone
		 */
		public function removeBone(bone:Bone):void
		{
			if(!bone)
			{
				throw new ArgumentError();
			}
			var index:int = _boneList.indexOf(bone);
			if(index >= 0)
			{
				var boneParent:Bone = bone.parent;
				var i:int = _boneList.length;
				while(i --)
				{
					var eachBone:Bone = _boneList[i];
					if(eachBone.parent == bone)
					{
						eachBone.setParent(boneParent);
					}
				}
				
				i = _slotList.length;
				while(i --)
				{
					var slot:Slot = _slotList[i];
					if(slot.parent == bone)
					{
						removeSlot(slot);
					}
				}
				
				bone.setParent(null);
				bone.setArmature(null);
				
				_boneList.fixed = false;
				_boneList.splice(index, 1);
				_boneList.fixed = true;
			}
			else
			{
				throw new ArgumentError();
			}
		}

		/**
		 * Remove a Bone instance from this Armature instance.
		 * @param The name of the Bone instance to remove.
		 * @see dragonBones.Bone
		 */
		public function removeBoneByName(boneName:String):void
		{
			if(!boneName)
			{
				return;
			}
			
			var bone:Bone = getBone(boneName);
			if(bone)
			{
				removeBone(bone);
			}
		}

		/**
		 * Sort all slots based on zOrder
		 */
		public function updateSlotsZOrder():void
		{
			_slotList.fixed = false;
			_slotList.sort(sortSlot);
			_slotList.fixed = true;
			var i:int = _slotList.length;
			while(i --)
			{
				var slot:Slot = _slotList[i];
				if(slot._isShowDisplay)
				{
					slot.addDisplayToContainer(display);
				}
			}
			
			_slotsZOrderChanged = false;
		}

		private function sortBoneList():void
		{
			var i:int = _boneList.length;
			if(i == 0)
			{
				return;
			}
			var helpArray:Array = [];
			while(i --)
			{
				var level:int = 0;
				var bone:Bone = _boneList[i];
				var boneParent:Bone = bone;
				while(boneParent)
				{
					level ++;
					boneParent = boneParent.parent;
				}
				helpArray[i] = [level, bone];
			}
			
			helpArray.sortOn("0", Array.NUMERIC|Array.DESCENDING);
			
			i = helpArray.length;
			while(i --)
			{
				_boneList[i] = helpArray[i][1];
			}
			helpArray.length = 0;
		}

		/** @private When AnimationState enter a key frame, call this func*/
		dragonBones_internal function arriveAtFrame(frame:Frame, timelineState:TimelineState, animationState:AnimationState, isCross:Boolean):void
		{
			if(frame.event && this.hasEventListener(FrameEvent.ANIMATION_FRAME_EVENT))
			{
				var frameEvent:FrameEvent = new FrameEvent(FrameEvent.ANIMATION_FRAME_EVENT);
				frameEvent.animationState = animationState;
				frameEvent.frameLabel = frame.event;
				_eventList.push(frameEvent);
			}
			
			if(frame.sound && _soundManager.hasEventListener(SoundEvent.SOUND))
			{
				var soundEvent:SoundEvent = new SoundEvent(SoundEvent.SOUND);
				soundEvent.armature = this;
				soundEvent.animationState = animationState;
				soundEvent.sound = frame.sound;
				_soundManager.dispatchEvent(soundEvent);
			}
			
			//[TODO]currently there is only gotoAndPlay belongs to frame action. In future, there will be more.  
			//后续会扩展更多的action，目前只有gotoAndPlay的含义
			if(frame.action)
			{
				if(animationState.displayControl)
				{
					animation.gotoAndPlay(frame.action);
				}
			}
		}

		private function sortSlot(slot1:Slot, slot2:Slot):int
		{
			return slot1.zOrder < slot2.zOrder?1: -1;
		}

	}
}
