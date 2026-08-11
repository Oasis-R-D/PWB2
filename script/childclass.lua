childWeap = {}

-- Per weapon constants
-- TO-DO: remove
local RELOAD_TIME = 1.5 -- seconds
local RELOAD_SOUND = "MOD/snd/smg1_reload.ogg"
local ALT_FIRESOUND = "MOD/snd/smg1_altfire.ogg"
local PRIM_FIRESOUND = "MOD/snd/smg1_fire.ogg"
local CLIP_SIZE = 45
local PICKUP_SIZE = 45
local RECOIL_AMNT = 0.1
local FIRERATE = 0.075
local ALTFIRERATE = 1
local DAMAGE = 0.4
local PLAYERDAMAGE = 0.05
local MAX_RANGE = 100.0
local WPNID = "hl2smg1"
local WPNNAME = "Combine SMG"
local CASING_ORG = Vec(0.02, 0.15, -0.15)

--=========================================================================
-- Define the weapon and it's variables
--=========================================================================

-- Values for this specific weapon
function childWeap:toolInfo()
	self.model				= "MOD/models/xml/smg1.xml"
	self.toolID 			= "childweap"
	self.toolName 			= "PWB2 Weapon"
	self.ammoLoadedMax 		= 50 -- max clip 	-- -1 for no clip (pulls from reserve)
	self.ammoAltLoadedMax	= -1 -- max alt clip -- -1 for no clip (pulls from reserve) 0 for no alt fire
	self.flags				= 0
end

function childWeap:initVars(owner)
    baseWeap:initVars(owner)
end

function childWeap:init_sv()
	childWeap = baseWeap:new(childWeap, GetLocalPlayer())
	RegisterTool(self.toolID, self.toolName, self.model, 3)
	SetToolAmmoPickupAmount(self.toolID, PICKUP_SIZE)
end

function childWeap:init_cl()
	childWeap = baseWeap:new(childWeap, GetLocalPlayer())
end

--=========================================================================
-- Weapon functions
--=========================================================================

function server.primaryFireSMG1(p)
	local mt = GetToolLocationWorldTransform("muzzle", p)

	local pos, dir = getAimVector(GetPlayerEyeTransform(p).pos, MAX_RANGE, GLOBAL_5DEGREES, p)
	
	server.ShootHook(pos, dir, "bullet", DAMAGE, PLAYERDAMAGE, MAX_RANGE, p, childWeap.toolID, childWeap.toolName)

	--PlaySound(LoadSound(PRIM_FIRESOUND), mt.pos, 300)

	server.depleteAmmo(p, childWeap.toolID)
end

function childWeap:PrimaryAttack()
	local mt = GetToolLocationWorldTransform("muzzle", p)
	if mt == nil then
		return
	end

	PointLight(mt.pos, 1, 0.7, 0.5, 3)

	if IsPlayerLocal(self.owner) then
		ServerCall("server.primaryFireSMG1", self.owner)

		client.DoMachineGunKick(1, data.timeFiring, 2)

		--PlayHaptic(shootHaptic, 1)

		-- shell ejection
		--ejectBrass(p, CASING_ORG, Vec(1, -0.2, 0), "MOD/prefab/casing_9mm.xml", FSFX_BRASS)
	end
	
	muzzleFlash(mt.pos, 2)

	data.ammoLoaded = data.ammoLoaded - 1
end
