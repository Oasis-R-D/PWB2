local baseWeap = {}
baseWeap.__index = baseWeap

-- Values that ALL weapons share/use
function baseWeap:initVars()
    -- compare against GetTime()
    self.nextFire           = 0
    self.nextAltFire        = 0

    self.inReload           = false

    -- True when gun is empty and player
    -- is still holding down attack keys
    self.fireOnEmpty        = false

    -- time creep vars
    self.prevPrimFireTime   = 0
    self.lastFireTime       = 0

    -- ammo loaded into weapon. Set by child
    self.ammoLoaded         = 0
    self.ammoAltLoaded      = 0
    

end

function baseWeap:new(obj)
    obj = obj or {}
    setmetatable(obj, self)

    -- Set up variables
    baseWeap:initVars()

    return obj
end

function baseWeap:CanAttack(attack_time, curtime)
	return attack_time <= curtime and true or false
end

WEAPON_NOCLIP = -1

function baseWeap:PrimaryAttack()   end
function baseWeap:SecondaryAttack() end

--=========================================================================
-- ItemPostFrame - Handles player inputs
--=========================================================================
function baseWeap:ItemPostFrame()
	local maxClip = self:iMaxClip()

    local curTime = GetTime()

	if self.inReload and m_pPlayer->m_flNextAttack <= curTime then
		-- complete the reload.

		self.ammoLoaded = math.min(maxClip, m_pPlayer->m_rgAmmo[m_iPrimaryAmmoType])

		--m_pPlayer->TabulateAmmo()

		self.inReload = false
    end

    -- declare var for this since it's used a lot 
    local fireKeyDown = InputDown("usetool", p)
	if not fireKeyDown then
		m_flLastFireTime = 0.0
    end

	if InputPressed("grab", p) and self:CanAttack(self.nextAltFire, curTime) then
		if self.ammoAltLoaded == 0 then
			self.fireOnEmpty = true
        end

		--m_pPlayer->TabulateAmmo()
		self:SecondaryAttack()
	elseif fireKeyDown and self:CanAttack(self.nextFire, curTime) then
		if (self.ammoLoaded == 0 and self:pszAmmo1()) or (maxClip == WEAPON_NOCLIP and 0 == m_pPlayer->m_rgAmmo[PrimaryAmmoIndex()]) then
			self.fireOnEmpty = true
        end

		--m_pPlayer->TabulateAmmo()

		self:PrimaryAttack()
	elseif InputPressed("r", p) and maxClip ~= WEAPON_NOCLIP and not self.inReload then
		-- reload when reload is pressed, or if no buttons are down and weapon is empty.
		self:reload()
	elseif not fireKeyDown and not InputDown("grab", p) then
		-- no fire buttons down

		self.fireOnEmpty = false

		if IsUseable() or self.nextFire >= curTime then
			-- weapon is useable. Reload if empty and weapon has waited as long as it has to after firing
			if self.ammoLoaded == 0 and self.nextFire < curTime and (iFlags() & ITEM_FLAG_NOAUTORELOAD) == 0 then
				self:reload()
				return
			end
		end

		WeaponIdle()
		return
	end

	-- catch all
	if ShouldWeaponIdle() then
		WeaponIdle()
	end
end

--=========================================================================
-- GetNextAttackDelay - Accurate way of getting the next primary fire time.
--=========================================================================
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
