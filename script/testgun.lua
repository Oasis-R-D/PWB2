CTestGun = {} -- goes in GLOBAL_WEAPONS

--=========================================================================
-- Define the weapon's SFX / VFX
--=========================================================================

function CTestGun:WeaponSounds()
	return {
		{"MOD/snd/smg1_fire.ogg", 	"sv", 10},
		{"MOD/snd/smg1_reload.ogg", "cl", 10},
		{"MOD/snd/smg1_reload.ogg", "cl", 10, true}
	}
end

--=========================================================================
-- Define the weapon and it's variables
--=========================================================================

-- Static values for this specific weapon
-- These don't need redefined in a weapon if a var is just the default value
CTestGun.model				= "MOD/models/xml/smg1.xml" -- path to the XML model file
CTestGun.casingOrg			= Vec(0.02, 0.15, -0.15)	-- where casings are ejected

CTestGun.toolID 			= "testgun"	  -- used by the engine. lowercase and no spaces
CTestGun.toolName 			= "PWB2 Test Gun" -- shown in killfeed
CTestGun.toolSlot			= 3

CTestGun.ammoLoadedMax 	= 45					 -- max clip 	 	-- -1 for no clip (pulls from reserve)
CTestGun.ammoAltLoadedMax	= 0 				 -- max alt clip 	-- -1 for no clip (pulls from reserve) 0 for no alt fire
CTestGun.ammoPickupSize	= CTestGun.ammoLoadedMax -- defaults to full mag
CTestGun.dmg_world			= 0.4
CTestGun.dmg_plyr			= 0.05				 -- 0.0-1.0

CTestGun.flags				= 0	-- weapon flags
CTestGun.snds				= 0	-- temp value, will be set to the sound array on init

-- override initVars to add new variables
function CTestGun:initVars(owner)
	if client then
		self.timeFiring = 0
	end

	baseWeap.initVars(self, owner)
end

--=========================================================================
-- Weapon functions
--=========================================================================

function CTestGun:PrimaryAttack(dt)
	local mt = GetToolLocationWorldTransform("muzzle", self.owner)
	if not mt then return end
	
	if client then
		if self.ammoLoaded <= 0 then
			self:PlayEmptySound()
			self.nextFire = GetTime() + 0.15
			self.nextAltFire = self.nextFire
			return
		end

		if GetTime() - self.lastFireTime < 0.1 then
			self.timeFiring = self.timeFiring + 0.1
		else
			self.timeFiring = 0
		end

		self:RecoilPosPunch(Vec(0, 0, GetRandomFloat(0.133, 0.166)))

		if self.isLocal then
			PointLight(mt.pos, 1, 0.7, 0.5, 3)

			client.DoMachineGunKick(1, self.timeFiring, 2)
			
			self:RecoilAngReset(-15)
			self:RecoilAngPunch(Vec(GetRandomFloat(0.5, 1), GetRandomFloat(-0.5, 0.5), GetRandomFloat(-1, 1)))

			-- shell ejection
			ejectBrass(self.owner, self.casingOrg, Vec(1, -0.2, 0), "MOD/models/xml/shell/casing_9mm.xml", FSFX_BRASS)
		end

		self:muzzleFlash(mt.pos, 2)
		
		self.ammoLoaded = self.ammoLoaded - 1
	else
		local pos, dir = getAimVector(GetPlayerEyeTransform(self.owner).pos, 100, GLOBAL_5DEGREES, self.owner)
		server.ShootHook(pos, dir, "bullet", self.dmg_world, self.dmg_plyr, 100, self.owner, self.toolID, self.toolName)
		
		PlayFireSound(self.snds[1], mt.pos, 300)

		baseWeap.DepleteAmmo(self)
	end
	
	self.nextFire = self:GetNextAttackDelay(0.075)
	self.nextAltFire = GetTime() + 0.075
end

function CTestGun:SV_FireAltEmptyCond()
	if self.ammoLoaded <= 3 then return true end

	return false
end

function CTestGun:SecondaryAttack(dt)
	local mt = GetToolLocationWorldTransform("muzzle", self.owner)
	if not mt then return end

	if client then
		if self.ammoLoaded <= 3 then
			self:PlayEmptySound()
			self.nextFire = GetTime() + 0.15
			self.nextAltFire = self.nextFire
			return
		end

		if GetTime() - self.lastFireTime < 0.1 then
			self.timeFiring = self.timeFiring + 0.1
		else
			self.timeFiring = 0
		end

		self:RecoilPosPunch(Vec(0, 0, GetRandomFloat(0.133, 0.166)))

		if self.isLocal then
			PointLight(mt.pos, 1, 0.7, 0.5, 3)

			client.DoMachineGunKick(1, self.timeFiring, 2)
			
			self:RecoilAngReset(-15)
			self:RecoilAngPunch(Vec(GetRandomFloat(0.5, 1), GetRandomFloat(-0.5, 0.5), GetRandomFloat(-1, 1)))

			-- shell ejection
			ejectBrass(self.owner, self.casingOrg, Vec(1, -0.2, 0), "MOD/models/xml/shell/casing_9mm.xml", FSFX_BRASS)
		end

		self:muzzleFlash(mt.pos, 2)
		
		self.ammoLoaded = self.ammoLoaded - 4
	else
		for i=1, 4 do
			local pos, dir = getAimVector(GetPlayerEyeTransform(self.owner).pos, 100, GLOBAL_5DEGREES, self.owner)
			server.ShootHook(pos, dir, "bullet", self.dmg_world, self.dmg_plyr, 100, self.owner, self.toolID, self.toolName)
		end

		PlayFireSound(self.snds[1], mt.pos, 300)

		baseWeap.DepleteAmmo(self, 4)
	end

	-- Use get time because GetNextAttackDelay breaks here
	self.nextFire = GetTime() + 0.5
	self.nextAltFire = self.nextFire
end

function CTestGun:Reload()
	if not self:DefaultReload(1.5) then return end

	if self.isLocal then
		self:PlayFollowingSound(self.snds[2], 1.258)
	else
		PlaySound(self.snds[1], GetPlayerPos(self.owner), 1)
	end
end

function CTestGun:WeaponIdle()
	self.playEmptySound = true
end