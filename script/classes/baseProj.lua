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
    self.think = function() end -- pointer to think func

    self.touch = function() end -- pointer to touch func

    self.lastTouched = -1    -- Last touched object, makes sure touch is only called for a impact once

    -- Physical representation
    self.model       = false -- 3D model (if applicable)
    self.sprite      = false -- Sprite model (if applicable)             
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

function baseEnt:RunPhysics(dt)
    local vel = GetBodyVelocity(self.model)
    local didHit, dist, shape, playerId, playerDamageFactor, normal = QueryShot(GetBodyTransform(self.model).pos, direction, maxDist, 0, self.owner)
    if not didHit or shape == self.lastTouched or playerId == self.lastTouched then
        return
    end

    self.lastTouched = playerId ~= 0 and playerId or shape
    self:touch()
end

function baseEnt:Tick(dt)
    local t = GetTime()

    self:RunPhysics(dt)
 
    if self.nextThink <= t then
        self:think() -- should work!
    end
end

function tickEntity(dt)
    for _, ent in pairs(SPAWNED_ENTITIES) do
        ent:Tick(dt)
    end
end