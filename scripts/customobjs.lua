
-- ' Custom Objects - derived from the base Generic Object
-- '--------------------------------------------------------------------------------
-- ' Mainly for use with 3DS objects
ModelObject = {

	saveMatrix      = 0,
	ox = 0.0, oy = 0.0, oz = 0.0,
	oh = 0.0, op = 0.0, orr = 0.0,

	CreateNew function(name, filename)
		local newobj = {}
		print( "here1" )
		newobj.Create(MakeCRC3DS(name))
		print( "here2" )
		newobj.model_id 	= LoadModel3DS(name, filename)			' Load in the mesh
		print( "here3" )
		newobj.type_id 	= Type_Static_3DSObject
		newobj.physics_id 	= -1
		newobj.saveMatrix 	= False
		return newobj
    end,

	Update = function()
		if saveMatrix then
			self.ox = x
			self.oy = y 
			self.oz = z
			self.oh = h
			self.op = p
			self.orr = r
        end

		if self.physics_id > -1 then
			self.x = gPhysicsManager.BoxStack[self.physics_id].V1.x
            self.y = gPhysicsManager.BoxStack[self.physics_id].V1.y
			self.z = gPhysicsManager.BoxStack[self.physics_id].V1.z	
        end
	
		self.SetRotation3DS(self.model_id, self.h, self.p, self.r)
		self.SetPosition3DS(self.model_id, self.x, self.y, self.z)
		
		-- ' If the matrix is to be saved, then push it into our vertex program
		if saveMatrix then
			glPushMatrix()
			glLoadIdentity()
			glRotatef oh, 1, 0, 0
			glRotatef op, 0, 1, 0
			glRotatef orr, 0, 0, 1
			glTranslatef ox, oy, oz
			
			glGetFloatv GL_MODELVIEW_MATRIX, localfv1
			glPopMatrix()
        end
		
	end,
	
	Render = function()	
		RenderModel3DS self.model_id
    end,
}

-- '--------------------------------------------------------------------------------
-- ' Non 3DS Objects - may be just a scene node with no renderable items
SimpleObject = { -- Extends GenericObject

	CreateNew = function(name)
		local newobj = SimpleObject.CreateMNew()
	    newobj.Create(MakeCRC3DS(name))
		newobj.type_id = Type_Static_Object
		return newobj
    end,

	Update = function()
    end,
	
	Render = function()
    end,
}

-- '--------------------------------------------------------------------------------
-- ' Custom render objects - build own render function! Copy this type!
RopeObject = { -- Extends GenericObject

	obj2 = {}, -- GenericObject
	fixed = 0,

	CreateNew = function(name)
		local newobj = RopeObject.CreateNew()
		newobj.Create(MakeCRC3DS(name))
		newobj.type_id = Type_Dynamic_Object
		newobj.fixed 	= True
		newobj.obj2 	= Null
		return newobj
    end,

	AttachToObject = function(obj)
		self.obj2 = obj
    end,
	
	Update = function()
    end,

	Render = function()
		glPushMatrix()
	
		glLineWidth(2)
		glColor4f(0, 0, 0, 1)
		glBegin GL_LINE_STRIP
			glVertex3f( x, y, z )
			glTexCoord2f(0.0, 0.0)
			glVertex3f( obj2.x, obj2.y, obj2.z )
			glTexCoord2f(1.0, 1.0)
		glEnd
		
		glPopMatrix()
    end,
}

