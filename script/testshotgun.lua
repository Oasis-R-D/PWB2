CTestShotgun = {} -- goes in GLOBAL_WEAPONS

--=========================================================================
-- Define the weapon's SFX / VFX
--=========================================================================

function CTestShotgun:WeaponSounds()
	return {
		{"MOD/snd/sbarrel.ogg", 	  "sv", 10},
		{"MOD/snd/dbarrel.ogg", 	  "sv", 10},

		{"MOD/snd/sgcock.ogg", 		  "cl", 10},
		{"MOD/snd/sgshellin0.ogg",    "cl", 10},
		{"MOD/snd/sgreloadstart.ogg", "cl", 10},
	}
end

function CTestShotgun:muzzleFlash(pos, size, color)
	color = color or Vec(1, 1, 1)
	local t = Transform(pos)
	t.rot = QuatRotateQuat(GetCameraTransform().rot, QuatEuler(0,0,GetRandomFloat(-180, 180)))

	-- Create the flashSPR variable to hold the sprite
	if not CTestGun.flashSPR then CTestGun.flashSPR = LoadSprite("gfx/flare_0.png") end

	local spriteSize = size * 0.4
	DrawSprite(CTestGun.flashSPR, t, spriteSize, spriteSize, color[1], color[2], color[3], 1.0, true, true, true)
end

--=========================================================================
-- Define the weapon and it's variables
--=========================================================================

-- Static values for this specific weapon
-- These don't need redefined in a weapon if a var is just the default value
CTestShotgun.model				= "MOD/models/xml/shotgun.xml" -- path to the XML model file
CTestShotgun.casingOrg			= Vec(0.02, 0.05, 0.033)	-- where casings are ejected

CTestShotgun.toolID 			= "testshotgun"				-- used by the engine. lowercase and no spaces
CTestShotgun.toolName 			= "PWB2 Test ShotGun"		-- shown in killfeed
CTestShotgun.toolSlot			= 3

CTestShotgun.ammoLoadedMax 		= 8							-- max clip 	 	-- -1 for no clip (pulls from reserve)
CTestShotgun.ammoAltLoadedMax	= 0 						-- max alt clip 	-- -1 for no clip (pulls from reserve) 0 for no alt fire
CTestShotgun.ammoPickupSize		= CTestShotgun.ammoLoadedMax-- defaults to full mag
CTestShotgun.dmg_world			= 0.35
CTestShotgun.dmg_plyr			= 0.1						-- 0.0-1.0

CTestShotgun.flags				= FWPN_SV_CALLONCESEC		-- weapon flags
CTestShotgun.snds				= 0							-- temp value, will be set to the sound array on init

-- override initVars to add new variables
function CTestGun2:initVars(owner)
	baseWeap.initVars(self, owner)

	if client and self.isLocal then
		self.body = 0
		self.slide = 0
		self.slideTransform = Transform()

		self.slideTime = nil
	end
end

--=========================================================================
-- Weapon functions
--=========================================================================

function CTestShotgun:PrimaryAttack(dt)
	local mt = GetToolLocationWorldTransform("muzzle", self.owner)
	if not mt then return end

	if client then
		if self.ammoLoaded <= 0 then
			self:PlayEmptySound()
			self:Reload()
			return
		end

		self:RecoilPosPunch(Vec(0, 0.1, GetRandomFloat(0.15, 0.2)))

		if self.isLocal then
			PointLight(mt.pos, 1, 0.7, 0.5, 3)

			self:RecoilAngReset(-15)
			self:RecoilAngPunch(Vec(GetRandomFloat(2, 3), GetRandomFloat(-0.5, 0.5), GetRandomFloat(-2, 1)))

			-- shell ejection
			ejectBrass(self.owner, self.casingOrg, Vec(1, -0.2, 0), "MOD/models/xml/shell/casing_shtgn.xml", FSFX_SHTGN)
		end

		self:muzzleFlash(mt.pos, 2)
		
		self.ammoLoaded = self.ammoLoaded - 1

		self.pumpTime = GetTime() + 0.5

		self.specialReload = 0

		if self.ammoLoaded ~= 0 then
			self.timeWeaponIdle = GetTime() + 5.0
		else
			self.timeWeaponIdle = 1
		end
	else
		local eyePos = GetPlayerEyeTransform(self.owner).pos
		for i=1, 6 do
			local pos, dir = getAimVector(eyePos, 80, GLOBAL_10DEGREES, self.owner)
			server.ShootHook(pos, dir, "bullet", self.dmg_world, self.dmg_plyr, 80, self.owner, self.toolID, self.toolName)
		end

		PlayFireSound(self.snds[1], mt.pos, 300)

		baseWeap.DepleteAmmo(self, 4)
	end

	self.nextFire = self:GetNextAttackDelay(0.75)
	self.nextAltFire = GetTime() + 0.75
end

function CTestShotgun:SecondaryAttack(dt)
	local mt = GetToolLocationWorldTransform("muzzle", self.owner)
	if not mt then return end

	if client then
		if self.ammoLoaded <= 1 then
			self:PlayEmptySound()
			self:Reload()
			return
		end

		self:RecoilPosPunch(Vec(0, 0.2, GetRandomFloat(0.2, 0.3)))

		if self.isLocal then
			-- not likely to be full auto'd with the alt fire. Don't do 2 every shot, just send 1
			self:ServerWpnCall("SecondaryAttack", dt)

			PointLight(mt.pos, 1, 0.7, 0.5, 3)
			
			self:RecoilAngReset(-15)
			self:RecoilAngPunch(Vec(GetRandomFloat(4, 5), GetRandomFloat(-0.5, 0.5), GetRandomFloat(-5, -1)))

			-- shell ejection
			ejectBrass(self.owner, self.casingOrg, Vec(1, -0.2, 0), "MOD/models/xml/shell/casing_shtgn.xml", FSFX_SHTGN)
			ejectBrass(self.owner, self.casingOrg, Vec(1, -0.2, 0), "MOD/models/xml/shell/casing_shtgn.xml", FSFX_SHTGN)
		end

		self:muzzleFlash(mt.pos, 3, Vec(1.33, 1, 1))
		
		self.ammoLoaded = self.ammoLoaded - 2

		self.pumpTime = GetTime() + 0.95

		self.specialReload = 0

		if self.ammoLoaded ~= 0 then
			self.timeWeaponIdle = GetTime() + 6.0
		else
			self.timeWeaponIdle = 1.5
		end
	else
		local eyePos = GetPlayerEyeTransform(self.owner).pos
		for i=1, 12 do
			local pos, dir = getAimVector(eyePos, 80, GLOBAL_10DEGREES, self.owner)
			server.ShootHook(pos, dir, "bullet", self.dmg_world, self.dmg_plyr, 80, self.owner, self.toolID, self.toolName)
		end

		PlayFireSound(self.snds[2], mt.pos, 300)

		baseWeap.DepleteAmmo(self, 4)
	end

	self.nextFire = self:GetNextAttackDelay(1.5)
	self.nextAltFire = GetTime() + 1.5
end

function CTestShotgun:Reload()
	if self.ammoTotal <= 0 or self.ammoLoaded == self.ammoLoadedMax then
		return end

	local curTime = GetTime()

	-- don't reload until recoil is done
	if self.nextFire > curTime then
		return end

	local mt = GetToolLocationWorldTransform("muzzle", self.owner)

	-- check to see if we're ready to reload
	if self.specialReload == 0 then
		if self.isLocal then 
			self:RecoilAngPunch(Vec(0, 2, -10))
			PlaySound(self.snds[3], mt.pos, 300)
		end

		-- hold gun straight
		self.animator.timeSinceFire = 0.0

		self.specialReload = 1
		self.timeWeaponIdle = curTime + 0.6
		self.nextFire = self:GetNextAttackDelay(1.0)
		self.nextAltFire = curTime + 1.0
		return
	elseif self.specialReload == 1 then
		-- waiting for gun to move to side
		if self.timeWeaponIdle > curTime then
			return end
		
		self.specialReload = 2

		PlayFireSound(self.snds[2], mt.pos, 300)

		if self.isLocal then self:RecoilAngPunch(Vec(GetRandomFloat(3, 4), GetRandomFloat(0, 1), GetRandomFloat(-6, -2))) end
		self:RecoilPosPunch(Vec(0, 0.1, 0.1))

		self.timeWeaponIdle = curTime + 0.5
	else
		-- Add them to the clip
		self.ammoLoaded = self.ammoLoaded + 1
		self.specialReload = 1

		-- hold gun straight
		self.animator.timeSinceFire = 0.0
	end
end

function CTestShotgun:WeaponIdle()
	self.playEmptySound = true

	if server then return end

	local curTime = GetTime()

	if self.timeWeaponIdle < curTime then
		if self.ammoLoaded == 0 and self.specialReload == 0 and 0 ~= self.ammoTotal then
			self:Reload()
		elseif self.specialReload ~= 0 then
			if self.ammoLoaded ~= self.ammoLoadedMax and 0 ~= self.ammoTotal then
				self:Reload()
			else
				-- reload debounce has timed out
				self.slideTime = 0

				local mt = GetToolLocationWorldTransform("muzzle", self.owner)

				-- play cocking sound
				PlaySound(self.snds[1], mt.pos, 300)

				self.specialReload = 0
				self.timeWeaponIdle = curTime + 1.5
			end
		end
	end
end

function CTestShotgun:tickPlayer_cl(dt)
	if 0 ~= self.pumpTime and self.pumpTime <= GetTime() then
		local mt = GetToolLocationWorldTransform("muzzle", self.owner)

		-- play pumping sound
		PlaySound(self.snds[1], mt.pos, 300)

		self.slideTime = 0
		self.pumpTime = 0
	end

	baseWeap.tickPlayer_cl(self, dt)
end

function CTestShotgun:CustomAnimate(dt)
	--Animate Slide
	local GunBody = GetToolBody(p)
	if self.body ~= GunBody then
		self.body = GunBody
		-- Slide is the third shape in vox file. Remember original position in attachment frame
		local shapes = GetBodyShapes(GunBody)
		self.slide = shapes[3]
		self.slideTransform = GetShapeLocalTransform(self.slide)
	end
	if self.slide and self.slideTime ~= nil then
		self.slideTime = self.slideTime + dt
	
		local UseValue = self.slideTime

		-- don't go over, add a delay between the pump forward!
		if self.slideTime >= 0.375 then
			self.slideTime = 0.375
		elseif self.slideTime > 0.125 and self.slideTime < 0.25 then
			UseValue = 0.125 -- lock back for a little
		elseif self.slideTime >= 0.25 then
			UseValue = self.slideTime - 0.125
		end

		-- Slide has returned
		if self.slideTime >= 0.375 then
			SetShapeLocalTransform(self.slide, self.slideTransform) -- force back just in case
			self.slideTime = nil
		else
			local position = Vec(0, 0, 0.10 * math.sin(4 * math.pi * UseValue))
			local TOffset = Transform(position)
			self.animator.leftHand.transform.pos = position

			local t = TransformToParentTransform(TOffset, self.slideTransform)
			SetShapeLocalTransform(self.slide, t)
		end
	end
end