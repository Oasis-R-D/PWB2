C_GREN = {} -- goes in GLOBAL_WEAPONS

--=========================================================================
-- Define the weapon and it's variables
--=========================================================================

-- Static values for this specific weapon
-- These don't need redefined in a weapon if a var is just the default value found in baseWeap

C_GREN.model = "grenade.xml" -- Path to the XML model file

C_GREN.toolID   = "pwb2_gren" -- Used by the engine. Lowercase and no spaces
C_GREN.toolName = "PWB2 Grenade"  -- Shown in killfeed
C_GREN.toolSlot = 4
C_GREN.toolPos  = 3			   -- placement in the hud column

C_GREN.ammoLoadedMax    = WEAPON_NOCLIP		 -- Max clip 	 	-- -1 for no clip (pulls from reserve)
C_GREN.ammoAltLoadedMax = WEAPON_NOALTAMMO 	 -- Max alt clip 	-- -1 for no clip (pulls from reserve)
C_GREN.ammoPickupSize   = 5					 -- Defaults to full mag

C_GREN.flags = addFlags(0, FWPN_SV_CALLONCE_PRIM,
						   FWPN_NOALTACTIONPOSE) -- Weapon flags
C_GREN.snds  = 0 -- Prechached SFX list, set on INIT

-- override initVars to add new variables
function C_GREN:initVars(owner)
	baseWeap.initVars(self, owner)

	if client then
		self.swingNumb 	  = -1 -- 1-3

		self.releaseThrow = -1
		self.startThrow   = 0
	end
end

--=========================================================================
-- Define the weapon's SFX / VFX
--=========================================================================

function C_GREN:Sounds()
	return {
		{"slam_throw.ogg", "cl", "throw"},
	}
end

--=========================================================================
-- Weapon functions
--=========================================================================

function C_GREN:Deploy()
	if client then
		client.PWB_ANIMATOR[self.owner].maxActionPoseTime = 0.1
		self.releaseThrow = -1

		client.PWB_ANIMATOR[self.owner].timeSinceFire = 99999 -- don't do throw pose
	end
end

function C_GREN:Holster()
	if client then
		client.PWB_ANIMATOR[self.owner].forceSecondaryActionPose = false
		client.PWB_ANIMATOR[self.owner].maxActionPoseTime = 5.0
		self.startThrow = 0
	end
end

function C_GREN:Throw(time)
    if server then
        local angThrow = TransformToParentVec(self.eye, Vec(0, 0, -1))

        local dirX = angThrow[2]
        if dirX < 0 then
            dirX = -10 + dirX * ((90 - 10) / 90.0)
        else
            dirX = -10 + dirX * ((90 + 10) / 90.0)
        end

        local flVel = (90 - dirX) * 4
        if flVel > 500 then
            flVel = 500
        end

        local vecThrow = VecAdd(VecScale(angThrow, flVel/39.37), GetPlayerVelocity(self.owner))

        if PWB_SETTING.debug then DebugPrint("Gren vel: " .. flVel) end

        local angles = Vec()
        if self.swingNumb == -1 then
            angles = Vec(-50.0, 3.5, 45.0)
        elseif self.swingNumb == -2 then
            angles = Vec(-55.0, 5.0, -45.0)
        else
            angles = Vec(-45.0, 3.0, 0.0)
        end

        angles = VecScale(VecNormalize(angles), GetRandomFloat(-8, 8))

	    E_Gren.Throw(self.muzzlePos, angles, vecThrow, time, self.owner)

		baseWeap.DepleteAmmo(self, 1)
    else
        E_Gren.Throw()

		if self.isLocal then
			self:ServerWpnCall("Throw", time)
		end

		PlaySound(self.snds["throw"], self.muzzlePos)
	end
end

function C_GREN:PrimaryAttack(dt)
	if 0 == self.startThrow and self.ammoTotal > 0 then
		self.startThrow = GetTime()
		self.releaseThrow = 0

		--self:KF_SetAnim(C_GREN.PINPULL)

		client.PWB_ANIMATOR[self.owner].forceSecondaryActionPose = true

		self.timeWeaponIdle = GetTime() + 0.5
	end
end

function C_GREN:WeaponIdle()
	if server then return end

	if self.releaseThrow == 0 and 0 ~= self.startThrow then
		self.releaseThrow = GetTime() end

	if self.timeWeaponIdle > GetTime() then
		return end

	if 0 ~= self.startThrow then
		-- alway explode 3 seconds after the pin was pulled
		local time = self.startThrow - GetTime() + 2.5
		if time < 0 then
			time = 0 end

		self:Throw(time)

		-- Stop "charging"
		client.PWB_ANIMATOR[self.owner].forceSecondaryActionPose = false

		-- Swing the grenade
		self.swingNumb = self.swingNumb - 1
		if self.swingNumb == -4 then self.swingNumb = -1 end
		client.PWB_ANIMATOR[self.owner].timeSinceFire = 0.0

		self.startThrow = 0
		self.nextFire = self:GetNextAttackDelay(0.5)
		self.timeWeaponIdle = GetTime() + 0.5

		self:DepleteAmmo(1)

		if 0 == self.ammoTotal then
			-- just threw last grenade
			-- set attack times in the future, and weapon idle in the future so we can see the whole throw
			-- animation, weapon idle will automatically retire the weapon for us.
			self.timeWeaponIdle = self:GetNextAttackDelay(0.5) -- ensure that the animation can finish playing
		end
	elseif self.releaseThrow > 0 then
		-- we've finished the throw, restart.
		self.startThrow = 0

		if 0 == self.ammoTotal then
			--RetireWeapon()
			-- REMOVE MODEL HERE
			return
		else
			self.timeWeaponIdle = GetTime() + GetRandomFloat(10, 15)
			self.releaseThrow = -1
		end
	end
end

function C_GREN:MDL_CallAnimator(dt)
	tickToolAnimator(client.PWB_ANIMATOR[self.owner], dt, nil, self.owner, self.swingNumb, nil, true)
end