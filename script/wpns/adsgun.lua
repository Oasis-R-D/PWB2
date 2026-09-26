C_ADSgun = {} -- goes in GLOBAL_WEAPONS

--=========================================================================
-- Define the weapon and it's variables
--=========================================================================

-- Static values for this specific weapon
-- These don't need redefined in a weapon if a var is just the default value found in baseWeap

C_ADSgun.model	   = "grease.xml"		    -- Path to the XML model file
C_ADSgun.casingOrg = Vec(0.01, 0.12, -0.15) -- Where casings are ejected

C_ADSgun.toolID   = "testads"  -- Used by the engine. Lowercase and no spaces
C_ADSgun.toolName = "PWB2 ADS" -- Shown in killfeed
C_ADSgun.toolSlot = 3
C_ADSgun.toolPos  = 3		   -- placement in the hud column

C_ADSgun.ammoLoadedMax 	  = 30					   -- Max clip 	 	-- -1 for no clip (pulls from reserve)
C_ADSgun.ammoAltLoadedMax = 0 					   -- Max alt clip 	-- -1 for no clip (pulls from reserve) 0 for no alt fire
C_ADSgun.ammoAltItemID	  = 0 					   -- WpnID of item to drain ammo for when altfiring
C_ADSgun.ammoPickupSize	  = C_ADSgun.ammoLoadedMax -- Defaults to full mag
C_ADSgun.dmg_world		  = 0.5					   -- Size of hole in meters
C_ADSgun.dmg_plyr		  = 0.16				   -- 0.0-1.0

C_ADSgun.flags= addFlags(0, FWPN_SV_CALLONCE_SEC, FWPN_CLICK_SEC) -- Weapon flags
C_ADSgun.snds = 0 -- Prechached SFX list, set on INIT 

-- override initVars to add new variables
function C_ADSgun:initVars(owner)
	baseWeap.initVars(self, owner)

	if server then
		self.ads = false
	end
end

--=========================================================================
-- Define the weapon's SFX / VFX
--=========================================================================

function C_ADSgun:Sounds()
	return {
		{"smg1_fire.ogg",   "sv", "fire"  },
		{"smg1_reload.ogg", "cl", "reload"},
		{"smg1_reload.ogg", "cl", "reloadLoop", true}
	}
end

function C_ADSgun:muzzleFlash(pos, size, color)
	color = color or Vec(1, 1, 1)

	if self.isLocal then
		pos = VecAdd(pos, VecScale(GetPlayerVelocity(), GetTimeStep()))
	end

	local t = Transform(pos)
	t.rot = QuatRotateQuat(GetCameraTransform().rot, QuatEuler(0,0,GetRandomFloat(-15, 15)))

	-- Create the flashSPR variable to hold the sprite
	if not C_ADSgun.flashSPR then C_ADSgun.flashSPR = LoadSprite("gfx/flare_0.png") end

	DrawSprite(C_ADSgun.flashSPR, t, size, size, color[1], color[2], color[3], 1.0, true, true, true)
end

--=========================================================================
-- Weapon functions
--=========================================================================

function C_ADSgun:Holster()
	if client then
		client.PWB_ANIMATOR[self.owner].forceSecondaryActionPose = false
		if self.isLocal then client.FOV_set(1) end
	else
		self.ads = false
	end
end

function C_ADSgun:PrimaryAttack(dt)
	local mt = GetToolLocationWorldTransform("muzzle", self.owner)
	if not mt then return end

	if client then
		if self.ammoLoaded <= 0 then
			self:PlayEmptySound()
			self.nextFire = GetTime() + 0.15
			return
		end

		if self.isLocal then
			client.VFX_DynLight(self.owner, 25, 0.1, Vec(0.7, 0.5, 0.3), Vec(), "muzzle")

			local punchVec = Vec()
			if client.PWB_ANIMATOR[self.owner].forceSecondaryActionPose then
				punchVec = Vec(GetRandomFloat(-0.025, 0.025), GetRandomFloat(0.0, 0.0125), GetRandomFloat(0.025, 0.025))

				self:MDL_PunchAng(Vec(GetRandomFloat(0.25, 0.66), GetRandomFloat(-0.4, 0.4), GetRandomFloat(-0.33, 0.33)))
			else
				punchVec = Vec(GetRandomFloat(-0.05, 0.05), GetRandomFloat(0.0, 0.025), GetRandomFloat(0.05, 0.1))

				self:MDL_PunchAngReset(-4)
				self:MDL_PunchAng(Vec(GetRandomFloat(1, 3), GetRandomFloat(-2, 2), GetRandomFloat(-1, 1)))
			end

			client.PUNCH_Reset()
			for i=1, 3 do
				client.PUNCH_Axis(i, punchVec[4-i] * 10)
			end

			self:MDL_PunchPos(punchVec)

			-- shell ejection
			client.TENT_EjectShell(self.owner, self.casingOrg, Vec(1, -1, 0), "MOD/models/xml/shell/casing_45acp.xml", FSFX_BRASS)
		else
			self:MDL_PunchPos(Vec(GetRandomFloat(-0.05, 0.05), GetRandomFloat(0.0, 0.025), GetRandomFloat(0.05, 0.1)))
		end

		self:muzzleFlash(mt.pos, 0.4)
	else
		PlayFireSound(self.snds["fire"], mt.pos, 300)
	end

	baseWeap.DepleteAmmo(self, 1, 1)

	local inAds = (server and self.ads) or (client and client.PWB_ANIMATOR[self.owner].forceSecondaryActionPose)
	self:FireBulletsPlayer(1, GetPlayerEyeTransform(self.owner).pos, inAds and GLOBAL_1DEGREE or GLOBAL_3DEGREES, 100)

	self.nextFire = self:GetNextAttackDelay(0.133)
end

function C_ADSgun:Reload()
	if not self:DefaultReload(1.5) then return end

	if self.isLocal then
		self:KF_SetAnim(C_ADSgun.ANIM_RELOAD)

		self:PlayFollowingSound(self.snds["reloadLoop"], 1.258)

		if client.PWB_ANIMATOR[self.owner].forceSecondaryActionPose then
			self:ServerWpnCall("SecondaryAttack", 0, false)
			client.FOV_set(1)
		end
	else
		PlaySound(self.snds["reload"], GetPlayerPos(self.owner), 1)
	end

	client.PWB_ANIMATOR[self.owner].forceSecondaryActionPose = false
end

function C_ADSgun:SecondaryAttack(dt, ads)
	if client then
		ads = not client.PWB_ANIMATOR[self.owner].forceSecondaryActionPose
		client.PWB_ANIMATOR[self.owner].forceSecondaryActionPose = ads

		if self.isLocal then
			self:ServerWpnCall("SecondaryAttack", dt, ads)
			if ads then
				client.FOV_set(0.9)

				self:MDL_PunchAngReset()
				self:MDL_PunchAng(Vec(-1, 0, 0.5))
			else
				client.FOV_set(1)

				self:MDL_PunchAngReset()
				self:MDL_PunchAng(Vec(1, 0, -0.5))
			end
		end
	else
		self.ads = ads
	end

	self.nextFire = self:GetNextAttackDelay(0.33)
	self.nextAltFire = self.nextFire
end

function C_ADSgun:WeaponIdle()
	self.playEmptySound = true
end

function C_ADSgun:tickPlayer_cl(dt)
	if self.isLocal then
		if client.PWB_ANIMATOR[self.owner].forceSecondaryActionPose then
			self.idleCycleScale = 0.05
		end
	end

	baseWeap.tickPlayer_cl(self, dt)
end