
-- ' Custom Objects - derived from the base Generic Object
-- '--------------------------------------------------------------------------------
-- ' Mainly for use with 3DS objects

local GO = require( "scripts.genericobj" )

MO = {}

MO.NewModelObject = function()
	
	local ModelObject = {

		saveMatrix      = nil,
		ox = 0.0, oy = 0.0, oz = 0.0,
		oh = 0.0, op = 0.0, orr = 0.0,
	}
	return GO.NewGenericObject( ModelObject )
end 

MO.CreateNew = function(name, filename)
	local newobj = MO.NewModelObject()
	print( "here1" )
	newobj.Create(MakeCRC3DS(name))
	print( "here2" )
	newobj.model_id 	= LoadModel3DS(name, filename)			-- ' Load in the mesh
	print( "here3" )
	newobj.type_id 		= ObjectType.Static_3DSObject
	newobj.physics_id 	= -1
	newobj.saveMatrix 	= true
	return newobj
end

MO.Update = function( mobj )
	if mobj.saveMatrix then
		mobj.ox = mobj.x
		mobj.oy = mobj.y 
		mobj.oz = mobj.z
		mobj.oh = mobj.h
		mobj.op = mobj.p
		mobj.orr = mobj.r
	end

	if mobj.physics_id > -1 then
		mobj.x = gPhysicsManager.BoxStack[mobj.physics_id].V1.x
		mobj.y = gPhysicsManager.BoxStack[mobj.physics_id].V1.y
		mobj.z = gPhysicsManager.BoxStack[mobj.physics_id].V1.z	
	end

	mobj.SetRotation3DS(mobj.model_id, mobj.h, mobj.p, mobj.r)
	mobj.SetPosition3DS(mobj.model_id, mobj.x, mobj.y, mobj.z)
	
	-- ' If the matrix is to be saved, then push it into our vertex program
	if mobj.saveMatrix then
		-- glPushMatrix()
		-- glLoadIdentity()
		-- glRotatef oh, 1, 0, 0
		-- glRotatef op, 0, 1, 0
		-- glRotatef orr, 0, 0, 1
		-- glTranslatef ox, oy, oz
		
		-- glGetFloatv GL_MODELVIEW_MATRIX, localfv1
		-- glPopMatrix()
	end
	
end
	
MO.Render = function( mobj )	
	RenderModel3DS(mobj.model_id)
end

-- '--------------------------------------------------------------------------------
-- ' Non 3DS Objects - may be just a scene node with no renderable items
SimpleObject = {} -- Extends GenericObject

SimpleObject.CreateNew = function(name)
	local newobj = MO.CreateNew()
	newobj.Create(MakeCRC3DS(name))
	newobj.type_id = ObjectType.Static_Object
	return newobj
end

SimpleObject.Update = function(sobj)
end
	
SimpleObject.Render = function(sobj)
end

-- '--------------------------------------------------------------------------------
-- ' Custom render objects - build own render function! Copy this type!
RopeObject = { -- Extends GenericObject

	obj2 = {}, -- GenericObject
	fixed = 0,
}

RopeObject.CreateNew = function(name)
	local newobj = MO.CreateNew()
	newobj.Create(MakeCRC3DS(name))
	newobj.type_id = Type_Dynamic_Object
	newobj.fixed 	= True
	newobj.obj2 	= nil
	return newobj
end

RopeObject.AttachToObject = function(robj, obj)
	robj.obj2 = obj
end
	
RopeObject.Update = function(robj)
end

RopeObject.Render = function(robj)
	-- glPushMatrix()

	-- glLineWidth(2)
	-- glColor4f(0, 0, 0, 1)
	-- glBegin GL_LINE_STRIP
	-- 	glVertex3f( x, y, z )
	-- 	glTexCoord2f(0.0, 0.0)
	-- 	glVertex3f( obj2.x, obj2.y, obj2.z )
	-- 	glTexCoord2f(1.0, 1.0)
	-- glEnd
	
	-- glPopMatrix()
end

-- '--------------------------------------------------------------------------------

return MO