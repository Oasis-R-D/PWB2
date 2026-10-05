--============================================================================================
-- 	 Entity OR projectile code (undecided)
--============================================================================================

baseEnt = {}

function baseEnt:init_sv(wpnSlot)
	-- must be called like this
	baseEnt.PrecacheSFX(self)
	self.entSlot = wpnSlot
end

function baseEnt:init_cl(wpnSlot)
	-- must be called like this
	baseEnt.PrecacheSFX(self)
	self.entSlot = wpnSlot
end

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
    return instance
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

    self.nextThink   = false
    self.think       = function() end -- pointer to think func

    self.touch       = function() end -- pointer to touch func

    self.lastTouched = -1    -- Last touched object, makes sure touch is only called for a impact once

    -- Physical representation (both can be present!)
    self.model       = false -- 3D model (if applicable)
    self.sprite      = false -- Sprite model (if applicable)

    self.origin      = Vec() -- needs var in case not using body
    
    -- FAKE PHYSICS VARS
        self.active = true, -- hasn't hit the ground?
        self.bounceFactor = 1.0

        self.prevOrigin = Vec()
        self.angles = Vec()
        self.angleVel = Vec()
        self.velocity = Vec()

    self:flags()
end

-- Override for more flags
function baseEnt:flags()
    self.flags = addFlags(0, 0)
end

function baseEnt:PrecacheSFX()
	local precachedSounds = {}
	local soundsLoaded = 0

	for i, sounddata in ipairs(self:Sounds()) do
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

function ReceiveEntCall(func, slot, ...)
	local ent = SPAWNED_ENTITIES[slot]

	if not ent then return end

	ent[func](ent, ...)
end

function baseEnt:ServerEntCall(func, ...)
	ServerCall("ReceiveEntCall", func, self.entSlot, ...)
end

function baseEnt:ClientEntCall(receivers, func, ...)
	ClientCall(receivers, "ReceiveEntCall", func, self.entSlot, ...)
end

function baseEnt:RunPhysics_Real(dt)
    self.origin = GetBodyTransform(self.model).pos

    local vel = GetBodyVelocity(self.model)
    local didHit, dist, shape, playerId, playerDamageFactor, normal = QueryShot(self.origin, VecNormalize(vel), VecLength(vel), 0, self.owner)
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
        local gravity = -dt * cl_gravity

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
                if self.velocity[2] <= 0 and self.velocity[2] >= gravity * 2 then
                    damp = 0 -- Stop
                    self.active = false
                    self.angles[1] = 0
                end
            end

            if damp > 0 and betweenLen / dt > 1 then
                self:touch() end  -- Hacky fix

            -- Reflect velocity
            if damp ~= 0 then
                proj = VecDot(self.velocity, traceNormal)
                --VectorMA(self.velocity, -proj * 2, traceNormal, self.velocity)
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
                self.velocity = VecAdd(self.velocity, GetGravity())
            else -- TO-DO: more sophisticated buoyancy using water plane normal
                self.velocity = VecScale(self.velocity, 0.98)
                self.angles = VecScale(self.angles, 0.98)

                if self.velocity[2] < 0 then
                    self.velocity[2] = self.velocity[2] * 0.95
                end

                self.velocity[2] = self.velocity[2] + ((math.sin(3 * GetTime()) * 0.00127) + 0.0127)
            end
        end
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

    -- sprites are simulated on clients
    if client and self.sprite then
        -- DRAW CAMERA FACING SPRITE HERE

	    local t = Transform(self.origin, GetCameraTransform().rot)
    end

    if self.nextThink <= t then
        self:think() -- should work!
    end
end

function tickEntity(dt)
    for _, ent in pairs(SPAWNED_ENTITIES) do
        ent:Tick(dt)
    end
end