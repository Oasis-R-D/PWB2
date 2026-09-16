C_Shtgn = {} -- goes in GLOBAL_WEAPONS

--=========================================================================
-- Define the weapon and it's variables
--=========================================================================

-- Static values for this specific weapon
-- These don't need redefined in a weapon if a var is just the default value
C_Shtgn.model	   = "shotgun.xml" 		    -- Path to the XML model file
C_Shtgn.casingOrg = Vec(0.02, 0.08, 0.022) -- Where casings are ejected

C_Shtgn.toolID   = "testsg"  	   -- Used by the engine. Lowercase and no spaces
C_Shtgn.toolName = "PWB2 Shotgun" -- Shown in killfeed
C_Shtgn.toolSlot = 3

C_Shtgn.ammoLoadedMax 	  = 8						   -- Max clip 	 	-- -1 for no clip (pulls from reserve)
C_Shtgn.ammoAltLoadedMax = 0 						   -- Max alt clip 	-- -1 for no clip (pulls from reserve) 0 for no alt fire
C_Shtgn.ammoPickupSize	  = C_Shtgn.ammoLoadedMax -- Defaults to full mag
C_Shtgn.dmg_world		  = 0.35					   -- Size of hole in meters
C_Shtgn.dmg_plyr		  = 0.1						   -- 0.0-1.0

C_Shtgn.flags = addFlags(0, FWPN_SV_CALLONCE_PRIM,
								 FWPN_SV_CALLONCE_SEC,
								 FWPN_CLICK_PRIM,
								 FWPN_CLICK_SEC) -- Weapon flags
C_Shtgn.snds = 0 -- Prechached SFX list, set on INIT

-- override initVars to add new variables
function C_Shtgn:initVars(owner)
	baseWeap.initVars(self, owner)

	if client and self.isLocal then
		self.body = 0
		self.slide = 0
		self.slideTransform = Transform()

		self.slideTime = nil
	end
end

--=========================================================================
-- Define the weapon's SFX / VFX
--=========================================================================

function C_Shtgn:Sounds()
	return {
		{"sbarrel.ogg", 	  "sv", 10},
		{"dbarrel.ogg", 	  "sv", 10},

		{"sgcock.ogg", 		  "cl", 10},
		{"sgshellin0.ogg",    "cl", 10},
		{"sgreloadstart.ogg", "cl", 10},
	}
end

function C_Shtgn:muzzleFlash(pos, size, color)
	color = color or Vec(1, 1, 1)

	if self.isLocal then
		pos = VecAdd(pos, VecScale(GetPlayerVelocity(), GetTimeStep()))
	end

	local t = Transform(pos)
	t.rot = QuatRotateQuat(GetCameraTransform().rot, QuatEuler(0,0,GetRandomFloat(-180, 180)))

	-- Create the flashSPR variable to hold the sprite
	if not CTestGun.flashSPR then CTestGun.flashSPR = LoadSprite("gfx/flare_0.png") end

	DrawSprite(CTestGun.flashSPR, t, size, size, color[1], color[2], color[3], 1.0, true, true, true)
end

--=========================================================================
-- Weapon functions
--=========================================================================

function C_Shtgn:Holster()
	if client then
		client.PWB_ANIMATOR[self.owner].leftHand.transform.pos = Vec()
	end
end

function C_Shtgn:PrimaryAttack(dt)
	local mt = GetToolLocationWorldTransform("muzzle", self.owner)
	if not mt then return end

	if client then
		if self.ammoLoaded <= 0 then
			self:PlayEmptySound()
			self:Reload()
			return
		end

		self:MDL_PunchPos(Vec(0, 0.1, GetRandomFloat(0.15, 0.2)))

		if self.isLocal then
			self:ServerWpnCall("PrimaryAttack", dt)

			client.VFX_DynLight(self.owner, 30, 0.25, Vec(0.7, 0.5, 0.3), Vec(), "muzzle")

			self:MDL_PunchAngReset(-15)
			self:MDL_PunchAng(Vec(GetRandomFloat(2, 3), GetRandomFloat(-0.5, 0.5), GetRandomFloat(-2, 1)))

			client.PUNCH_Axis(1, 2)
			client.PUNCH_Axis(2, GetRandomFloat(-0.5, 0.5))
		end

		self:muzzleFlash(mt.pos, 0.8)

		self.pumpTime = GetTime() + 0.5

		self.specialReload = 0

		if self.ammoLoaded ~= 0 then
		else
			self.timeWeaponIdle = 1
		end
	else
		PlayFireSound(self.snds[1], mt.pos, 300)
	end

	baseWeap.DepleteAmmo(self, 1, 1)

	self:FireBulletsPlayer(6, GetPlayerEyeTransform(self.owner).pos, GLOBAL_10DEGREES, 80)

	self.nextFire = self:GetNextAttackDelay(0.75)
	self.nextAltFire = GetTime() + 0.75
end

function C_Shtgn:SecondaryAttack(dt)
	local mt = GetToolLocationWorldTransform("muzzle", self.owner)
	if not mt then return end

	if client then
		if self.ammoLoaded <= 1 then
			self:PlayEmptySound()
			self:Reload()
			return
		end

		self:MDL_PunchPos(Vec(0, 0.2, GetRandomFloat(0.2, 0.3)))

		if self.isLocal then
			self:ServerWpnCall("SecondaryAttack", dt)

			client.VFX_DynLight(self.owner, 40, 0.5, Vec(0.7, 0.5, 0.3), Vec(), "muzzle")

			self:MDL_PunchAngReset(-15)
			self:MDL_PunchAng(Vec(GetRandomFloat(4, 5), GetRandomFloat(-0.5, 0.5), GetRandomFloat(-5, -1)))

			client.PUNCH_Axis(1, 5)
			client.PUNCH_Axis(2, GetRandomFloat(-0.5, 0.5))
			
			-- shell ejection
			client.TENT_EjectShell(self.owner, self.casingOrg, Vec(1, -0.2, 0), "MOD/models/xml/shell/casing_shtgn.xml", FSFX_SHTGN)
		end

		self:muzzleFlash(mt.pos, 1.2, Vec(1.33, 1, 1))

		self.pumpTime = GetTime() + 0.95

		self.specialReload = 0

		if self.ammoLoaded ~= 0 then
		else
			self.timeWeaponIdle = 1.5
		end
	else
		PlayFireSound(self.snds[2], mt.pos, 300)
	end

	baseWeap.DepleteAmmo(self, 2, 2)

	self:FireBulletsPlayer(12, GetPlayerEyeTransform(self.owner).pos, GLOBAL_10DEGREES, 80)

	self.nextFire = self:GetNextAttackDelay(1.5)
	self.nextAltFire = GetTime() + 1.5
end

function C_Shtgn:Reload()
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
			self:MDL_PunchAng(Vec(0, 2, -10))
			PlaySound(self.snds[3], mt.pos, 300)
		end

		if self.ammoLoaded == 0 then self.pumpTime = -1 end

		-- hold gun straight
		client.PWB_ANIMATOR[self.owner].timeSinceFire = 0.0

		self.specialReload = 3
		self.timeWeaponIdle = curTime + 0.6
		self.nextFire = self:GetNextAttackDelay(1.0)
		self.nextAltFire = curTime + 1.0
		return
	elseif self.specialReload == 1 or self.specialReload == 3 then
		-- waiting for gun to move to side
		if self.timeWeaponIdle > curTime then
			return end

		-- fixes first shell not adding to clip
		--if true or self.specialReload == 3 then
			-- Add them to the clip
			self.ammoLoaded = self.ammoLoaded + 1
		--end

		self.specialReload = 2

		PlayFireSound(self.snds[2], mt.pos, 300)

		if self.isLocal then
			self:MDL_PunchAng(Vec(GetRandomFloat(3, 4), GetRandomFloat(0, 1), GetRandomFloat(-6, -2)))
			client.PUNCH_Axis(3, -0.33)
			client.PUNCH_Axis(1, -0.33)
		end

		self:MDL_PunchPos(Vec(0, 0.1, 0.1))

		self.timeWeaponIdle = curTime + 0.5
	else
		-- Add them to the clip
		--self.ammoLoaded = self.ammoLoaded + 1

		self.specialReload = 1

		-- hold gun straight
		client.PWB_ANIMATOR[self.owner].timeSinceFire = 0.0
	end
end

function C_Shtgn:WeaponIdle()
	self.playEmptySound = true

	if server then return end

	local curTime = GetTime()

	if self.timeWeaponIdle < curTime then
		if self.ammoLoaded == 0 and self.specialReload == 0 and self.ammoLoaded ~= self.ammoTotal then
			self:Reload()
		elseif self.specialReload ~= 0 then
			if self.ammoLoaded ~= self.ammoLoadedMax and self.ammoLoaded ~= self.ammoTotal then
				self:Reload()
			else
				if self.pumpTime == -1 then
					self.pumpTime = 0

					-- reload debounce has timed out
					if self.isLocal then
						self.slideTime = 0

						-- shell ejection
						client.TENT_EjectShell(self.owner, self.casingOrg, Vec(1, -0.2, 0), "MOD/models/xml/shell/casing_shtgn.xml", FSFX_SHTGN)
					end

					local mt = GetToolLocationWorldTransform("muzzle", self.owner)

					-- play cocking sound
					PlaySound(self.snds[1], mt.pos, 300)
				end

				self.specialReload = 0
				self.timeWeaponIdle = curTime + 1.5
			end
		end
	end
end

function C_Shtgn:tickPlayer_cl(dt)
	if self.pumpTime > 0 and self.pumpTime <= GetTime() then
		local mt = GetToolLocationWorldTransform("muzzle", self.owner)

		-- play pumping sound
		PlaySound(self.snds[1], mt.pos, 300)

		if self.isLocal then
			self.slideTime = 0

			-- shell ejection
			client.TENT_EjectShell(self.owner, self.casingOrg, Vec(1, -0.2, 0), "MOD/models/xml/shell/casing_shtgn.xml", FSFX_SHTGN)
		end

		self.pumpTime = 0
	end

	baseWeap.tickPlayer_cl(self, dt)
end

function C_Shtgn:MDL_CustomAnimate(dt)
	if not self.isLocal then return end

	--Animate Slide
	local GunBody = GetToolBody()
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
			client.PWB_ANIMATOR[self.owner].leftHand.transform.pos = position

			local t = TransformToParentTransform(TOffset, self.slideTransform)
			SetShapeLocalTransform(self.slide, t)
		end
	end
end