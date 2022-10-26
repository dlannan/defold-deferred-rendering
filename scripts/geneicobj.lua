
-- '--------------------------------------------------------------------------------
-- ' Enum of types of objects supported

-- Protect from duplicate definition
ObjectType = {
   Static_Object			= 1,
   Static_3DObject		    = 2,
   Dynamic_Object			= 3,
   Dynamic_3DObject		    = 4,
   Character				= 5,
   Vehicle				    = 6,
   Camera				    = 7,
   Light				    = 8,
}

-- The actual api for handling generic objects
local GO = {}

-- '--------------------------------------------------------------------------------
-- ' This is where our base Generic Object is defined
GO.NewGenericObject = function( extendedObj )
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
        pass_mask	= 0,    -- ' pass mask - match to index for bit. only 32 bits (passes) to play with 
    }

    if(extendedObj) then 
        for k,v in pairs(extendedObj) do GenericObject[k] = v end
    end

    return GenericObject
end 

-- '--------------------------------------------------------------------------------
-- ' The manager will pass a crcname back to this function
GO.CreateNew = function(name, extended) 
   local obj = GO.NewGenericObject( extended )
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
   obj.type_id 	= ObjectType.Static_Object
   return obj
end 

-- '--------------------------------------------------------------------------------
GO.AddToPass = function(go, pass)
   go.pass_mask = bit.bor( go.pass_mask,  math.floor(2 ^ pass) )
end

-- '--------------------------------------------------------------------------------
GO.ClearPass = function(go)
   go.pass_mask = 0
end

-- ' Use this method to do any custom rendering passes you may want within your
-- ' Rendering passes
-- ' Derive the Generic class, and override this lethod with your own. 
GO.Render = function(go)
   
end

-- ' Use this method to 'do what you want' with your object
-- ' At a minimum you want to 'push' your position and orientation into
-- ' your entity object (or they wont change when you render them)
GO.Update = function(go)

end

-- '--------------------------------------------------------------------------------

return GO 

-- '--------------------------------------------------------------------------------