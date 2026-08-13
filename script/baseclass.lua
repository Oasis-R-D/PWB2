baseWeap = {}

-- Values for this specific weapon
baseWeap.model				= "MOD/models/xml/model.xml"-- path to the XML model file
baseWeap.toolID 			= "baseweap"				-- used by the engine. lowercase and no spaces
baseWeap.toolName 			= "PWB2 Base Weapon"		-- shown in killfeed
baseWeap.toolSlot			= 0
baseWeap.ammoLoadedMax 		= 0							-- max clip 	 	-- -1 for no clip (pulls from reserve)
baseWeap.ammoAltLoadedMax	= 0 						-- max alt clip 	-- -1 for no clip (pulls from reserve) 0 for no alt fire
baseWeap.ammoPickupSize		= baseWeap.ammoLoadedMax	-- defaults to full mag
baseWeap.flags				= 0							-- weapon flags
baseWeap.snds				= 0

function baseWeap:init_sv()
	-- must be called like this due to how static vars work
	baseWeap.init_tool(self)
	baseWeap.init_sfx(self)
end

function baseWeap:init_cl()
	-- must be called like this due to how static vars work
	baseWeap.init_sfx(self)
end

function baseWeap:init_tool()
	RegisterTool(self.toolID, self.toolName, self.model, self.toolSlot)
	SetToolAmmoPickupAmount(self.toolID, self.ammoPickupSize)
end

function baseWeap:init_sfx()
	self.snds = PrecacheSFXArray(self:WeaponSounds())
end

-- sound data for PrecacheSFXArray, override per weapon
function baseWeap:WeaponSounds()
	return {
--  		   [SOUND]		 [load to]	[dist]
		{"MOD/snd/SOUND.ogg", "sv/cl", 	  10}
	} 
end

-- Values that ALL weapons share/use
-- override initVars to add new variables
-- add 'baseWeap.initVars(self, owner)'
-- at the beginning to override vars
-- or end to add more vars
function baseWeap:initVars(owner)
	-- CLIENT VARS
	if client then
		self.holstered			= true

		-- compare against GetTime()
		self.nextFire           = 0
		self.nextAltFire        = 0

		-- can be used for shotgun pumpping, bolt cycling
		-- or any post firing stuff really
		self.pumptime           = 0

		self.inReload           = false

		-- used for shotgun reload interrupting
		self.specialReload      = 0

		-- time until resetting idle anim (there aren't idle anims)
		self.timeWeaponIdle		= 0

		-- True when gun is empty
		-- Use to check if it
		-- should fire in the
		-- firing functions.
		self.firedOnEmpty       = false
		self.playEmptySound		= true
		-- time creep vars
		self.prevPrimFireTime   = 0
		self.lastFireTime       = 0

		-- ammo loaded into weapon. Set by child
		self.ammo				= 0 			-- reserve + clip
		self.ammoLoaded         = self.ammoLoadedMax -- clip
		
		self.ammoAlt      		= 0 			-- clip
		
		self.animator        = ToolAnimator()
	end

	-- which player owns this instance
	self.owner					= owner
end

-- to add a new weapon just do CHILD = baseWeap:new(CHILD, owner) where CHILD is {}
-- to add a weapon to a player do PLCHILD = baseWeap.new(CHILD, PLCHILD, owner)
function baseWeap:new(obj, owner)
    owner = owner or -1

    -- make new table
    local instance = {}
    if obj then
        for k, v in pairs(obj) do
            instance[k] = v
        end
    end

    setmetatable(instance, self)
    self.__index = self

    instance:initVars(owner)
    return instance
end

WEAPON_NOCLIP = -1

-- These are overriden per weapon
function baseWeap:PrimaryAttack()   end
function baseWeap:SecondaryAttack() end
function baseWeap:Reload()          end
function baseWeap:WeaponIdle()		end -- called when no buttons are pressed

--=========================================================================
-- tickPlayer - Handles player inputs
--=========================================================================
function baseWeap:tickPlayer(dt)
	tickToolAnimator(self.animator, dt, nil, self.owner)

	

	local curTime = GetTime()
	
	-- declare var for this since it's used a lot 
    local fireKeyDown 	 = InputDown("usetool", self.owner)
	local altfireKeyDown = InputDown("grab", self.owner)

	self.ammo = GetToolAmmo(self.toolID, self.owner)

	if self.holstered == true then
		-- no rapid firing
		self.nextFire 		= math.max(self.nextFire, curTime + 0.25)
		self.nextAltFire 	= math.max(self.nextAltFire, self.nextFire)
		self.lastFireTime 	= 0

		self.holstered 	= false
	end

	if self.inReload and --[[m_pPlayer->m_flNextAttack]] self.nextFire <= curTime then
		-- complete the reload.
		self.ammoLoaded = math.min(self.ammoLoadedMax, self.ammo)

		self.inReload = false
    end

	if not fireKeyDown then
		self.lastFireTime = 0.0
    end

	if altfireKeyDown and self:CanAttack(self.nextAltFire, curTime) then
		if self.ammoAltLoadedMax ~= WEAPON_NOCLIP and self.ammoAlt == 0 then
			self.firedOnEmpty = true
        end

		-- hold gun straight
		self.animator.timeSinceFire = 0.0

		self:SecondaryAttack()
	elseif fireKeyDown and self:CanAttack(self.nextFire, curTime) then
		if (self.ammoLoaded == 0 and self.ammo == 0) or (self.ammoLoadedMax == WEAPON_NOCLIP and 0 == self.ammo) then
			self.firedOnEmpty = true
        end

		self:PrimaryAttack()
	elseif InputPressed("r", self.owner) and self.ammoLoadedMax ~= WEAPON_NOCLIP and not self.inReload then
		-- reload when reload is pressed, or if no buttons are down and weapon is empty.
		self:Reload()
	elseif not fireKeyDown and not altfireKeyDown then
		-- no fire buttons down
		self.firedOnEmpty = false

		if self.nextFire <= curTime and self:IsUseable() then
			-- weapon is useable. Reload if empty and weapon has waited as long as it has to after firing
			if self.ammoLoaded == 0 --[[and not hasFlag(self.flags, ITEM_FLAG_NOAUTORELOAD)]] then
				self:Reload()
				return
			end
		end

		self:WeaponIdle()
		return
	end

	-- used for when you need extra stuff in WeaponIdle
	if self:ShouldWeaponIdle() then
		self:WeaponIdle()
	end
end

function baseWeap:DrawHUD()
	if self.ammoLoadedMax ~= WEAPON_NOCLIP then -- has clips
		UiPush()
			UiFont("bold.ttf", 32)
			UiAlign("center middle")
			UiTranslate(UiCenter(), UiMiddle() + (UiMiddle() * 0.833))
			if self.inReload == true then
				UiText("RELOADING...")
			else
				UiText(self.ammoLoaded .. "/" .. self.ammoLoadedMax)
			end
		UiPop()
	end

	if self.ammoAltLoadedMax ~= 0 and self.inReload == false then -- has altfire
		UiPush()
			UiFont("bold.ttf", 32)
			UiAlign("center middle")
			UiTranslate(UiCenter(), UiMiddle() + (UiMiddle() * 0.766))
			if self.ammoAltLoadedMax ~= WEAPON_NOCLIP then
				UiText(self.ammoAlt .. "/" .. self.ammoAltLoadedMax)
			else
				UiText(self.ammoAlt)
			end
		UiPop()
	end
end

--=========================================================================
-- 								UTIL FUNCS
--=========================================================================

function baseWeap:PlayEmptySound()
	if self.playEmptySound then
		PlaySound(LoadSound("MOD/snd/empty.ogg"), GetPlayerTransform(self.owner).pos, 0.5)
		self.playEmptySound = false
	end
end

function baseWeap:ShouldWeaponIdle()
	return false -- override me!
end

function baseWeap:CanAttack(attack_time, curtime)
	return (attack_time <= curtime)
end

-- GetNextAttackDelay - Accurate way of getting the next primary fire time.
function baseWeap:GetNextAttackDelay(delay)
    local curTime = GetTime()

	if self.lastFireTime == 0 or self.prevPrimFireTime == -1 then
		-- At this point, we are assuming that the client has stopped firing
		-- and we are going to reset our book keeping variables.
		self.lastFireTime = curTime
		self.prevPrimFireTime = delay
    end

	-- calculate the time between this shot and the previous
	local flTimeBetweenFires = curTime - self.lastFireTime
	local flCreep = 0.0
	if flTimeBetweenFires > 0 then
		flCreep = flTimeBetweenFires - self.prevPrimFireTime -- postive or negative
    end

	-- save the last fire time
	self.lastFireTime = curTime

	local flNextAttack = curTime + delay - flCreep
	-- we need to remember what the self.prevPrimFireTime time is set to for each shot,
	-- store it as self.prevPrimFireTime.
	self.prevPrimFireTime = flNextAttack - curTime
	return flNextAttack
end

--=========================================================
-- IsUseable - this function determines whether or not a
-- weapon is useable by the player in its current state.
-- (does it have ammo loaded? do I have any ammo for the
-- weapon?, etc)
--=========================================================
function baseWeap:IsUseable()
	if self.ammoLoaded > 0 then
		return true
	end

	--Player has unlimited ammo for this weapon or does not use magazines
	if self.ammoLoadedMax == WEAPON_NOCLIP then
		return true
	end

	if self.ammo > 0 then
		return true
	end

	if self.ammoAltLoadedMax ~= 0 then
		--Player has unlimited ammo for this weapon or does not use magazines
		if self.ammoAltLoadedMax == WEAPON_NOCLIP then
			return true
		end

		if self.ammoAlt > 0 then
			return true
		end
	end

	-- clip is empty (or nonexistant) and the player has no more ammo of this type.
	return false --CanDeploy()
end

function baseWeap:DefaultReload(iClipSize, fDelay)
	if self.ammo <= 0 then return false end

	local j = math.min(self.ammoLoadedMax - self.ammoLoaded, self.ammo)
	if j <= 0 then return false end

	local curTime = GetTime()

	--[[m_pPlayer->m_flNextAttack]] self.nextFire = curTime + fDelay
	self.nextAltFire = self.nextFire

	--!!UNDONE -- reload sound goes here !!!

	self.inReload = true

	self.timeWeaponIdle = curTime + 3

	return true
end

function PrecacheSFXArray(arr)
	local precachedSounds = {}
	for i, sounddata in ipairs(arr) do
		if server and sounddata[2] == "sv" then
			table.insert(precachedSounds, LoadSound(sounddata[1], sounddata[3]))
		elseif client and sounddata[2] == "cl" then
			table.insert(precachedSounds, LoadSound(sounddata[1], sounddata[3]))
		end
	end

	--self.WeaponSounds = nil -- don't need this anymore

	return precachedSounds
end