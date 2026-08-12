local childWeap = {}
g_childWeap = childWeap

-- Per weapon constants
-- TO-DO: remove
local RELOAD_TIME = 1.5 -- seconds
local RECOIL_AMNT = 0.1
local FIRERATE = 0.075
local ALTFIRERATE = 1
local DAMAGE = 0.4
local PLAYERDAMAGE = 0.05
local MAX_RANGE = 100.0
local CASING_ORG = Vec(0.02, 0.15, -0.15)

--=========================================================================
-- Define the weapon and it's variables
--=========================================================================

-- Values for this specific weapon
childWeap.model				= "MOD/models/xml/smg1.xml" -- path to the XML model file
childWeap.toolID 			= "childweap"				-- used by the engine. lowercase and no spaces
childWeap.toolName 			= "PWB2 Weapon"				-- shown in killfeed
childWeap.toolSlot			= 3
childWeap.ammoLoadedMax 	= 45						-- max clip 	 	-- -1 for no clip (pulls from reserve)
childWeap.ammoAltLoadedMax	= -1 						-- max alt clip 	-- -1 for no clip (pulls from reserve) 0 for no alt fire
childWeap.ammoPickupSize	= childWeap.ammoLoadedMax	-- defaults to full mag
childWeap.flags				= 0							-- weapon flags

function childWeap:init_sv()
	-- must be called like this due to how static vars work
	baseWeap.init_tool(self)
end

function childWeap:init_cl()
	baseWeap.init_cl(self) -- does nothing currently
	
	self.timeFiring = 0
end

function childWeap:WeaponSounds()
	return {
		{"MOD/snd/smg1_fire.ogg", "sv", 10}
	}
end

--=========================================================================
-- Weapon functions
--=========================================================================

function server.PrimaryAttack(p)
	local mt = GetToolLocationWorldTransform("muzzle", p)

	local pos, dir = getAimVector(GetPlayerEyeTransform(p).pos, MAX_RANGE, GLOBAL_5DEGREES, p)
	
	server.ShootHook(pos, dir, "bullet", DAMAGE, PLAYERDAMAGE, MAX_RANGE, p, childWeap.toolID, childWeap.toolName)
	
	StopSound(childWeap.snds[1])
	PlaySound(childWeap.snds[1], mt.pos, 300)

	server.depleteAmmo(p, childWeap.toolID)
end

function childWeap:PrimaryAttack()
	if self.ammoLoaded <= 0 then
		self:PlayEmptySound()
		self.nextFire = GetTime() + 0.15
		return
	end

	local mt = GetToolLocationWorldTransform("muzzle", p)

	if true or IsPlayerLocal(self.owner) then
		PointLight(mt.pos, 1, 0.7, 0.5, 3)

		ServerCall("server.PrimaryAttack", self.owner)

		client.DoMachineGunKick(1, self.timeFiring, 2)

		-- shell ejection
		ejectBrass(p, CASING_ORG, Vec(1, -0.2, 0), "MOD/models/xml/shell/casing_9mm.xml", FSFX_BRASS)
	end

	if GetTime() - self.lastFireTime < 0.1 then
		self.timeFiring = self.timeFiring + 0.1
	else
		self.timeFiring = 0
	end

	muzzleFlash(mt.pos, 2)

	self.ammoLoaded = self.ammoLoaded - 1

	self.nextFire = self:GetNextAttackDelay(0.075)
end

function childWeap:Reload()
	self:DefaultReload(self.ammoLoadedMax50, 1.5)
end

function childWeap:WeaponIdle()
	self.playEmptySound = true
end