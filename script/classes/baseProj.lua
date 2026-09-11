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
    self.origin     = Vec()
    self.angle      = Vec()

    self.prevOrigin = Vec()

    -- which player owns this instance
	self.owner	    = owner

    self.nextThink  = false
    self.think = function() end

    -- Physical representation
    self.model      = false  -- 3D model (if applicable)
    self.sprite     = false  -- Sprite model (if applicable)
    self.physical   = true   -- Use Teardown physics instead of Temp-Ent physics

    self.lastTouched = -1    -- Last touched object, makes sure touch is only called for a impact once
end

function baseEnt:PrecacheSFX()
	local precachedSounds = {}
    local soundsLoaded = 0

	for i, sounddata in ipairs(self:Sounds()) do
		if server and sounddata[2] == "sv" then
            soundsLoaded = soundsLoaded + 1
			if sounddata[4] and sounddata[4] == true then
                precachedSounds[soundsLoaded] = LoadLoop("MOD/snd/" .. sounddata[1], sounddata[3])
            else
                precachedSounds[soundsLoaded] = LoadSound("MOD/snd/" .. sounddata[1], sounddata[3])
            end
		elseif client and sounddata[2] == "cl" then
            soundsLoaded = soundsLoaded + 1
            if sounddata[4] and sounddata[4] == true then
                precachedSounds[soundsLoaded] = LoadLoop("MOD/snd/" .. sounddata[1], sounddata[3])
            else
                precachedSounds[soundsLoaded] = LoadSound("MOD/snd/" .. sounddata[1], sounddata[3])
            end
		end
	end

	self.snds = precachedSounds
end

function ReceiveEntCall(func, owner, slot, ...)
	local wpn = PLAYER_WEAPONS[owner][slot]

	if not wpn then return end

	wpn[func](wpn, ...)
end

function baseEnt:ServerEntCall(func, ...)
	ServerCall("ReceiveEntCall", func, self.owner, self.entSlot, ...)
end

function baseEnt:ClientEntCall(receivers, func, ...)
	ClientCall(receivers, "ReceiveEntCall", func, self.owner, self.entSlot, ...)
end

function baseEnt:RunPhysics(dt)
end

function baseEnt:Tick(dt)
    local t = GetTIme()

    if self.nextThink < t then
        self:think() -- should work!
    end
end