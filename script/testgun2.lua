CTestGun2 = {} -- goes in GLOBAL_WEAPONS

--=========================================================================
-- Define the weapon's SFX / VFX
--=========================================================================

function CTestGun2:WeaponSounds()
	return {
		{"MOD/snd/smg1_fire.ogg", "sv", 10}
	}
end

--=========================================================================
-- Define the weapon and it's variables
--=========================================================================

-- Static values for this specific weapon
-- These don't need redefined in a weapon if a var is just the default value
CTestGun2.model				= "MOD/models/xml/smg1.xml" -- path to the XML model file
CTestGun2.casingOrg			= Vec(0.02, 0.15, -0.15)	-- where casings are ejected

CTestGun2.toolID 			= "testgun2"				-- used by the engine. lowercase and no spaces
CTestGun2.toolName 			= "PWB2 Test Gun"			-- shown in killfeed
CTestGun2.toolSlot			= 3

CTestGun2.ammoLoadedMax 	= 45						-- max clip 	 	-- -1 for no clip (pulls from reserve)
CTestGun2.ammoAltLoadedMax	= 0 						-- max alt clip 	-- -1 for no clip (pulls from reserve) 0 for no alt fire
CTestGun2.ammoPickupSize	= CTestGun2.ammoLoadedMax	-- defaults to full mag
CTestGun2.dmg_world			= 0.4
CTestGun2.dmg_plyr			= 0.05						-- 0.0-1.0

CTestGun2.flags				= 0							-- weapon flags
CTestGun2.snds				= 0							-- temp value, will be set to the sound array on init

-- override initVars to add new variables
function CTestGun2:initVars(owner)
	if client then
		self.timeFiring = 0
	end

	baseWeap.initVars(self, owner)
end

--=========================================================================
-- Weapon functions
--=========================================================================

function CTestGun2Fire(p)
	local mt = GetToolLocationWorldTransform("muzzle", p)

	local pos, dir = getAimVector(GetPlayerEyeTransform(p).pos, 100, GLOBAL_5DEGREES, p)
	server.ShootHook(pos, dir, "bullet", CTestGun2.dmg_world, CTestGun2.dmg_plyr, 100, p, CTestGun2.toolID, CTestGun2.toolName)
	
	PlayFireSound(CTestGun2.snds[1], mt.pos, 300)

	baseWeap.DepleteAmmo(CTestGun2)
end

function CTestGun2:PrimaryAttack(dt)
	if self.ammoLoaded <= 0 then
		self:PlayEmptySound()
		self.nextFire = GetTime() + 0.15
		self.nextAltFire = self.nextFire
		return
	end

	local mt = GetToolLocationWorldTransform("muzzle", self.owner)

	if GetTime() - self.lastFireTime < 0.1 then
		self.timeFiring = self.timeFiring + 0.1
	else
		self.timeFiring = 0
	end

	self:RecoilPosPunch(Vec(0, 0, GetRandomFloat(0.133, 0.166)))

	if IsPlayerLocal(self.owner) then
		mt.pos = VecAdd(mt.pos, VecScale(GetPlayerVelocity(), dt))

		PointLight(mt.pos, 1, 0.7, 0.5, 3)

		ServerCall("CTestGun2Fire", self.owner)

		client.DoMachineGunKick(1, self.timeFiring, 2)
		
		self:RecoilAngReset(-15)
		self:RecoilAngPunch(Vec(GetRandomFloat(0.5, 1), GetRandomFloat(-0.5, 0.5), GetRandomFloat(-1, 1)))

		-- shell ejection
		ejectBrass(self.owner, self.casingOrg, Vec(1, -0.2, 0), "MOD/models/xml/shell/casing_9mm.xml", FSFX_BRASS)
	end

	self:muzzleFlash(mt.pos, 2)

	self.ammoLoaded = self.ammoLoaded - 1

	self.nextFire = self:GetNextAttackDelay(0.075)
end

function CTestGun2AltFire(p)
	local mt = GetToolLocationWorldTransform("muzzle", p)
	
	for i=1, 4 do
		local pos, dir = getAimVector(GetPlayerEyeTransform(p).pos, 100, GLOBAL_5DEGREES, p)
		server.ShootHook(pos, dir, "bullet", CTestGun2.dmg_world, CTestGun2.dmg_plyr, 100, p, CTestGun2.toolID, CTestGun2.toolName)
	end
	
	StopSound(CTestGun2.snds[1])
	PlaySound(CTestGun2.snds[1], mt.pos, 300)

	baseWeap.DepleteAmmo(CTestGun2, 4)
end

function CTestGun2:SecondaryAttack(dt)
	if self.ammoLoaded <= 3 then
		self:PlayEmptySound()
		self.nextFire = GetTime() + 0.15
		self.nextAltFire = self.nextFire
		return
	end

	local mt = GetToolLocationWorldTransform("muzzle", self.owner)

	self:RecoilPosPunch(Vec(0, GetRandomFloat(0.05, 0.15), GetRandomFloat(0.1, 0.2)))

	if IsPlayerLocal(self.owner) then
		mt.pos = VecAdd(mt.pos, VecScale(GetPlayerVelocity(), dt))
		
		PointLight(mt.pos, 1, 0.7, 0.5, 4)

		ServerCall("CTestGun2AltFire", self.owner)

		self:RecoilAngPunch(Vec(GetRandomFloat(2, 4), GetRandomFloat(-0.5, 0.5), GetRandomFloat(0.25, 1)))

		-- shell ejection
		ejectBrass(self.owner, self.casingOrg, Vec(1, -0.2, 0), "MOD/models/xml/shell/casing_9mm.xml", FSFX_BRASS)
	end

	self:muzzleFlash(mt.pos, 2)

	self.ammoLoaded = self.ammoLoaded - 4

	self.nextFire = self:GetNextAttackDelay(0.5)
	self.nextAltFire = self.nextFire
end

function CTestGun2:Reload()
	self:DefaultReload(self.ammoLoadedMax50, 1.5)
end

function CTestGun2:WeaponIdle()
	self.playEmptySound = true
end