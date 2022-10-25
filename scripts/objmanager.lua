-- ' *******************************************************************************
-- ' Ultra Simple Model/Entity manager
-- ' ---------------------------------
-- ' Ok. Why? Well, one day or another you are going to want to organise your scene or your 'world'. 
-- ' The organisation method you choose is entirely up to you but a good way to tackle this design
-- ' problem is to make a generic 'object handler' or manager. This is an example of such a thing.
-- ' The manager's main goal is to provide a _simple_ way to retrieve and store models, and other data
-- ' in a single object structure. The object should be extensible - you should be able to later 
-- ' add scene graph management, ai management, collision management, and so on. So think carefully
-- ' HOW you do it. The method I choose these days is referential data indexes maintained in the object.
-- ' Ok, so whats that? Simply put the object or core generic structure that holds information never
-- ' holds ANY information directly (there are a couple of exceptions, but will explain later), the
-- ' information is always inferred as an index, a handle or a crc. The main reason for this is 
-- ' the ability to _easily_ extend an object without causing ramifications in other systems. 
-- ' The only data I store in an object is position and rotation (since these are core data used in
-- ' almost every system possible - your object is essentially SOMETHING at SOMEPLACE).
-- ' Referential data however may include things like:
-- '  Physics Object id
-- '  Model Identity id
-- '  Scripting id
-- '  State id
-- '  Type id
-- '  Animation id
-- ' and so on... See the Blitz forum for more detail on this.

-- ' Enum of types of objects supported
local Type_Static_Object			= 1
local Type_Static_3DSObject		    = 2
local Type_Dynamic_Object			= 3
local Type_Dynamic_3DSObject		= 4
local Type_Character				= 5
local Type_Vehicle				    = 6
local Type_Camera				    = 7

-- ' This is where our base Generic Object is defined
local GenericObject = {
	-- ' Little note. USE DOUBLE NOT FLOAT. Ok.. why? Because of scale. Unless you wish to visit
	-- ' the realm of scaling hell, use double. If you use float, your accuracy dies at 5km from 0.0
	-- ' if 1.0 represents 1m. The reason is floats are simply not accurate when they scale to large 
	-- ' sizes. If you are doing an indoor shooter, or something closed then sure use Float. But if 
	-- ' you are unsure use Double - modern CPU's have barely any difference between Double and Float
	-- ' perf (in fact most internally convert float to Double anyway!!).
	x   = 0.0, y = 0.0, z = 0.0,	        -- ' Simple position info about your object
	h = 0.0, p = 0.0, r = 0.0,	            -- ' Beware using hpr - gimbal hell!! If you can, and understand quaternions
										    -- ' use them. They will save you a huge amount of hell.
										    -- ' If there is enough want for a simple Quaternion type, I'll add it.
	
	sx = 0.0, sy = 0.0, sz = 0.0,       	-- ' Size of the object in bounding size. For this to work well, we also need
										    -- ' a pivot position, but for time being position is pivot of model!
	
	id	        = 0,    -- ' This is a CRC of the objects name (dont bother keeping strings!!! 
						-- ' They are slow, and you dont need them!
	model_id	= 0,    -- ' Will be same as normal id for the moment.
	physics_id  = 0,	-- ' If I get around to adding it :)
	state_id	= 0,    -- ' This will be useful later...
	type_id	    = 0,	-- ' Use this as much as possible - make an enum.. and use it..
	anim_id	    = 0,	-- ' Probably wont get around to it, anim is a vast area of dev on its own.

	-- ' Rendering specific information - set these masks to apply passes or not
	pass_mask	= 0     -- ' pass mask - match to index for bit. only 32 bits (passes) to play with 

	-- ' The manager will pass a crcname back to this function
	GenericObject = function(name) 
		obj = {}
		obj.x = 9999999.999999	    -- ' just make it big enough so you can recognise when something hasn't got valid data in it.
		obj.y = 9999999.999999
		obj.z = 9999999.999999	
		obj.sx = 0.0
		obj.sy = 0.0
		obj.sz = 0.0
		obj.h = 0.0
		obj.p = 0.0
		obj.r = 0.0
		obj.id = name
		obj.model_id 	= name
		obj.physics_id	= -1
		obj.type_id 	= Type_Static_Object
		return obj
    end, 
	
	AddToPass = function(pass)
		pass_mask = pass_mask | Int(2 ^ pass)
    end,

	ClearPass = function()
		pass_mask = 0
    end,
	
	-- ' Use this method to do any custom rendering passes you may want within your
	-- ' Rendering passes
	-- ' Derive the Generic class, and override this lethod with your own. 
	Render = function()
		
    end,
	
	-- ' Use this method to 'do what you want' with your object
	-- ' At a minimum you want to 'push' your position and orientation into
	-- ' your entity object (or they wont change when you render them)
	Update = function()

    end,

}

-- '--------------------------------------------------------------------------------
-- ' Simple pass type - holds output texture target, and shader number to use
local PassType = {
	outTex      = 0,
	shaderNo    = 0,
	clearColour = 0,
	clearDepth  = 0,
	saveDepth   = 0,		-- ' Save the depth buffer out to this texture id
	enable      = 0,
}

-- '--------------------------------------------------------------------------------
-- ' Simple combine type - holds input Tex1 and Tex2, Shader to use and target type
-- ' 
-- ' Target type is an Int. If it is -1 then screen is the output not a tetxure.
local CombineType = {
	outTex      = 0,
	shaderNo    = 0,
	inpTex1     = 0,
	inpTex2     = 0,
	clearColour = 0,
	clearDepth  = 0,
	enable      = 0,
}

-- '--------------------------------------------------------------------------------

local ObjectManager  = 
	MAX_PASSES 			= 6,    		-- ' Change as needed
	MAX_COMBINES 		= 6,    		-- ' Change as needed
	
	ObjectCount         = 0,
	MaxCount            = 0,   
	
	GenericObject       = {}, 
	passes              = {},
	combines            = {},
		
	AddObject = function(name, obj) 
		if self.ObjectCount + 1 >= MaxCount Then 
			return nil 
        end

		self.objlist[self.ObjectCount] = obj	-- ' Add object to list
		-- ' Do other object init here
		self.ObjectCount = self.ObjectCount + 1
		return (self.ObjectCount-1)
	end,

	GetObject = function(index)
		local obj =  self.objlist[index]
		return obj
    end,

	-- ' -----------------------------------------------------------------
	-- ' Main function for manipulating objects (physics, events, etc)
	-- '
	-- ' Objects call their owners if they exist. Use the mask to do a specific
	-- ' type of pass, so you can order your system runs.
	UpdateAll = function(objtype)
	
		local i = 0
		-- ' Two types of loops (same but test is external) - one test vs one test per obj
		if self.objlist[i] ~= nil then
			if objtype = 0 then
				for i=0, self.ObjectCount-1 do
					local tobj =  self.objlist[i]
					self.tobj:Update()
                end
		    else
				for i=0, self.ObjectCount-1 do
					local obj =  self.objlist[i]
					-- ' Only render if type is the same
					if obj.type_id = objtype then
						obj.Update
                    end
                end
			end
		end	

	end,
	
	-- ' -----------------------------------------------------------------
	AddPass = function(index, shaderno, outtex)
		local pass = {}
		pass.shaderNo = shaderno
		pass.outTex = outtex
        -- ' Some basic defaults
		pass.clearColour 	= GL_COLOR_BUFFER_BIT
		pass.clearDepth 	= GL_DEPTH_BUFFER_BIT
		pass.saveDepth		= -1	-- ' defines this id as invalid
		pass.enable			= 1
		self.passes[index] = pass
    end,

	-- ' -----------------------------------------------------------------
	PassSaveDepth = function(index, tex)
		self.passes[index].saveDepth = tex	
    end,

	-- ' -----------------------------------------------------------------
	AddCombine = function(index, shaderno, intex1, inTex2, outtex)
		Local combine = {}
		combine.shaderNo = shaderno
		combine.outTex = outtex
		combine.inpTex1 = inTex1
		combine.inpTex2 = inTex2
		combine.clearColour 	= GL_COLOR_BUFFER_BIT
		combine.clearDepth 		= GL_DEPTH_BUFFER_BIT
		combine.enable  = 1
		
        self.combines[index] = combine
    end,

	-- ' -----------------------------------------------------------------
	-- ' Main function for rendering.. all the action realy happens here.
	-- '
	-- ' Passes and combines are all processed here in order.
	RenderAll = funciton()
		local i = 0
		local c = 0
		local p = 0

		-- ' Iterate the passes that are valid in the list		
		for p=0, MAX_PASSES-1 then
			if passes[p] ~= nil then
				If passes[p].enable = 1 Then
				' This is not quite what we want.. but it will do
				Local pass:PassType = passes[p]			
				glClear (pass.clearColour | pass.clearDepth)
				
				SetShader(pass.shaderNo)
			
				For i=0 To ObjectCount-1
					If objlist[i] ~= nil Then
						Local obj:GenericObject =  objlist[i]
						' Only render if pass is set!
						If obj.pass_mask & Int(2 ^ p) > 0  Then
							obj.Render()
						End If
					End If
				Next
			
				glDisable(GL_FRAGMENT_PROGRAM_ARB)
				glDisable(GL_VERTEX_PROGRAM_ARB)
	
				SaveColourBufferTexture(pass.outTex)
				SaveDepthBufferTexture(pass.saveDepth)
				End If
			End If		
		Next
		
		' Combine pass outputs as required using appropriate shaders
		For c=0 To MAX_COMBINES-1
			If combines[c] ~= nil Then
				If combines[c].enable = 1 Then
				Local combine:CombineType = combines[c]
				glClear (combine.clearColour | combine.clearDepth)

				SetShader(combine.shaderNo)
				RenderFullScreenQuad(combine.inpTex1, combine.inpTex2)
			
				glDisable(GL_FRAGMENT_PROGRAM_ARB)
				glDisable(GL_VERTEX_PROGRAM_ARB)

				If combine.outTex> -1 Then
					SaveColourBufferTexture(combine.outTex)
				End If
				End If
			End If
		Next
	End Function
	
	Function Create:ObjectManager(maxsize) 
		Local mgr:ObjectManager = New ObjectManager 
		mgr.ObjectCount = 0
		mgr.MaxCount	= maxsize
		mgr.objlist		= New GenericObject[maxsize]
		mgr.passes		= New PassType[MAX_PASSES]
		mgr.combines	= New CombineType[MAX_COMBINES]
		Return mgr
	End	Function 

End Type 

' *******************************************************************************
