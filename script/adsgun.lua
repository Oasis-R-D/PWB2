CAdsGun = {} -- goes in GLOBAL_WEAPONS

--=========================================================================
-- Define the weapon's SFX / VFX
--=========================================================================

function CAdsGun:WeaponSounds()
	return {
		{"MOD/snd/smg1_fire.ogg", "sv", 10},
		{"MOD/snd/smg1_reload.ogg", "cl", 10},
		{"MOD/snd/smg1_reload.ogg", "cl", 10, true}
	}
end

function CAdsGun:muzzleFlash(pos, size, color)
	color = color or Vec(1, 1, 1)
	local t = Transform(pos)
	t.rot = QuatRotateQuat(GetCameraTransform().rot, QuatEuler(0,0,GetRandomFloat(-15, 15)))

	-- Create the flashSPR variable to hold the sprite
	if not CAdsGun.flashSPR then CAdsGun.flashSPR = LoadSprite("gfx/flare_0.png") end

	local spriteSize = size * 0.4
	DrawSprite(CAdsGun.flashSPR, t, spriteSize, spriteSize, color[1], color[2], color[3], 1.0, true, true, true)
end

--=========================================================================
-- Define the weapon and it's variables
--=========================================================================

-- Static values for this specific weapon
-- These don't need redefined in a weapon if a var is just the default value
CAdsGun.model				= "MOD/models/xml/grease.xml"-- path to the XML model file
CAdsGun.casingOrg			= Vec(0.01, 0.12, -0.15)	 -- where casings are ejected

CAdsGun.toolID 				= "adsgun"		  -- used by the engine. lowercase and no spaces
CAdsGun.toolName 			= "PWB2 Ads Gun" -- shown in killfeed
CAdsGun.toolSlot			= 3

CAdsGun.ammoLoadedMax 		= 30					-- max clip 	 	-- -1 for no clip (pulls from reserve)
CAdsGun.ammoAltLoadedMax	= 0 					-- max alt clip 	-- -1 for no clip (pulls from reserve) 0 for no alt fire
CAdsGun.ammoAltItemID		= 0 					-- wpnID of item to drain ammo for when altfiring
CAdsGun.ammoPickupSize		= CAdsGun.ammoLoadedMax	-- defaults to full mag
CAdsGun.dmg_world			= 0.5
CAdsGun.dmg_plyr			= 0.16					-- 0.0-1.0

CAdsGun.flags				= addFlags(0, FWPN_SV_CALLONCESEC, FWPN_CLICK_SEC) -- weapon flags
CAdsGun.snds				= 0												   -- temp value, will be set to the sound array on init

-- override initVars to add new variables
function CAdsGun:initVars(owner)
	baseWeap.initVars(self, owner)

	if server then
		self.ads = false
	end
end

--=========================================================================
-- Weapon functions
--=========================================================================

function CAdsGun:PrimaryAttack(dt)
	local mt = GetToolLocationWorldTransform("muzzle", self.owner)
	if not mt then return end

	if client then
		if self.ammoLoaded <= 0 then
			self:PlayEmptySound()
			self.nextFire = GetTime() + 0.15
			return
		end

		if self.isLocal then
			PointLight(mt.pos, 1, 0.7, 0.5, 3)

			local punchVec = Vec()
			if self.animator.forceSecondaryActionPose then
				punchVec = Vec(GetRandomFloat(-0.025, 0.025), GetRandomFloat(0.0, 0.0125), GetRandomFloat(0.025, 0.025))

				self:RecoilAngPunch(Vec(GetRandomFloat(0.25, 0.66), GetRandomFloat(-0.4, 0.4), GetRandomFloat(-0.33, 0.33)))
			else
				punchVec = Vec(GetRandomFloat(-0.05, 0.05), GetRandomFloat(0.0, 0.025), GetRandomFloat(0.05, 0.1))

				self:RecoilAngReset(-4)
				self:RecoilAngPunch(Vec(GetRandomFloat(1, 3), GetRandomFloat(-2, 2), GetRandomFloat(-1, 1)))
			end

			client.SRC_PunchReset()
			for i=1, 3 do
				client.SRC_PunchAxis(i, punchVec[4-i] * 10)
			end

			self:RecoilPosPunch(punchVec)

			-- shell ejection
			ejectBrass(self.owner, self.casingOrg, Vec(1, -1, 0), "MOD/models/xml/shell/casing_45acp.xml", FSFX_BRASS)
		else
			self:RecoilPosPunch(Vec(GetRandomFloat(-0.05, 0.05), GetRandomFloat(0.0, 0.025), GetRandomFloat(0.05, 0.1)))
		end

		self:muzzleFlash(mt.pos, 1)
		
		self.ammoLoaded = self.ammoLoaded - 1
	else
		local pos, dir = getAimVector(GetPlayerEyeTransform(self.owner).pos, 100, self.ads and GLOBAL_1DEGREE or GLOBAL_3DEGREES, self.owner)
	
		server.ShootHook(pos, dir, "bullet", self.dmg_world, self.dmg_plyr, 100, self.owner, self.toolID, self.toolName)

		PlayFireSound(self.snds[1], mt.pos, 300)

		baseWeap.DepleteAmmo(self)
	end

	self.nextFire = self:GetNextAttackDelay(0.133)
end

function CAdsGun:Reload()
	if not self:DefaultReload(1.5) then return end
	
	if self.isLocal then
		self:PlayFollowingSound(self.snds[2], 1.258)
	else
		PlaySound(self.snds[1], GetPlayerPos(self.owner), 1)
	end
end

function CAdsGun:SecondaryAttack(dt, ads)
	if self.isLocal then
		self:ServerWpnCall("SecondaryAttack", dt, not self.animator.forceSecondaryActionPose)
	end

	if client then
		self.animator.forceSecondaryActionPose = not self.animator.forceSecondaryActionPose
	else
		self.ads = ads
	end

	self.nextFire = self:GetNextAttackDelay(0.33)
	self.nextAltFire = GetTime() + 0.5
end

function CAdsGun:WeaponIdle()
	self.playEmptySound = true
end

function CAdsGun:tickPlayer_cl(dt)
	if self.isLocal and self.animator.forceSecondaryActionPose then
		self.idleCycleScale = 0.1 end

	baseWeap.tickPlayer_cl(self, dt)
end
