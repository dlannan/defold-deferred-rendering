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

local MAX_PASSES 		= 6    		-- ' Change as needed
local MAX_COMBINES 		= 6    		-- ' Change as needed

-- '--------------------------------------------------------------------------------
-- ' Simple pass type - holds output texture target, and shader number to use
PassType = {
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
CombineType = {
	outTex      = 0,
	shaderNo    = 0,
	inpTex1     = 0,
	inpTex2     = 0,
	clearColour = 0,
	clearDepth  = 0,
	enable      = 0,
}

-- '--------------------------------------------------------------------------------
-- Object Manager API that is used to handle object manager pools
local OM = {}

OM.Init = function(mgr)

	assert(mgr)
	-- This is an internal default clear color. This can be overridden per pass.
	mgr.clear_color = vmath.vector4(0, 0, 0, 0)
	mgr.clear_color.x = sys.get_config("render.clear_color_red", 0)
	mgr.clear_color.y = sys.get_config("render.clear_color_green", 0)
	mgr.clear_color.z = sys.get_config("render.clear_color_blue", 0)
	mgr.clear_color.w = sys.get_config("render.clear_color_alpha", 0)	

	-- Make predicates for passes
	for pn = 0, MAX_PASSES-1 do 
		mgr["pass_pred_"..pn] = render.predicate({"pass_"..pn})
	end

	-- Make predicates for combines
	for cn = 0, MAX_COMBINES-1 do 
		mgr["combine_pred_"..cn] = render.predicate({"combine_"..cn})
	end
end 

-- ' -----------------------------------------------------------------
OM.AddPass = function(mgr, index, shadername, outtex)
	local pass = {}
	pass.shaderName		= shadername
	pass.outTex 		= outtex
	-- ' Some basic defaults
	pass.clearColour 	= OM.clear_color  -- GL_COLOR_BUFFER_BIT
	pass.clearDepth 	= 1  	-- GL_DEPTH_BUFFER_BIT
	pass.saveDepth		= -1	-- ' defines this id as invalid
	pass.enable			= 1


	if( outtex == nil ) then 
		pass.render_target = render.RENDER_TARGET_DEFAULT
	else 
		-- render target buffer parameters
		local color_params = { format = render.FORMAT_RGBA,
							width = render.get_window_width(),
							height = render.get_window_height(),
							min_filter = render.FILTER_LINEAR,
							mag_filter = render.FILTER_LINEAR,
							u_wrap = render.WRAP_CLAMP_TO_EDGE,
							v_wrap = render.WRAP_CLAMP_TO_EDGE }
		local depth_params = { format = render.FORMAT_DEPTH,
							width = render.get_window_width(),
							height = render.get_window_height(),
							u_wrap = render.WRAP_CLAMP_TO_EDGE,
							v_wrap = render.WRAP_CLAMP_TO_EDGE }
		pass.render_target = render.render_target({[render.BUFFER_COLOR_BIT] = color_params, [render.BUFFER_DEPTH_BIT] = depth_params })
	end 

	mgr.passes[index] = pass
end

-- ' -----------------------------------------------------------------
OM.AddCombine = function(mgr, index, shadername, src1, src2, outtex)
	local combine = {}
	combine.shaderName = shadername
	combine.outTex = outtex
	combine.src1Tex = src1 
	combine.src2Tex = src2 
	combine.clearColour 	= OM.clear_color -- GL_COLOR_BUFFER_BIT
	combine.clearDepth 		= 1 -- GL_DEPTH_BUFFER_BIT
	combine.enable  = 1

	if( outtex == nil ) then 
		combine.render_target = render.RENDER_TARGET_DEFAULT
	else 
		-- render target buffer parameters
		local color_params = { format = render.FORMAT_RGBA,
							width = render.get_window_width(),
							height = render.get_window_height(),
							min_filter = render.FILTER_LINEAR,
							mag_filter = render.FILTER_LINEAR,
							u_wrap = render.WRAP_CLAMP_TO_EDGE,
							v_wrap = render.WRAP_CLAMP_TO_EDGE }
		local depth_params = { format = render.FORMAT_DEPTH,
							width = render.get_window_width(),
							height = render.get_window_height(),
							u_wrap = render.WRAP_CLAMP_TO_EDGE,
							v_wrap = render.WRAP_CLAMP_TO_EDGE }
		combine.render_target = render.render_target({[render.BUFFER_COLOR_BIT] = color_params, [render.BUFFER_DEPTH_BIT] = depth_params })
	end 

	mgr.combines[index] = combine
end

-- ' -----------------------------------------------------------------
-- ' Main function for rendering.. all the action realy happens here.
-- '
-- ' Passes and combines are all processed here in order.
OM.RenderAll = function(mgr)

	-- ' Iterate the passes that are valid in the list		
	for p=0, MAX_PASSES-1 do
		if mgr.passes[p] ~= nil then
			if mgr.passes[p].enable == 1 then
				-- ' This is not quite what we want.. but it will do
				local pass = mgr.passes[p]			

				if(pass.render_target ~= render.RENDER_TARGET_DEFAULT) then 
					render.set_render_target(pass.render_target) --, { transient = { pass.clearDepth, 0 } } )
				end 

				render.clear({[render.BUFFER_COLOR_BIT] = vmath.vector4(1, 0, 0, 0), [render.BUFFER_DEPTH_BIT] = 1})
				-- render.clear({[render.BUFFER_COLOR_BIT] = pass.clearColour, [render.BUFFER_DEPTH_BIT] = pass.clearDepth, [render.BUFFER_STENCIL_BIT] = 0})

				render.enable_material(pass.shaderName)

				-- glClear (pass.clearColour | pass.clearDepth)
				--render.clear({[render.BUFFER_COLOR_BIT] = pass.clearColour, [render.BUFFER_DEPTH_BIT] = pass.clearDepth, [render.BUFFER_STENCIL_BIT] = 0})
				
				-- SetShader(pass.shaderNo)

				render.draw(mgr["pass_pred_"..p])
			
				render.disable_material()
			
				-- glDisable(GL_FRAGMENT_PROGRAM_ARB)
				-- glDisable(GL_VERTEX_PROGRAM_ARB)
	
				-- SaveColourBufferTexture(pass.outTex)
				-- SaveDepthBufferTexture(pass.saveDepth)

				-- render.set_render_target(render.RENDER_TARGET_DEFAULT)
			end 
		end
	end
	render.set_render_target(render.RENDER_TARGET_DEFAULT)

	-- ' Combine pass outputs as required using appropriate shaders
	for c=0, MAX_COMBINES-1 do
		if mgr.combines[c] ~= nil then
			if mgr.combines[c].enable == 1 then
				local combine = mgr.combines[c]

				if(combine.render_target ~= render.RENDER_TARGET_DEFAULT) then 
					render.set_render_target(combine.render_target, { transient = { combine.clearDepth, 0 } } )
				end

				-- render.clear({[render.BUFFER_COLOR_BIT] = vmath.vector4(0, 0, 0, 0), [render.BUFFER_DEPTH_BIT] = 1})
				-- render.clear({[render.BUFFER_COLOR_BIT] = combine.clearColour, [render.BUFFER_DEPTH_BIT] = combine.clearDepth, [render.BUFFER_STENCIL_BIT] = 0})

				-- SetShader(combine.shaderNo)
				render.enable_material(combine.shaderName)

				-- glClear (combine.clearColour | combine.clearDepth)

				if(combine.src1Tex) then 
					local pass = mgr.passes[combine.src1Tex]
					render.enable_texture(0, pass.render_target, render.BUFFER_COLOR_BIT)
				end 
				if(combine.src2Tex) then 
					local pass = mgr.passes[combine.src2Tex]
					render.enable_texture(1, pass.render_target, render.BUFFER_COLOR_BIT)
				end

				-- RenderFullScreenQuad(combine.inpTex1, combine.inpTex2)
				render.draw(mgr["combine_pred_0"])
			

				if(combine.src1Tex) then render.disable_texture(0) end
				if(combine.src2Tex) then render.disable_texture(1) end
				render.disable_material()

				-- glDisable(GL_FRAGMENT_PROGRAM_ARB)
				-- glDisable(GL_VERTEX_PROGRAM_ARB)

				-- if combine.outTex > -1 then
				-- 	SaveColourBufferTexture(combine.outTex)
				-- end 
			end
		end
	end 
	render.set_render_target(render.RENDER_TARGET_DEFAULT)
end

-- This is an easier way to create a new table for an Object Manager without settings.
OM.NewObjectManager = function() 
	local mgr = {		
		ObjectCount         = 0,
		MaxCount            = 0,   
		
		objlist       		= {}, 
		passes              = {},
		combines            = {},
	}

	mgr.view 	= vmath.matrix4()
	mgr.near	= -1
	mgr.far 	= 1
	return mgr
end 

-- An Object manager create with settings - this should normally be used.
OM.CreateNew = function(maxsize) 
	local mgr = OM.NewObjectManager()
	mgr.ObjectCount = 0
	mgr.MaxCount	= maxsize
	mgr.objlist		= {}
	mgr.passes		= {}
	mgr.combines	= {}
	return mgr
end

-- ' *******************************************************************************
-- Return the object manager and the generic object API

return OM 

-- ' *******************************************************************************