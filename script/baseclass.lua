baseWeap = {}

-- Values for this specific weapon
function baseWeap:toolInfo()
	self.model				= "MOD/models/xml/MODEL.xml"
	self.toolID 			= "pwb2weap"
	self.toolName 			= "PWB2 Baseweapon"
	self.ammoLoadedMax 		= 0 -- max clip 	-- -1 for no clip (pulls from reserve)
	self.ammoAltLoadedMax	= 0 -- max alt clip -- -1 for no clip (pulls from reserve) 0 for no alt fire
	self.flags				= 0
end

-- Values that ALL weapons share/use
function baseWeap:initVars()
	self:toolInfo()

    -- compare against GetTime()
    self.nextFire           = 0
    self.nextAltFire        = 0

    -- can be used for shotgun pumpping, bolt cycling
    -- or any post firing stuff really
    self.pumptime           = 0

    self.inReload           = false

    -- used for shotgun reload interrupting
    self.specialReload      = 0

    -- True when gun is empty
	-- Use to check if it
	-- should fire in the
	-- firing functions.
    self.firedOnEmpty       = false

    -- time creep vars
    self.prevPrimFireTime   = 0
    self.lastFireTime       = 0

    -- ammo loaded into weapon. Set by child
	self.ammo				= 0 -- reserve + clip
    self.ammoLoaded         = 0 -- clip
	
    self.ammoAlt      		= 0 -- clip
    
    self.WpnAnimator        = ToolAnimator()

	-- which player owns this instance
	self.owner = owner
end

-- to add a new weapon just do CHILD = baseWeap:new(CHILD, owner) where CHILD is {}
function baseWeap:new(obj, owner)
    obj = obj or {}
    setmetatable(obj, self)
	self.__index = self

    -- Set up variables
    obj:initVars(owner)

    return obj
end

WEAPON_NOCLIP = -1

-- These are overriden per weapon
function baseWeap:PrimaryAttack()   end
function baseWeap:SecondaryAttack() end
function baseWeap:Reload()          end

function baseWeap:PlayEmptySound()
	PlaySound("MOD/snd/357_cock1.ogg", GetPlayerTransform(self.owner).pos, 0.5)
end

--=========================================================================
-- tickPlayer - Handles player inputs
--=========================================================================
function baseWeap:tickPlayer(dt)
	tickToolAnimator(self.toolAnimator, dt, nil, self.owner)
	self.ammo = GetToolAmmo(self.toolID, self.owner)

    local curTime = GetTime()

	if self.inReload and --[[m_pPlayer->m_flNextAttack]] self.nextFire <= curTime then
		-- complete the reload.
		self.ammoLoaded = math.min(self.ammoLoadedMax, self.ammo)

		self.inReload = false
    end

    -- declare var for this since it's used a lot 
    local fireKeyDown = InputDown("usetool", self.owner)
	if not fireKeyDown then
		self.lastFireTime = 0.0
    end

	if InputPressed("grab", self.owner) and self:CanAttack(self.nextAltFire, curTime) then
		if self.ammoAltLoadedMax ~= WEAPON_NOCLIP and self.ammoAlt == 0 then
			self.firedOnEmpty = true
        end

		self:SecondaryAttack()
	elseif fireKeyDown and self:CanAttack(self.nextFire, curTime) then
		if (self.ammoLoaded == 0 and self.ammo == 0) or (self.ammoLoadedMax == WEAPON_NOCLIP and 0 == self.ammo) then
			self.firedOnEmpty = true
        end

		self:PrimaryAttack()
	elseif InputPressed("r", self.owner) and self.ammoLoadedMax ~= WEAPON_NOCLIP and not self.inReload then
		-- reload when reload is pressed, or if no buttons are down and weapon is empty.
		self:Reload()
	elseif not fireKeyDown and not InputDown("grab", self.owner) then
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

	-- catch all
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