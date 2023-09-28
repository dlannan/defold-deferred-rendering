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

-- render target buffer parameters
local DefaultRT_ColorParams
local DefaultRT_DepthParams

-- '--------------------------------------------------------------------------------
-- Render Manager API that is used to handle object manager pools
local RM = {}

RM.Init = function(mgr, robj)

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
	mgr.clear_color = vmath.vector4(0, 0, 0, 0)
	mgr.render_info = robj
end 

-- ' -----------------------------------------------------------------
RM.AddPass = function(mgr, msg)

	local pass = {}
	pass.name			= msg.name
	pass.material 		= msg.material
	pass.output 		= msg.output
	pass.preds 			= msg.preds
	pass.tex0 			= msg.tex0 
	pass.tex1 			= msg.tex1 
	pass.view 			= msg.view 
	pass.clear 			= msg.clear or true
	
	-- ' Some basic defaults
	pass.clearColour 	= mgr.clear_color  	-- GL_COLOR_BUFFER_BIT
	pass.clearDepth 	= 1  				-- GL_DEPTH_BUFFER_BIT
	pass.saveDepth		= -1				-- ' defines this id as invalid
	pass.enable			= 1
	pass.view 			= msg.view

	mgr.passes[msg.name] = pass
	table.insert(mgr.passlist, pass.name)
end

-- ' -----------------------------------------------------------------
RM.NewRenderTarget = function(mgr, msg)

	local color  = msg.color or { 
		format = render.FORMAT_RGBA,
		width = render.get_window_width(),
		height = render.get_window_height(),
		min_filter = render.FILTER_LINEAR,
		mag_filter = render.FILTER_LINEAR,
		u_wrap = render.WRAP_CLAMP_TO_EDGE,
		v_wrap = render.WRAP_CLAMP_TO_EDGE 
	}
	local depth = msg.depth or { 
		format = render.FORMAT_DEPTH,
		width = render.get_window_width(),
		height = render.get_window_height(),
		u_wrap = render.WRAP_CLAMP_TO_EDGE,
		v_wrap = render.WRAP_CLAMP_TO_EDGE 
	}
	
	local new_rt = render.render_target({
		[render.BUFFER_COLOR_BIT] = color, 
		[render.BUFFER_DEPTH_BIT] = depth 
	})
	
	mgr.rts[msg.name] = new_rt
end

-- ' -----------------------------------------------------------------
-- ' Allow setting the view matrix and viewport for a pass
-- '
RM.SetPassView = function(mgr, id, view )
	local pass = mgr.passes[id]
	if(pass) then 
		pass.view = view 
		mgr.passes[id] = pass
	end
end

-- ' -----------------------------------------------------------------
-- 'Final Render view settings
-- '
RM.SetRenderView = function(mgr, view )
	mgr.renderView = view 
end

-- ' -----------------------------------------------------------------

RM.GetProjection =  function(mgr)
	local rinfo = mgr.render_info
	return rinfo.projection_fn(rinfo.near, rinfo.far, rinfo.zoom)
end

-- ' -----------------------------------------------------------------
RM.AddPredicate = function(mgr, message)

	mgr.render_info:add_predicate(message.name)
end

-- ' -----------------------------------------------------------------
-- ' Main function for rendering.. all the action realy happens here.
-- '
-- ' Passes and combines are all processed here in order.
RM.RenderAll = function(mgr, renderobj)

	-- render.set_depth_mask(true)
	-- render.set_stencil_mask(0xff)
	-- render.clear({[render.BUFFER_COLOR_BIT] = mgr.clear_color, [render.BUFFER_DEPTH_BIT] = 1})
	-- render.set_viewport(0, 0, render.get_window_width(), render.get_window_height())

-- 	render.set_view(mgr.renderView.matrix)
-- 	local proj = RM.GetProjection(mgr)
-- 	render.set_projection(proj)	

	for k,v in ipairs(mgr.passlist) do
		local pass = mgr.passes[v]
		if pass then 
			local rt = nil
			if pass.output then 
				rt = mgr.rts[pass.output]
				render.set_render_target(rt)
			else 
				render.set_render_target(render.RENDER_TARGET_DEFAULT)
			end

			if pass.view then 
				render.set_view(pass.view)
			else
				render.set_view(mgr.renderView.matrix)
			end

			if pass.clear then 
				render.clear({[render.BUFFER_COLOR_BIT] = mgr.clear_color, [render.BUFFER_DEPTH_BIT] = 1})
			end
			
			if(pass.tex0) then 
				render.enable_texture(0, mgr.rts[pass.tex0], render.BUFFER_COLOR_BIT) 
			end
			if(pass.tex1) then 
				render.enable_texture(1, mgr.rts[pass.tex1], render.BUFFER_COLOR_BIT) 
			end
			
			render.enable_material(pass.material)

--			render.set_depth_mask(true)
-- 			render.set_depth_func(render.COMPARE_FUNC_LEQUAL)
-- 			render.enable_state(render.STATE_CULL_FACE)
-- 			render.enable_state(render.STATE_DEPTH_TEST)
-- 			render.disable_state(render.STATE_BLEND)

			render.draw(mgr.preds[pass.preds[1]])

			render.disable_material()

			if(pass.tex0) then render.disable_texture(0) end 
			if(pass.tex1) then render.disable_texture(1) end
			
			if rt then 
				render.set_render_target(render.RENDER_TARGET_DEFAULT)
			end
		end
	end

	render.set_view(vmath.matrix4())
end

-- This is an easier way to create a new table for an Object Manager without settings.
RM.NewRenderManager = function() 
	local mgr = {			
		rts 		= {},
		passes      = {},
		passlist 	= {},
		materials 	= {},
		preds 		= {},  -- Predicates should be mapped to their names
		render_info = nil,
	}

	mgr.view 	= vmath.matrix4()
	mgr.near	= -1
	mgr.far 	= 1
	return mgr
end 

-- An Object manager create with settings - this should normally be used.
RM.CreateNew = function() 
	local mgr = RM.NewRenderManager()
	mgr.rts			= {}
	mgr.passes		= {}
	mgr.passlist 	= {}
	mgr.materials	= {}
	
	return mgr
end

-- ' *******************************************************************************
-- Return the object manager and the generic object API

return RM 

-- ' *******************************************************************************