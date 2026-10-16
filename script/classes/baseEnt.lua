CurEntSlot = 1

--============================================================================================
-- 	 Entity OR projectile code (undecided)
--============================================================================================

baseEnt = {}

-- entity class constructor
-- run baseEnt:Create(CLASS, pos, ang, owner) to add a new entity
function baseEnt:Create(obj, pos, ang, owner)
    owner = owner or -1

    -- make new table
    local instance = {}
    if obj then
		-- copy values from used class
        for k, v in pairs(obj) do
            instance[k] = v
        end
    end

    setmetatable(instance, self)
    self.__index = self

    instance:initVars()

    instance.owner = owner
    instance.origin = VecCopy(pos)
    instance.angles = VecCopy(ang)

    instance.slot = CurEntSlot

    GLOBAL_SPAWNED_ENTITIES[CurEntSlot] = instance
    CurEntSlot = CurEntSlot + 1

    instance:Spawn()

    return instance
end

-- defines sound data per entity class
-- sounds are automatically parsed from the snd folder
-- dist and loop are optional and default to values shown in table
-- index is optional and defaults to order loaded (shown below)
-- x sv (index 1 on sv)
-- y cl (index 1 on cl)
-- z cl (index 2 on cl)
-- NOTE: if you really want to save space, 
-- you can access sounds from other entity classes instead of duplicating them
function baseEnt:Sounds()
	return {
--  	   SOUND	  load to	  [index]      [loop]  [dist]
		{"SOUND.ogg", "sv|cl", "name/num/nil", false,	10}
	}
end

-----------------------------------------------------------
-- Values that ALL weapons share/use
-- override initVars() to add variables
-- add 'baseEnt.initVars(self, owner)'
-- at the beginning if overriding vars
-- at the end otherwise if preferred
-----------------------------------------------------------
function baseEnt:initVars()
    -- which player owns this instance
	self.owner	     = 0

    -- Next time to run self:think() (GetTime() + X)
    self.nextThink   = 0

    -- Called when GetTime() reaches self.nextThink
    self.think       = function() end -- pointer to think func

    -- Called when ent impacts a new object
    self.touch       = function() end -- pointer to touch func

    self.origin      = Vec()

    self.flags       = self:SpawnFlags()

    -- FAKE PHYSICS VARS
        self.active        = true -- hasn't hit the ground?
        self.bounceFactor  = 1.0

        --self.prevOrigin    = Vec()
        self.angles        = Vec()
        self.angleVel      = Vec()
        self.velocity      = Vec()
        self.gravityMult   = 1
        self.collideRadius = 0.05 -- keep decently high to prevent clipping

    -- Physical representation (both can be present!)
    self.body            = false -- 3D body     (if applicable)
    self.cl_ent          = false -- true if the body is a client entity
    if client then
        self.sprite      = false -- Sprite body (if applicable)
        self.spriteScale = 1
    end
end

-- Override for more flags
function baseEnt:SpawnFlags()
    return addFlags(FENT_NONE, 0)
end

-- Creates the entities body (model) entity at XML[index] on the server. Keep clBodynil
function baseEnt:MDL_SV_SET(XML, index, clBody)
    Delete(self.body)
    self.body = nil
    self.cl_ent = nil

    if client then
        self.body = clBody
        return
    end

    if XML ~= 0 and XML then
        local TDent = Spawn(XML, Transform(self.origin, GetBodyTransform(self.body).rot))
        self.body = TDent[index]

        self:ClientEntCall(0, "MDL_SV_SET", 0, 0, self.body)
    end
end

-- Creates the entities body (model) entity at XML[index]
function baseEnt:MDL_SET(XML, index)
    Delete(self.body)
    self.body = nil
    self.cl_ent = true

    if server then
        return
    end

    if XML ~= 0 and XML then
        local TDent = Spawn(XML, Transform(self.origin, GetBodyTransform(self.body).rot))
        self.body = TDent[index]
    end
end

-- Sets the entities image sprite, doesn't override model
function baseEnt:SetSprite(Sprite)
    if not client then
        return end

    self.sprite = Sprite
    self.drawnSPR = nil    
end

function baseEnt:SetOrigin(origin)
    self.origin = VecCopy(origin)
    self.prevOrigin = VecCopy(origin)
    if server and self.body then
        SetBodyTransform(self.body, Transform(origin, GetBodyTransform(self.body).rot))
    end
end

-- Collision uses QueryShot, includes players by default
-- will not hit owner
function baseEnt:PHYS_QuerySettings()
    QueryRequire('visible physical')
    QueryRejectBody(self.body)
end

function baseEnt:DeleteThis()
    if server or (self.cl_ent and client) then Delete(self.body) end
    GLOBAL_SPAWNED_ENTITIES[self.slot] = nil
end

-- Gets the returned values of the raytrace that last called Touch()
function baseEnt:PHYS_GetLastTouchTrace()
    --    dist shape plyrHit surfNormal
    return 0,    0,     0,     Vec()
end

--=========================================================================
--	NETWORKING
--	Used to communicate between a entities server and client representation
--=========================================================================

function ReceiveEntCall(func, slot, ...)
	local ent = GLOBAL_SPAWNED_ENTITIES[slot]
	if not ent then error("EntCall couldn't find ent:" .. slot) return end

	ent[func](ent, ...)
end

function baseEnt:ServerEntCall(func, ...)
	ServerCall("ReceiveEntCall", func, self.slot, ...)
end

function baseEnt:ClientEntCall(receivers, func, ...)
	ClientCall(receivers, "ReceiveEntCall", func, self.slot, ...)
end

--=========================================================================
--	BACKEND FUNCS
--  These are used by the entity code for very specific purposes 
--  and shouldn't (under normal circumstanced) be overriden.
--=========================================================================

function baseEnt:PHYS_RunReal(dt)
    self.origin = GetBodyTransform(self.body).pos

    if not self:hasFunc("touch") then return end

    local vel = GetBodyVelocity(self.body)

    self:PHYS_QuerySettings()
    local didHit, dist, shape, playerId, _, normal = QueryShot(self.origin, VecNormalize(vel), VecLength(vel), self.collideRadius, self.owner)
    if not didHit or shape == select(2, self:PHYS_GetLastTouchTrace()) or playerId == select(3, self:PHYS_GetLastTouchTrace()) then
        return
    end

    self.PHYS_GetLastTouchTrace = function()
        return dist, shape, playerId, normal
    end

    self:touch()
end

function baseEnt:PHYS_RunFake(dt)
    self.prevOrigin = VecCopy(self.origin)

    -- apply velocity
    for j = 1, 3 do
        self.origin[j] = self.origin[j] + (self.velocity[j] * dt)
    end

    if self.active then
        -- Ang vel ----------------------------------------------------
        for j = 1, 3 do
            self.angles[j] = self.angles[j] + self.angleVel[j] * dt
        end

        -- Collision ----------------------------------------------------
        local betweenDir = VecNormalize(self.velocity)
        local betweenLen = VecLength(self.velocity) * dt
        local gravity = dt * GetGravity()[2] * self.gravityMult

        self:PHYS_QuerySettings()
        local hit, dist, shape, playerId, _, traceNormal = QueryShot(self.prevOrigin, betweenDir, betweenLen, self.collideRadius, self.owner)

        if hit == true then
            local proj, damp

            -- Place at contact point
            self.origin = VecAdd(self.prevOrigin, VecScale(betweenDir, dist))

            -- Pull out
            self.origin = VecAdd(self.origin, VecScale(traceNormal, self.collideRadius))

            -- Damp velocity
            damp = self.bounceFactor
            damp = damp * 0.5
            if traceNormal[2] > 0.9 then -- Hit floor?
                -- TO-DO: only works with normal gravity!!
                -- Also the range needs tweaked per collideRadius. Fix?
                if self.velocity[2] <= 0 and self.velocity[2] > -2 then
                    damp = 0 -- Stop
                    self.active = false
                    self.nextActiveCheck = GetTime() + 0.1
                    self.angles[1] = 0
                    self.velocity = Vec()
                end
            end

            if betweenLen / dt > 1 then
                if self:hasFunc("touch") then
                    self.PHYS_GetLastTouchTrace = function()
                        return dist, shape, playerId, traceNormal
                    end

                    self:touch()
                end
            end

            -- Reflect velocity
            if damp ~= 0 then
                proj = VecDot(self.velocity, traceNormal)
                self.velocity = VecAdd(self.velocity, VecScale(traceNormal, -proj * 2))

                -- Reflect rotation (fake)
                self.angles[2] = -self.angles[2]
            end

            if damp ~= 1 then
                self.velocity = VecScale(self.velocity, damp)
                self.angleVel = VecScale(self.angleVel, 0.9)
            end
        end

        -- Gravity ----------------------------------------------------
        if self.active and gravity ~= 0 then
            if IsPointInWater(self.origin) == false then
                self.velocity[2] = self.velocity[2] + gravity
            else
                self.velocity = VecScale(self.velocity, 0.98)
                self.angles = VecScale(self.angles, 0.98)

                if self.velocity[2] < 0 then
                    self.velocity[2] = self.velocity[2] * 0.95 * self.gravityMult
                end

                self.velocity[2] = self.velocity[2] + ((math.sin(3 * GetTime()) * 0.00127) + 0.0127) * self.gravityMult
            end
        end
    elseif self.nextActiveCheck <= GetTime() then
        self:PHYS_QuerySettings()
        local hit = QueryShot(self.origin, VecNormalize(GetGravity()), self.collideRadius*1.25, self.collideRadius, self.owner)
        if not hit then
            self.active = true
        end

        self.nextActiveCheck = GetTime() + 0.33
    end

    if not self.body then return end

    -- check if the body is on client or server
    if not self.cl_ent then
        if server then
            SetBodyTransform(self.body, Transform(self.origin, QuatEuler(self.angles[1], self.angles[2], self.angles[3])))
        end
    elseif client then
        SetBodyTransform(self.body, Transform(self.origin, QuatEuler(self.angles[1], self.angles[2], self.angles[3])))
    end
end

function baseEnt:Tick(dt)
    local t = GetTime()

    if hasFlag(self.flags, FENT_FAKEPHYSICS) then
        self:PHYS_RunFake(dt) -- works with bodies and sprites
    else
        self:PHYS_RunReal(dt) -- only works with a body
    end

    -- sprites are only simulated on clients
    if self.sprite then
	    local spriteTrans = Transform(
            self.origin,
            GetPlayerCameraTransform().rot
        )

        -- Create the drawnSPR variable to hold the sprite
        if not self.drawnSPR then
            self.drawnSPR = LoadSprite(self.sprite)
            self.sprite = true -- dummy value to keep drawing running
        end

        DrawSprite(self.drawnSPR, spriteTrans, self.spriteScale, self.spriteScale, 1.0, 1.0, 1.0, 1.0, true, true, true)
    end

    if self.nextThink <= t then
        self.nextThink = math.huge
        self:think()
    end
end

function baseEnt:init_sv()
    PrecacheSFX(self)

    -- Delete the raw sounds now that they are uneeded
	FREE(self.init_sv)
	FREE(self.Sounds)
end

function baseEnt:init_cl()
	PrecacheSFX(self)

    -- Delete the raw sounds now that they are uneeded
    FREE(self.init_cl)
	FREE(self.Sounds)
end

function baseEnt:hasFunc(function_name)
    return self[function_name] ~= baseEnt[function_name]
end