-- ' *******************************************************************************
-- ' Ultra Simple Render manager
-- ' ---------------------------------
--  Goal: 
--     A simple generic deferred rendering system that allows multipass
--     shader rendering of objects as well as render to target for a pass
--     and a combine phase that allow shaders to use passes and outputs as 
--     source textures to fullscreen/predicate targets material shaders.
--  
--  Example uses:
--     Simple lighting and shadow passes 
--     Post render effects like SSAO and Bloom 
--     Multiple PIP render targets 
--
--  Notes: 
--     This is going to take a while to evolve and before feature complete.
--     I hope to have initial simple PBR styled deferred rendering, with 
--     lighting, shadows, SSAO, MSAA and Bloom as a base set of features.

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

-- render target buffer parameters
local DefaultRT_ColorParams
local DefaultRT_DepthParams

-- '--------------------------------------------------------------------------------
-- Render Manager API that is used to handle object manager pools
local RM = {}

RM.Init = function(mgr)

	assert(mgr)

	DefaultRT_ColorParams = { 
		format = render.FORMAT_RGBA,
		width = render.get_window_width(),
		height = render.get_window_height(),
		min_filter = render.FILTER_LINEAR,
		mag_filter = render.FILTER_LINEAR,
		u_wrap = render.WRAP_CLAMP_TO_EDGE,
		v_wrap = render.WRAP_CLAMP_TO_EDGE 
	}
	DefaultRT_DepthParams = { 
		format = render.FORMAT_DEPTH,
		width = render.get_window_width(),
		height = render.get_window_height(),
		u_wrap = render.WRAP_CLAMP_TO_EDGE,
		v_wrap = render.WRAP_CLAMP_TO_EDGE 
	}

	-- This is an internal default clear color. This can be overridden per pass.
	mgr.clear_color = vmath.vector4(0, 0, 0, 1)
	
	--mgr.clear_color.x = sys.get_config("render.clear_color_red", 0)
	--mgr.clear_color.y = sys.get_config("render.clear_color_green", 0)
	--mgr.clear_color.z = sys.get_config("render.clear_color_blue", 0)
	--mgr.clear_color.w = sys.get_config("render.clear_color_alpha", 0)	

	-- Make predicates for passes
	for pn = 0, MAX_PASSES-1 do 
		mgr["pass_pred_"..pn] = render.predicate({"pass_"..pn})
	end

	-- Make predicates for combines
	for cn = 0, MAX_COMBINES-1 do 
		mgr["combine_pred_"..cn] = render.predicate({"combine_"..cn})
	end

	mgr["render_texture"] = render.predicate({"render_texture"})
end 

-- ' -----------------------------------------------------------------
RM.SetPassRenderTarget = function(pass, color, depth)

	if(pass == nil) then print("[Error] Invalid RenderTarget Pass index."); return end

	color = color or DefaultRT_ColorParams
	depth = depth or DefaultRT_DepthParams

	if( pass.render_target ) then render.delete_render_target( pass.render_target ) end 
	pass.render_target = render.render_target({
		[render.BUFFER_COLOR_BIT] = color, 
		[render.BUFFER_DEPTH_BIT] = depth 
	})
end

-- ' -----------------------------------------------------------------
RM.AddPass = function(mgr, msg)

	local pass = {}
	pass.shaderName		= msg.name
	-- ' Some basic defaults
	pass.clearColour 	= mgr.clear_color  	-- GL_COLOR_BUFFER_BIT
	pass.clearDepth 	= 1  				-- GL_DEPTH_BUFFER_BIT
	pass.saveDepth		= -1				-- ' defines this id as invalid
	pass.enable			= 1
	pass.view 			= msg.view

	RM.SetPassRenderTarget( pass, nil, nil )

	mgr.passes[msg.index] = pass
end

-- ' -----------------------------------------------------------------
RM.SetCombineRenderTarget = function(combine, color, depth)

	if(combine == nil) then print("[Error] Invalid RenderTarget Pass index."); return end

	color = color or DefaultRT_ColorParams
	depth = depth or DefaultRT_DepthParams

	if( combine.render_target ) then render.delete_render_target( combine.render_target ) end 
	combine.render_target = render.render_target({
		[render.BUFFER_COLOR_BIT] = color, 
		[render.BUFFER_DEPTH_BIT] = depth 
	})
end

-- ' -----------------------------------------------------------------
RM.AddCombine = function(mgr, msg)
	
	local combine = {}
	combine.shaderName 		= msg.name
	combine.src1Tex 		= msg.tex0
	combine.src2Tex 		= msg.tex1
	combine.clearColour 	= vmath.vector4(0, 0, 0, 1)
	combine.clearDepth 		= 1 -- GL_DEPTH_BUFFER_BIT
	combine.enable  		= 1
	combine.view 			= msg.view

	mgr.combines[msg.index] = combine
	RM.SetCombineRenderTarget( combine, nil, nil )
end

-- ' -----------------------------------------------------------------
-- ' Allow setting the view matrix and viewport for a pass
-- '
RM.SetPassView = function(mgr, index, view )
	local cpass = mgr.passes[index]
	if(pass) then 
		pass.view = view 
		mgr.passes[index] = pass
	end
end

-- ' -----------------------------------------------------------------
-- ' Allow setting the view matrix and viewport for a combine
-- '
RM.SetCombineView = function(mgr, index, view )
	local combine = mgr.combines[index]
	if(combine) then 
		combine.view = view 
		mgr.combines[index] = combine
	end
end

-- ' -----------------------------------------------------------------
-- 'Final Render view settings
-- '
RM.SetRenderView = function(mgr, view )
	mgr.renderView = view 
end

-- ' -----------------------------------------------------------------
-- ' Main function for rendering.. all the action realy happens here.
-- '
-- ' Passes and combines are all processed here in order.
RM.RenderAll = function(mgr, renderobj)
		
	render.set_view(renderobj.view)

	-- ' Iterate the passes that are valid in the list		
	for p=0, MAX_PASSES-1 do
		if mgr.passes[p] ~= nil then
			if mgr.passes[p].enable == 1 then
				
				-- ' This is not quite what we want.. but it will do
				local pass = mgr.passes[p]			
				-- if(pass and pass.view) then 
				-- 	local view = pass.view
				-- 	render.set_viewport(view.vp.x, view.vp.y, view.vp.width, view.vp.height)
				-- 	render.set_view(view.matrix)
				-- end				

				--if(pass.render_target) then 
					pprint(p, mgr["pass_pred_"..p])
					render.set_render_target(pass.render_target) --, { transient = { pass.clearDepth, 0 } } )
				--end 

				--render.clear({[render.BUFFER_COLOR_BIT] = vmath.vector4(0, 0, 0, 0), [render.BUFFER_DEPTH_BIT] = 1})
				render.clear({[render.BUFFER_COLOR_BIT] = pass.clearColour, [render.BUFFER_DEPTH_BIT] = pass.clearDepth})

				render.enable_material(pass.shaderName)

				render.draw(mgr["pass_pred_"..p])
			
				render.disable_material()
			
				render.set_render_target(render.RENDER_TARGET_DEFAULT)
			end 
		end
	end

	--  Combine pass outputs as required using appropriate 
	--  A queue of the combine passes. In a combine pass the queue can be referred to
	--   in the input texture as a negative number. 
	--  Combine indexes are 1 to MAX_COMBINES
	local RTQueue = {}

	if COMBINES then 

	for c=0, MAX_COMBINES-1 do
		if mgr.combines[c] ~= nil then
			if mgr.combines[c].enable == 1 then

				local combine = mgr.combines[c]
				if(combine and combine.view) then 
					local view = combine.view
					render.set_viewport(view.vp.x, view.vp.y, view.vp.z, view.vp.w)
					render.set_view(view.matrix)
				end				

				if(combine.render_target) then 
					render.set_render_target(combine.render_target) --, { transient = { combine.clearDepth, 0 } } )
				end

				render.clear({[render.BUFFER_COLOR_BIT] = combine.clearColour, [render.BUFFER_DEPTH_BIT] = combine.clearDepth})

				render.enable_material(combine.shaderName)

				if(combine.src1Tex) then 
					local texrt = nil
					if(combine.src1Tex < 0) then 
						texrt = RTQueue[-combine.src1Tex]
					else
						texrt = mgr.passes[combine.src1Tex] 
					end 
					render.enable_texture(0, texrt.render_target, render.BUFFER_COLOR_BIT)
				end 

				if(combine.src2Tex) then 
					local texrt = nil
					if(combine.src2Tex < 0) then 
						texrt = RTQueue[-combine.src2Tex]
					else
						texrt = mgr.passes[combine.src2Tex] 
					end 
					render.enable_texture(1, texrt.render_target, render.BUFFER_COLOR_BIT)
				end

				-- Generally this will be a fullscreen quad with associated combine_1 combine_2.. etc predicates
				render.draw(mgr["render_texture"])
			
				if(combine.src1Tex) then render.disable_texture(0) end
				if(combine.src2Tex) then render.disable_texture(1) end
				render.disable_material()

				if(combine.render_target) then
					RTQueue[c+1] = combine
				end

				render.set_render_target(render.RENDER_TARGET_DEFAULT)
			end
		end
	end 

	end

	if(mgr.renderView) then 
		local view = mgr.renderView
		render.set_viewport(view.vp.x, view.vp.y, view.vp.z, view.vp.w)
		render.set_view(view.matrix)
	end				

	render.set_render_target(render.RENDER_TARGET_DEFAULT)

	-- for o=0, MAX_COMBINES-1 do 
	-- 	if RTQueue[o+1] then 
	-- 		local combine =  RTQueue[o+1]
	-- 		render.enable_material("model")
	-- 		render.enable_texture(0, combine.render_target, render.BUFFER_COLOR_BIT)
	-- 		render.draw(mgr["combine_pred_"..o])
	-- 		render.disable_material()
	-- 	end
	-- end

	render.enable_material("model")
	local pass = mgr.passes[0]
	render.enable_texture(0, pass.render_target, render.BUFFER_COLOR_BIT)
	render.draw(mgr["combine_pred_0"])
	render.disable_material()
end

-- ' -----------------------------------------------------------------
-- ' Render targets to output objects
-- '
RM.RenderOutputs = function(mgr, renderobj)

end

-- This is an easier way to create a new table for an Object Manager without settings.
RM.NewRenderManager = function() 
	local mgr = {			
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
RM.CreateNew = function() 
	local mgr = RM.NewRenderManager()
	mgr.ObjectCount = 0
	mgr.objlist		= {}
	mgr.passes		= {}
	mgr.combines	= {}
	return mgr
end

-- ' *******************************************************************************
-- Return the object manager and the generic object API

return RM 

-- ' *******************************************************************************