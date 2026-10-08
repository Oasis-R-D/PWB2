local curEntSlot = 1

--============================================================================================
-- 	 Entity OR projectile code (undecided)
--============================================================================================

baseEnt = {}

-- entity class constructor
-- to add a new entity just do WPNPTR = baseEnt:new(CHILD, owner) where CHILD is {}
function baseEnt:new(obj, owner)
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

    instance:initVars(owner)

    instance.slot = curEntSlot
    curEntSlot = curEntSlot + 1

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
function baseEnt:initVars(owner)
    -- which player owns this instance
	self.owner	     = owner

    -- Next time to run self:think() (GetTime() + X)
    self.nextThink   = 0

    -- Called when GetTime() reaches self.nextThink
    self.think       = function() end -- pointer to think func

    -- Called when ent impacts a new object
    self.touch       = function() end -- pointer to touch func
`   
    -- Last touched object, makes sure touch is only called for a impact once
    self.lastTouched = -1    

    self.origin      = Vec()

    self.flags       = self:addflags()

    -- FAKE PHYSICS VARS
        self.active       = true -- hasn't hit the ground?
        self.bounceFactor = 1.0

        self.prevOrigin   = Vec()
        self.angles       = Vec()
        self.angleVel     = Vec()
        self.velocity     = Vec()

    -- Physical representation (both can be present!)
    self.model           = false -- 3D model     (if applicable)
    if client then
        self.sprite      = false -- Sprite model (if applicable)
        self.spriteScale = 1
    end
end

-- Override for more flags
function baseEnt:addflags()
    return addFlags(FENT_NONE, 0)
end

function baseEnt:setModel(model)
    self.model = model

    if client then return end
    self:ClientEntCall(0, "setModel", model)
end

function baseEnt:PrecacheSFX()
	local precachedSounds = {}
	local soundsLoaded = 0

	for _, sounddata in ipairs(self:Sounds()) do
		-- Distance defaults to 10 on SV + CL
		sounddata[5] = sounddata[5] and sounddata[5] or 10

		-- Set the index
		sounddata[3] = sounddata[3] and sounddata[3] or (soundsLoaded + 1)

		if server and sounddata[2] == "sv" then
            soundsLoaded = soundsLoaded + 1

			if sounddata[4] and sounddata[4] == true then
                precachedSounds[sounddata[3]] = LoadLoop("MOD/snd/" .. sounddata[1], sounddata[5])
            else
                precachedSounds[sounddata[3]] = LoadSound("MOD/snd/" .. sounddata[1], sounddata[5])
            end
		elseif client and sounddata[2] == "cl" then
            soundsLoaded = soundsLoaded + 1

            if sounddata[4] and sounddata[4] == true then
                precachedSounds[sounddata[3]] = LoadLoop("MOD/snd/" .. sounddata[1], sounddata[5])
            else
                precachedSounds[sounddata[3]] = LoadSound("MOD/snd/" .. sounddata[1], sounddata[5])
            end
		end
	end

	self.snds = precachedSounds
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

function baseEnt:RunPhysics_Real(dt)
    self.origin = GetBodyTransform(self.model).pos

    local vel = GetBodyVelocity(self.model)
    local didHit, _, shape, playerId = QueryShot(self.origin, VecNormalize(vel), VecLength(vel), 0, self.owner)
    if not didHit or shape == self.lastTouched or playerId == self.lastTouched then
        return
    end

    self.lastTouched = playerId ~= 0 and playerId or shape
    self:touch()
end

function baseEnt:RunPhysics_Fake(dt)
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
        local gravity = -dt * GetGravity()[2]

        QueryRequire("visible physical")
        local hit, dist, traceNormal = QueryRaycast(self.prevOrigin, betweenDir, betweenLen)

        if hit == true then
            local proj, damp

            -- Pull away from walls
            local useDist = dist
            if traceNormal[2] < 0.9 then
                useDist = useDist - 0.01
            end

            -- Place at contact point
            self.origin = VecAdd(self.prevOrigin, VecScale(betweenDir, useDist))

            -- Damp velocity
            damp = self.bounceFactor
            damp = damp * 0.5
            if traceNormal[2] > 0.9 then -- Hit floor?
                -- TO-DO: improve gravity here (only works with normal gravity!!)
                if self.velocity[2] <= 0 and self.velocity[2] >= gravity * 2 then
                    damp = 0 -- Stop
                    self.active = false
                    self.nextActiveCheck = GetTime() + 0.1
                    self.angles[1] = 0
                end
            end

            if damp > 0 and betweenLen / dt > 1 then
                self:touch() end  -- Hacky fix

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
        if self.active then
            if IsPointInWater(self.origin) == false then
                self.velocity[2] = self.velocity[2] + gravity
            else
                self.velocity = VecScale(self.velocity, 0.98)
                self.angles = VecScale(self.angles, 0.98)

                if self.velocity[2] < 0 then
                    self.velocity[2] = self.velocity[2] * 0.95
                end

                self.velocity[2] = self.velocity[2] + ((math.sin(3 * GetTime()) * 0.00127) + 0.0127)
            end
        end
    elseif self.nextActiveCheck <= GetTime() then
        QueryRequire("visible physical")
        local hit = QueryRaycast(self.origin, Vec(0, -GetGravity()[2]), dt)
        if not hit then
            self.active = true
        end

        self.nextActiveCheck = GetTime() + 0.1
    end

    -- bodies must be on the server!
    if server and self.model then
        SetBodyTransform(self.model, Transform(self.origin, QuatEuler(self.angles[1], self.angles[2], self.angles[3])))
    end
end

function baseEnt:Tick(dt)
    local t = GetTime()

    if hasFlag(self.flags, FENT_FAKEPHYSICS) then
        self:RunPhysics_Fake(dt) -- works with bodies and sprites
    else
        self:RunPhysics_Real(dt) -- only works with a body
    end

    -- sprites are only simulated on clients
    if self.sprite then
	    local spriteTrans = Transform(
            self.origin,
            GetCameraTransform().rot
        )
        
        -- Create the drawnSPR variable to hold the sprite
        if not self.drawnSPR then
            self.drawnSPR = LoadSprite(self.sprite)
            self.sprite = true -- dummy value to keep drawing running
        end

        DrawSprite(self.drawnSPR, spriteTrans, self.spriteScale, self.spriteScale, 1.0, 1.0, 1.0, 1.0, true, true, true)
    end

    if self.nextThink <= t then
        self:think() -- should work!
    end
end

function baseEnt:init_sv()
	-- must be called like this
	baseEnt.PrecacheSFX(self)

    -- Delete the raw sounds now that they are uneeded
	FREE(self.init_sv)
	FREE(self.Sounds)
	FREE(self.PrecacheSFX)
end

function baseEnt:init_cl()
	-- must be called like this
	baseEnt.PrecacheSFX(self)

    -- Delete the raw sounds now that they are uneeded
    FREE(self.init_cl)
	FREE(self.Sounds)
	FREE(self.PrecacheSFX)
end