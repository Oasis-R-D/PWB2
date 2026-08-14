--============================================================================================
-- 	 weapon function defaults. Override functions here in child classes to make new guns!
-- 							  (see main.lua for more info)
--
--	do NOT modify these functions directly in this file unless you know what you're doing!
--============================================================================================

baseWeap = {}

-- Static values for this specific weapon
baseWeap.model				= "MOD/models/xml/model.xml"-- path to the XML model file
baseWeap.casingOrg			= Vec()

baseWeap.toolID 			= "baseweap"				-- used by the engine. lowercase and no spaces
baseWeap.toolName 			= "PWB2 Base Weapon"		-- shown in killfeed
baseWeap.toolSlot			= 0

baseWeap.ammoLoadedMax 		= 0							-- max clip 	 	-- -1 for no clip (pulls from reserve)
baseWeap.ammoAltLoadedMax	= 0 						-- max alt clip 	-- -1 for no clip (pulls from reserve) 0 for no alt fire
baseWeap.ammoPickupSize		= baseWeap.ammoLoadedMax	-- defaults to full mag
baseWeap.dmg_world			= 0
baseWeap.dmg_plyr			= 0							-- 0.0-1.0

baseWeap.flags				= 0							-- weapon flags
baseWeap.snds				= 0

function baseWeap:init_sv()
	-- must be called like this
	baseWeap.init_tool(self)
	baseWeap.init_sfx(self)
end

function baseWeap:init_cl()
	-- must be called like this
	baseWeap.init_sfx(self)
end

function baseWeap:init_tool()
	RegisterTool(self.toolID, self.toolName, self.model, self.toolSlot)
	SetToolAmmoPickupAmount(self.toolID, self.ammoPickupSize)
end

function baseWeap:init_sfx()
	self.snds = PrecacheSFXArray(self:WeaponSounds())
end

-- sound data for PrecacheSFXArray, override per weapon
function baseWeap:WeaponSounds()
	return {
--  		   [SOUND]		 [load to]	[dist]
		{"MOD/snd/SOUND.ogg", "sv/cl", 	  10}
	} 
end

-- Values that ALL weapons share/use
-- override initVars to add new variables
-- add 'baseWeap.initVars(self, owner)'
-- at the beginning to override vars
-- or end to add more vars
function baseWeap:initVars(owner)
	-- CLIENT VARS
	if client then
		-- true when the weapon isn't equipped
		self.holstered			= true

		-- compare against GetTime()
		self.nextFire           = 0
		self.nextAltFire        = 0

		-- can be used for shotgun pumpping, bolt cycling
		-- or any post firing stuff really
		self.pumptime           = 0

		self.inReload           = false

		-- used for shotgun reload interrupting
		self.specialReload      = 0

		-- time until resetting idle anim (there aren't idle anims)
		self.timeWeaponIdle		= 0

		-- True when gun is empty
		-- Use to check if it
		-- should fire in the
		-- firing functions.
		self.firedOnEmpty       = false
		self.playEmptySound		= true

		-- time creep vars
		self.prevPrimFireTime   = 0
		self.lastFireTime       = 0

		-- ammo loaded into weapon. Set by child
		self.ammoTotal			= 0 -- total ammo
		self.ammoLoaded         = self.ammoLoadedMax -- current magazine amount
		
		
		self.ammoAltTotal      	= 0 -- total alt ammo
		
		self.animator        	= ToolAnimator()

		self.recoilPos 			= Vec(0,0,0)
		self.recoilAng 			= Vec(0,0,0)
		self.recoilAngVel 		= Vec(0,0,0)
	end

	-- which player owns this instance
	self.owner					= owner
end

-- to add a new weapon just do CHILD = baseWeap:new(CHILD, owner) where CHILD is {}
-- to add a weapon to a player do PLCHILD = baseWeap.new(CHILD, PLCHILD, owner)
function baseWeap:new(obj, owner)
    owner = owner or -1

    -- make new table
    local instance = {}
    if obj then
        for k, v in pairs(obj) do
            instance[k] = v
        end
    end

    setmetatable(instance, self)
    self.__index = self

    instance:initVars(owner)
    return instance
end

WEAPON_NOCLIP = -1

-- These are overriden per weapon
function baseWeap:Deploy()   		  end -- called when weapon is equipped
function baseWeap:PrimaryAttack(dt)   end
function baseWeap:SecondaryAttack(dt) end
function baseWeap:Reload()            end -- called when reload is started
function baseWeap:WeaponIdle()		  end -- called when no buttons are pressed

function baseWeap:CustomAnimate(dt)	  end -- called every frame, use for adding custom
										  -- weapon movement, see PWB1  slide/pump anims
		
--=========================================================================
-- tickPlayer - Handles player inputs
--=========================================================================
function baseWeap:tickPlayer(dt)
	self:Animate(dt)

	tickToolAnimator(self.animator, dt, nil, self.owner)

	local curTime = GetTime()
	
	-- declare var for this since it's used a lot 
    local fireKeyDown 	 = InputDown("usetool", self.owner)
	local altfireKeyDown = InputDown("grab", self.owner)

	

	self.ammoTotal = GetToolAmmo(self.toolID, self.owner)

	if GetPlayerGrabBody(self.owner) ~= 0 then
		self.inReload  = false
		self.holstered = true
		fireKeyDown, altfireKeyDown = false, false
	elseif self.holstered == true then
		-- no rapid firing
		self.nextFire 	  = math.max(self.nextFire, curTime + 0.25)
		self.nextAltFire  = math.max(self.nextAltFire, self.nextFire)
		self.lastFireTime = 0

		-- cancel reloads
		self.inReload	  = false

		self.holstered 	  = false

		self:Deploy()
	end

	if self.inReload and self.nextFire <= curTime then
		-- complete the reload.
		self.ammoLoaded = math.min(self.ammoLoadedMax, self.ammoTotal)

		self.inReload = false
    end

	if not fireKeyDown then
		self.lastFireTime = 0.0
    end

	if altfireKeyDown and self:CanAttack(self.nextAltFire, curTime) then
		if self.ammoAltLoadedMax ~= WEAPON_NOCLIP and self.ammoAltTotal == 0 then
			self.firedOnEmpty = true
        end

		-- hold gun straight
		self.animator.timeSinceFire = 0.0

		self:SecondaryAttack(dt)
	elseif fireKeyDown and self:CanAttack(self.nextFire, curTime) then
		if (self.ammoLoaded == 0 and self.ammoTotal == 0) or (self.ammoLoadedMax == WEAPON_NOCLIP and 0 == self.ammoTotal) then
			self.firedOnEmpty = true
        end

		self:PrimaryAttack(dt)
	elseif InputPressed("r", self.owner) and self.ammoLoadedMax ~= WEAPON_NOCLIP and not self.inReload then
		-- reload when reload is pressed, or if no buttons are down and weapon is empty.
		self:Reload()
	elseif not fireKeyDown and not altfireKeyDown then
		-- no fire buttons down
		self.firedOnEmpty = false

		if self.nextFire <= curTime and self.ammoLoaded == 0 and self:IsUseable() then
			if not hasFlag(self.flags, FWPN_NOAUTORELOAD) then 
				self:Reload()
				return
			end
		end

		self:WeaponIdle()
		return
	end

	-- used for when you need extra stuff in WeaponIdle
	if self:ShouldWeaponIdle() then
		self:WeaponIdle()
	end
end

function baseWeap:DrawHUD()
	if self.ammoLoadedMax ~= WEAPON_NOCLIP then -- has clips
		UiPush()
			UiFont("bold.ttf", 32)
			UiAlign("center middle")
			UiTranslate(UiCenter(), UiMiddle() + (UiMiddle() * 0.833))
			if self.inReload == true then
				UiText("RELOADING | " .. math.modf((self.nextFire - GetTime()) * 10) / 10)
			else
				UiText(self.ammoLoaded .. " | " .. self.ammoLoadedMax)
			end
		UiPop()
	end

	if self.ammoAltLoadedMax ~= 0 and self.inReload == false then -- has altfire
		UiPush()
			UiFont("bold.ttf", 32)
			UiAlign("center middle")
			UiTranslate(UiCenter(), UiMiddle() + (UiMiddle() * 0.766))
			if self.ammoAltLoadedMax ~= WEAPON_NOCLIP then
				UiText(self.ammoAltTotal .. " | " .. self.ammoAltLoadedMax)
			else
				UiText(self.ammoAltTotal)
			end
		UiPop()
	end
end

--=========================================================================
-- 								ANIMATION
--=========================================================================

function baseWeap:Animate(dt)
	-- ang recoil could prob be made local for performance

	self.animator.offsetTransform = Transform(self.recoilPos, QuatEuler(self.recoilAng[1], self.recoilAng[2], self.recoilAng[3]))
	self:decayPosRecoil(dt)
	self:decayAngRecoil(dt)

	self:CustomAnimate(dt)
end

function baseWeap:RecoilAngPunch(punchAngles, mult)
	mult = mult and mult or 20
	self.recoilAngVel = VecAdd(self.recoilAngVel, VecScale(punchAngles, mult))
end

function baseWeap:decayPosRecoil(dt)
	local len = VecLength(self.recoilPos)
	len = len - ((10.0 + len * 0.25) * dt)
	len = math.max(len, 0.0)
	self.recoilPos = VecScale(VecNormalize(self.recoilPos), len)
end

function baseWeap:decayAngRecoil(dt)
	if VecLength(self.recoilAng) > 0.03 or VecLength(self.recoilAngVel) > 0.03 then
		self.recoilAng = VecAdd(self.recoilAng, VecScale(self.recoilAngVel, dt))
		local damping = 1 - (9 * dt)
		
		if damping < 0 then 
			damping = 0
		end

		self.recoilAngVel = VecScale(self.recoilAngVel, damping)
		
		-- torsional spring
		-- UNDONE: Per-axis spring constant?
		local springForceMagnitude = 65 * dt
		springForceMagnitude = math.clamp( springForceMagnitude, 0.0, 2.0 )
		self.recoilAngVel = VecSub(self.recoilAngVel, VecScale(self.recoilAng, springForceMagnitude))

		-- don't wrap around
		self.recoilAng[1] = math.clamp(self.recoilAng[1], -89,  89 )
		self.recoilAng[2] = math.clamp(self.recoilAng[2], -179, 179)
		self.recoilAng[3] = math.clamp(self.recoilAng[3], -89,  89 )
	else
		self.recoilAng 	  = Vec(0,0,0)
		self.recoilAngVel = Vec(0,0,0)
	end
end

function baseWeap:RecoilAngReset(tolerance)
	tolerance = tolerance or 0
	if tolerance ~= 0 then
		tolerance = tolerance

		local check = VecLength(self.recoilAngVel) + VecLength(self.recoilAng)

		if check > tolerance then
			return
		end
	end

	self.recoilAng 	 = Vec(0,0,0)
	self.recoilAngVel = Vec(0,0,0)
end

--=========================================================================
-- 								UTIL FUNCS
--=========================================================================

-- TO-DO: add firer's velocity?
function baseWeap:muzzleFlash(pos, size, color)
	color = color or Vec(1, 1, 1)
	local t = Transform(pos)
	t.rot = QuatRotateQuat(GetCameraTransform().rot, QuatEuler(0,0,GetRandomFloat(-15, 15)))

	-- Create the flashSPR variable to hold the sprite
	if not baseWeap.flashSPR then baseWeap.flashSPR = LoadSprite("gfx/glare.png") end

	local spriteSize = size * 0.4
	DrawSprite(baseWeap.flashSPR, t, spriteSize, spriteSize, color[1], color[2], color[3], 1.0, true, true, true)
end

function baseWeap:PlayEmptySound()
	if self.playEmptySound then
		PlaySound(LoadSound("MOD/snd/empty.ogg"), GetPlayerTransform(self.owner).pos, 0.5)
		self.playEmptySound = false
	end
end

function baseWeap:ShouldWeaponIdle()
	return false -- override me!
end

function baseWeap:CanAttack(attack_time, curtime)
	return (attack_time <= curtime) and GetPlayerCanUseTool(self.owner) == true
end

-- GetNextAttackDelay - Accurate way of getting the next primary fire time.
function baseWeap:GetNextAttackDelay(delay)
    local curTime = GetTime()

	if self.lastFireTime == 0 or self.prevPrimFireTime == -1 then
		-- At this point, we are assuming that the client has stopped firing
		-- and we are going to reset our book keeping variables.
		self.lastFireTime = curTime
		self.prevPrimFireTime = delay
    end

	-- calculate the time between this shot and the previous
	local flTimeBetweenFires = curTime - self.lastFireTime
	local flCreep = 0.0
	if flTimeBetweenFires > 0 then
		flCreep = flTimeBetweenFires - self.prevPrimFireTime -- postive or negative
    end

	-- save the last fire time
	self.lastFireTime = curTime

	local flNextAttack = curTime + delay - flCreep
	-- we need to remember what the self.prevPrimFireTime time is set to for each shot,
	-- store it as self.prevPrimFireTime.
	self.prevPrimFireTime = flNextAttack - curTime
	return flNextAttack
end

--=========================================================
-- IsUseable - this function determines whether or not a
-- weapon is useable by the player in its current state.
-- (does it have ammo loaded? do I have any ammo for the
-- weapon?, etc)
--=========================================================
function baseWeap:IsUseable()
	if self.ammoLoaded > 0 then
		return true
	end

	--Player has unlimited ammo for this weapon or does not use magazines
	if self.ammoLoadedMax == WEAPON_NOCLIP then
		return true
	end

	if self.ammoTotal > 0 then
		return true
	end

	if self.ammoAltLoadedMax ~= 0 then
		--Player has unlimited ammo for this weapon or does not use magazines
		if self.ammoAltLoadedMax == WEAPON_NOCLIP then
			return true
		end

		if self.ammoAltTotal > 0 then
			return true
		end
	end

	-- clip is empty (or nonexistant) and the player has no more ammo of this type.
	return false --CanDeploy()
end

function baseWeap:DefaultReload(iClipSize, fDelay)
	if self.ammoTotal <= 0 then return false end

	local j = math.min(self.ammoLoadedMax - self.ammoLoaded, self.ammoTotal)
	if j <= 0 then return false end

	local curTime = GetTime()

	--[[m_pPlayer->m_flNextAttack]] self.nextFire = curTime + fDelay
	self.nextAltFire = self.nextFire

	--!!UNDONE -- reload sound goes here !!!

	self.inReload = true

	self.timeWeaponIdle = curTime + 3

	return true
end

function baseWeap:DepleteAmmo(amount)
	amount = amount or 1
	local ammo = GetToolAmmo(self.toolID, self.owner)
	DebugPrint(self.toolID)
	if ammo < 9999 then
		SetToolAmmo(self.toolID, ammo-amount, self.owner)
	end
end

function PrecacheSFXArray(arr)
	local precachedSounds = {}
	for i, sounddata in ipairs(arr) do
		if server and sounddata[2] == "sv" then
			table.insert(precachedSounds, LoadSound(sounddata[1], sounddata[3]))
		elseif client and sounddata[2] == "cl" then
			table.insert(precachedSounds, LoadSound(sounddata[1], sounddata[3]))
		end
	end

	--self.WeaponSounds = nil -- don't need this anymore

	return precachedSounds
end