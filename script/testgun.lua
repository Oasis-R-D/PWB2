-- local for the table, global for the reference
local childWeap = {}
g_testWeapon = childWeap

-- Per weapon constants
local DAMAGE = 0.4
local PLAYERDAMAGE = 0.05
local MAX_RANGE = 100.0
local CASING_ORG = Vec(0.02, 0.15, -0.15)

--=========================================================================
-- Define the weapon's SFX
--=========================================================================

function childWeap:WeaponSounds()
	return {
		{"MOD/snd/smg1_fire.ogg", "sv", 10}
	}
end

--=========================================================================
-- Define the weapon and it's variables
--=========================================================================

-- Values for this specific weapon
childWeap.model				= "MOD/models/xml/smg1.xml" -- path to the XML model file
childWeap.toolID 			= "testgun"					-- used by the engine. lowercase and no spaces
childWeap.toolName 			= "PWB2 Test Gun"			-- shown in killfeed
childWeap.toolSlot			= 3
childWeap.ammoLoadedMax 	= 30						-- max clip 	 	-- -1 for no clip (pulls from reserve)
childWeap.ammoAltLoadedMax	= 0 						-- max alt clip 	-- -1 for no clip (pulls from reserve) 0 for no alt fire
childWeap.ammoPickupSize	= childWeap.ammoLoadedMax	-- defaults to full mag
childWeap.flags				= 0							-- weapon flags
childWeap.snds				= 0							-- temp value, will be set to the sound array on init

-- override initVars to add new variables
function childWeap:initVars(owner)
	if client then
		self.timeFiring = 0
	end

	baseWeap.initVars(self, owner)
end

--=========================================================================
-- Weapon functions
--=========================================================================

function server.PrimaryAttack(p)
	local pos, dir = getAimVector(GetPlayerEyeTransform(p).pos, MAX_RANGE, GLOBAL_5DEGREES, p)
	
	server.ShootHook(pos, dir, "bullet", DAMAGE, PLAYERDAMAGE, MAX_RANGE, p, childWeap.toolID, childWeap.toolName)

	StopSound(childWeap.snds[1])
	PlaySound(childWeap.snds[1], GetToolLocationWorldTransform("muzzle", p).pos, 300)

	server.depleteAmmo(p, childWeap.toolID)
end

function childWeap:PrimaryAttack(dt)
	if self.ammoLoaded <= 0 then
		self:PlayEmptySound()
		self.nextFire = GetTime() + 0.15
		return
	end

	local mt = GetToolLocationWorldTransform("muzzle", self.owner)

	if IsPlayerLocal(self.owner) then
		mt.pos = VecAdd(mt.pos, VecScale(GetPlayerVelocity(), dt))

		PointLight(mt.pos, 1, 0.7, 0.5, 3)

		ServerCall("server.PrimaryAttack", self.owner)

		client.DoMachineGunKick(1.66, self.timeFiring, 1)

		-- shell ejection
		ejectBrass(self.owner, CASING_ORG, Vec(1, -0.2, 0), "MOD/models/xml/shell/casing_556.xml", FSFX_BRASS)
	end

	if GetTime() - self.lastFireTime < 0.125 then
		self.timeFiring = self.timeFiring + 0.125
	else
		self.timeFiring = 0
	end

	muzzleFlash(mt.pos, 3)

	self.ammoLoaded = self.ammoLoaded - 1

	self.nextFire = self:GetNextAttackDelay(0.1)
end

function childWeap:Reload()
	self:DefaultReload(self.ammoLoadedMax50, 1.5)
end

function childWeap:WeaponIdle()
	self.playEmptySound = true
end