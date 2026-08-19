--============================================================================================
-- 	 weapon function defaults. Override functions here in child classes to make new guns!
-- 							  (see main.lua for more info)
--
--	do NOT modify these functions directly in this file unless you know what you're doing!
--============================================================================================

baseWeap = {}

-- Static values for this specific weapon. These are shared for all instances of the class
-- These don't need redefined in a weapon if a var is just the default value
baseWeap.model				= "MOD/models/xml/mdl.xml"	-- path to the XML model file
baseWeap.casingOrg			= Vec(0,0,0)				-- where casings are ejected

baseWeap.toolID 			= "basetool"				-- used by the engine. lowercase and no spaces
baseWeap.toolName 			= "PWB2 Base Tool"			-- shown in killfeed
baseWeap.toolSlot			= 0

baseWeap.ammoLoadedMax 		= 0							-- max clip 	 	-- -1 for no clip (pulls from reserve)
baseWeap.ammoAltLoadedMax	= 0 						-- max alt clip 	-- -1 for no clip (pulls from reserve) 0 for no alt fire
baseWeap.ammoPickupSize		= baseWeap.ammoLoadedMax	-- defaults to full mag
baseWeap.dmg_world			= 0							-- world damage, 'gun' does around 0.5
baseWeap.dmg_plyr			= 0							-- 0.0-1.0

baseWeap.flags				= 0	-- weapon flags
baseWeap.snds				= 0 -- temp value, will be set to the sound array on init

baseWeap.recoilPosDecay 	= 0.5 -- multiplier for recoil pos decay. Lower is slower, higher is faster
baseWeap.recoilAngSpring	= 65  -- bigger number increases the speed at which the angle corrects
baseWeap.recoilAngDamp		= 9	  -- bigger number makes the response more damped, smaller is less damped
								  -- currently the system will overshoot, with larger damping values it won't

local WEAPON_NOCLIP = -1

-----------------------------------------------------------								
-- Values that ALL weapons share/use
-- override initVars() to add variables
-- add 'baseWeap.initVars(self, owner)'
-- at the beginning if overriding vars
-- at the end otherwise if preferred
-----------------------------------------------------------
function baseWeap:initVars(owner, wpnSlot)
	if client then
		-- can be used for shotgun pumpping, bolt cycling
		-- or any post firing stuff really
		self.pumpTime           = 0

		-- used for shotgun reload interrupting
		self.specialReload      = 0

		-- True when gun's reserve is empty
		-- Use to check if gun should fire
		-- Use alongside ammoLoaded.
		self.firedOnEmpty       = false
		
		-- current magazine amount
		self.ammoLoaded         = self.ammoLoadedMax 

		-- total alt ammo
		self.ammoAltTotal      	= 0 

		self.inReload           = false

		-- True when the gun is allowed to
		-- play empty sounds. Reset it in Idle()
		self.playEmptySound		= true
		
		self.animator        	= ToolAnimator()

		self.recoilPos 			= Vec(0,0,0)

		-- Better than calling IsPlayerLocal()
		-- every time needed
		self.isLocal 			= false

		if IsPlayerLocal(owner) then
			self.isLocal 		= true

			self.recoilAng 		= Vec(0,0,0)
			self.recoilAngVel 	= Vec(0,0,0)

			self.idleCycleTime  = 0
			self.idleCycleScale = 1
		end
	end

	-- total ammo
	self.ammoTotal			= 0 

	if server or (client and self.isLocal == true) then
		-- used for server networking
		self.inPrimary 		= false
		self.inSecondary 	= false
	end

	-- compare against GetTime()
	self.nextFire           = 0
	self.nextAltFire        = 0

	-- time creep vars
	self.prevPrimFireTime   = -1
	self.lastFireTime       = 0

	-- time used for running code in Idle()
	self.timeWeaponIdle		= 0

	-- true when the weapon isn't equipped
	self.holstered			= true

	-- which player owns this instance
	self.owner				= owner

	-- list of currently playing following sounds
	self.followingSNDS 		= {}
end

--=========================================================================
-- Init funcs
--=========================================================================

function baseWeap:init_sv(wpnSlot)
	-- must be called like this
	baseWeap.init_tool(self)
	baseWeap.PrecacheSFX(self)
	self.weaponSlot	= wpnSlot
end

function baseWeap:init_cl(wpnSlot)
	-- must be called like this
	baseWeap.PrecacheSFX(self)
	self.weaponSlot	= wpnSlot
end

function baseWeap:init_tool()
	RegisterTool(self.toolID, self.toolName, self.model, self.toolSlot)
	SetToolAmmoPickupAmount(self.toolID, self.ammoPickupSize)
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

--=========================================================================
-- Weapon SFX / VFX
--=========================================================================
function baseWeap:muzzleFlash(pos, size, color)
	color = color or Vec(1, 1, 1)

	if self.isLocal then
		pos = VecAdd(pos, VecScale(GetPlayerVelocity(), GetTimeStep()))
	end

	local t = Transform(pos)
	t.rot = QuatRotateQuat(GetCameraTransform().rot, QuatEuler(0,0,GetRandomFloat(-15, 15)))

	-- Create the flashSPR variable to hold the sprite
	if not baseWeap.flashSPR then baseWeap.flashSPR = LoadSprite("gfx/glare.png") end

	local spriteSize = size * 0.4
	DrawSprite(baseWeap.flashSPR, t, spriteSize, spriteSize, color[1], color[2], color[3], 1.0, true, true, true)
end

-- sound data for PrecacheSFX(), override per weapon
-- loop is optional and doesn't need included.
function baseWeap:WeaponSounds()
	return {
--  		   SOUND		  load to	 dist	[loop]
		{"MOD/snd/SOUND.ogg", "sv|cl", 	  10,	false}
	} 
end

function baseWeap:PlayEmptySound()
	if self.playEmptySound then
		if not baseWeap.emptySND then baseWeap.emptySND = LoadSound("MOD/snd/empty.ogg") end
		PlaySound(baseWeap.emptySND, GetPlayerTransform(self.owner).pos, 0.5)
		self.playEmptySound = false
	end
end

-- Uses sound loops to have a sound that follows the player
-- length should be the duration of the sound
-- (feel free to clip off some decimals so it won't overshoot)
function baseWeap:PlayFollowingSound(loop, length)
	self.followingSNDS[#self.followingSNDS + 1] = {loop, (GetTime() + length)}
end

function baseWeap:PrecacheSFX()
	local precachedSounds = {}
	local svSounds, clSounds = 0, 0

	for i, sounddata in ipairs(self:WeaponSounds()) do
		if server and sounddata[2] == "sv" then
            svSounds = svSounds + 1
			if sounddata[4] and sounddata[4] == true then
                precachedSounds[svSounds] = LoadLoop(sounddata[1], sounddata[3])
            else
                precachedSounds[svSounds] = LoadSound(sounddata[1], sounddata[3])
            end
		elseif client and sounddata[2] == "cl" then
            clSounds = clSounds + 1
            if sounddata[4] and sounddata[4] == true then
                precachedSounds[clSounds] = LoadLoop(sounddata[1], sounddata[3])
            else
                precachedSounds[clSounds] = LoadSound(sounddata[1], sounddata[3])
            end
		end
	end

	self.snds = precachedSounds
end

--=========================================================================
-- Weapon interactions
-- These should be overriden per weapon
--=========================================================================
function baseWeap:Deploy()   		 		  	end -- called when weapon is equipped
function baseWeap:Holster()			  		   	end -- called when weapon is unequipped

function baseWeap:PrimaryAttack(dt)   		   	end
function baseWeap:SecondaryAttack(dt) 		   	end
function baseWeap:Reload()            		   	end -- called when reload is started
function baseWeap:WeaponIdle()		  		   	end -- called when no buttons are pressed

function baseWeap:CustomAnimate(dt)	  		   	end -- called every frame, use for adding custom
										 	       	-- weapon movement, see PWB1  slide/pump anims

-- Override these if the weapon has extra conditions needed for firing
-- I.E. Weapon uses multiple rounds in the mag per fire
-- These are ran on client only but if they're true, server isn't called												
function baseWeap:SV_FireEmptyCond() 	return false end
function baseWeap:SV_FireAltEmptyCond() return false end
--=========================================================================
-- 	Input handling and HUD
--=========================================================================
function baseWeap:tickPlayer_cl(dt)
	self:DumpGlobals()
	
	self:Animate(dt)

	tickToolAnimator(self.animator, dt, nil, self.owner)

	local curTime = GetTime()

	if self.isLocal then
		for index, sound in pairs(self.followingSNDS) do
			if (sound[2] - curTime) > dt then
				PlayLoop(sound[1], GetPlayerPos(), 1.0)
			else
				SetSoundLoopProgress(sound[1])
				self.followingSNDS[index] = nil
			end
		end
	end

	local fireKeyDown, altfireKeyDown = false, false
	if hasFlag(self.flags, FWPN_CLICK_PRIM) then
		fireKeyDown = InputPressed("usetool", self.owner)
	else
		fireKeyDown = InputDown("usetool", self.owner)
	end

	if hasFlag(self.flags, FWPN_CLICK_SEC) then
		altfireKeyDown = InputPressed("grab", self.owner)
	else
		altfireKeyDown = InputDown("grab", self.owner)
	end

	if not self.holstered then
		if GetPlayerGrabBody(self.owner) ~= 0 or GetPlayerVehicle(self.owner) ~= 0 then
			-- player is grabbing object
			self:DefaultHolster()
			fireKeyDown, altfireKeyDown = false, false
		end
	elseif GetPlayerGrabBody(self.owner) == 0 and GetPlayerVehicle(self.owner) == 0 then
		-- deploying weapon
		self:DefaultDeploy(curTime)
	end

	self.ammoTotal = GetToolAmmo(self.toolID, self.owner)

	if self.inReload and self.nextFire <= curTime then
		-- complete the reload.
		self.ammoLoaded = math.min(self.ammoLoadedMax, self.ammoTotal)

		self.inReload = false
    end

	local empty_prim = ((self.ammoLoaded == 0 and self.ammoTotal == 0) or (self.ammoLoadedMax == WEAPON_NOCLIP and 0 == self.ammoTotal)) or self:SV_FireEmptyCond()
	if not fireKeyDown or altfireKeyDown or empty_prim or self.ammoLoaded == 0 then
		self.lastFireTime = 0.0

		if self.isLocal and self.inPrimary == true then
			self.inPrimary = false

			-- update server ASAP! Otherwise will cause desync if you press both at the same time
			if (not hasFlag(self.flags, FWPN_SV_CALLONCE) and not hasFlag(self.flags, FWPN_CLICK_PRIM)) or hasFlag(self.flags, FWPN_SV_CALLONCESEC) then
				self:ServerWpnCall("SV_StopFire")
			end
		end
	end

	-- TO-DO: this probably breaks if FWPN_SV_CALLONCE is true and you press both at once
	local empty_sec = false or self:SV_FireAltEmptyCond() --(self.ammoAltLoadedMax ~= WEAPON_NOCLIP and self.ammoAltTotal == 0) or (self.ammoAltLoadedMax == WEAPON_NOCLIP and empty_prim)
	if self.isLocal and self.inSecondary == true then
		-- enforce order
		self.inPrimary = false

		self.lastFireTime = 0.0

		if not altfireKeyDown or empty_sec then
			self.inSecondary = false
			if not hasFlag(self.flags, FWPN_SV_CALLONCESEC) and not hasFlag(self.flags, FWPN_CLICK_SEC) then
				self:ServerWpnCall("SV_StopAltFire")
			end
		end
	end
	
	if altfireKeyDown and self:CanAttack(self.nextAltFire, curTime) then
		self:DefaultSecondaryAttack(dt, empty_sec)
	elseif fireKeyDown and self:CanAttack(self.nextFire, curTime) then
		self:DefaultPrimaryAttack(dt, empty_prim)
	elseif InputDown("r", self.owner) and self.ammoLoadedMax ~= WEAPON_NOCLIP and not self.inReload and self:CanAttack(math.max(self.nextFire, self.nextAltFire), curTime) then
		-- reload when reload is pressed, or if no buttons are down and weapon is empty.
		self:Reload()
		if self.isLocal then self.inPrimary, self.inSecondary = false, false end
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

-- Server only cares about firing
-- Don't simulate reloading or clip amount
function baseWeap:tickPlayer_sv(dt)
	self:DumpGlobals()

	local curTime = GetTime()

	for index, sound in pairs(self.followingSNDS) do
		if (sound[2] - curTime) > dt then
			PlayLoop(sound[1], GetPlayerPos(self.owner), 1.0)
		else
			SetSoundLoopProgress(sound[1])
			self.followingSNDS[index] = nil
		end
	end

	if not self.holstered then
		if GetPlayerGrabBody(self.owner) ~= 0 or GetPlayerVehicle(self.owner) ~= 0 then
			-- player is grabbing object
			self:DefaultHolster()
		end
	elseif GetPlayerGrabBody(self.owner) == 0 and GetPlayerVehicle(self.owner) == 0 then
		-- deploying weapon
		self:DefaultDeploy(curTime)
	end

	self.ammoTotal = GetToolAmmo(self.toolID, self.owner)

	-- enforce order
	if self.inSecondary then
		self.inPrimary = false
		self.lastFireTime = 0.0
	elseif not self.inPrimary then
		self.lastFireTime = 0.0
    end

	if self.inSecondary == true and self:CanAttack(self.nextAltFire, curTime) then
		self:SecondaryAttack(dt, false)
	elseif self.inPrimary == true and self:CanAttack(self.nextFire, curTime) then
		self:PrimaryAttack(dt, false)
	end

	-- used for when you need extra stuff in WeaponIdle
	if self:ShouldWeaponIdle() then
		self:WeaponIdle()
	end
end

function baseWeap:DefaultPrimaryAttack(dt, empty)
	if empty then
		self.firedOnEmpty = true
	elseif self.isLocal then
		if self.inPrimary == false and (self.ammoLoaded > 0 or (self.ammoLoadedMax == WEAPON_NOCLIP and self.ammoTotal > 0)) then
			self.inPrimary = true
			if not hasFlag(self.flags, FWPN_SV_CALLONCE) and not hasFlag(self.flags, FWPN_CLICK_PRIM) then
				self:ServerWpnCall("SV_StartFire")
			end
		end
	end

	self:PrimaryAttack(dt)
end

function baseWeap:DefaultSecondaryAttack(dt, empty)
	if empty then
		self.firedOnEmpty = true
	elseif self.isLocal then
		if self.inSecondary == false then
			self.inSecondary = true
			if not hasFlag(self.flags, FWPN_SV_CALLONCESEC) and not hasFlag(self.flags, FWPN_CLICK_SEC) then
				self:ServerWpnCall("SV_StartAltFire")
			end
		end
	end

	-- hold gun straight
	self.animator.timeSinceFire = 0.0

	self:SecondaryAttack(dt)
end

function baseWeap:DefaultDeploy(curTime)
	-- no rapid firing
	self.nextFire 	  = math.max(self.nextFire, curTime + 0.25)
	self.nextAltFire  = math.max(self.nextAltFire, self.nextFire)
	self.lastFireTime = 0.0

	self.holstered 	  = false

	if client then
		-- cancel reloads
		self.inReload = false

		-- Reset old recoil and do some movement
		self.recoilPos = Vec(0,0,0)
		if self.isLocal then
			self:RecoilAngReset()
			self:RecoilAngPunch(Vec(3, 0.75, 0.66))
			
			self:RecoilPosPunch(Vec(0.05, 0.1, -0.05))
		end
	end

	self:Deploy()
end

function baseWeap:DefaultHolster()
	if client then
		self.inReload = false
	end

	if server or self.isLocal then
		for index, sound in pairs(self.followingSNDS) do
			SetSoundLoopProgress(sound[1])
		end

		self.followingSNDS = {}
		
		self.inPrimary 	  = false
		self.inSecondary  = false
	end

	self.lastFireTime = 0.0

	self.holstered = true
	self:Holster()
end

function baseWeap:DrawHUD()
	if hasFlag(self.flags, FWPN_NOHUD) then return end

	if self.ammoLoadedMax ~= WEAPON_NOCLIP then -- has clips
		UiPush()
			UiFont("bold.ttf", 32)
			UiAlign("center middle")
			UiTranslate(UiCenter(), UiMiddle() + (UiMiddle() * 0.833))
			if self.inReload == true then
				UiText("RELOADING | " .. string.format("%.2f", self.nextFire - GetTime()))
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
-- 	WEAPON MODEL RECOIL
-- 	Don't modify these, just edit the per class constants
--=========================================================================
function baseWeap:Animate(dt)
	if self.isLocal then
		local idlePos = Vec(
			math.sin(self.idleCycleTime*0.5) + math.cos(self.idleCycleTime*0.25),
			-math.sin(self.idleCycleTime*0.5) + math.cos(self.idleCycleTime*0.25),
			0
		)

		self.idleCycleTime = self.idleCycleTime + dt

		if self.timeWeaponIdle > GetTime() then
			self.idleCycleScale = math.lerp(self.idleCycleScale, 0.0, dt)
		else
			self.idleCycleScale = math.lerp(self.idleCycleScale, 1.0, dt)
		end

		idlePos = VecScale(VecSub(VecScale(idlePos, 0.01), Vec(0.01, 0.01, 0)), self.idleCycleScale)

		self.animator.offsetTransform = Transform(
			VecAdd(self.recoilPos, idlePos),
			QuatEuler(self.recoilAng[1], self.recoilAng[2], self.recoilAng[3])
		)

		self:decayAngRecoil(dt)
	else
		self.animator.offsetTransform.pos = self.recoilPos
	end

	self:decayPosRecoil(dt)

	self:CustomAnimate(dt)
end

function baseWeap:RecoilPosPunch(punchPos)
	self.recoilPos = VecAdd(self.recoilPos, punchPos)
end

function baseWeap:RecoilAngPunch(punchAngles, mult)
	mult = mult and mult or 20
	self.recoilAngVel = VecAdd(self.recoilAngVel, VecScale(punchAngles, mult))
end

function baseWeap:decayPosRecoil(dt)
	local len = VecLength(self.recoilPos)
	if len == 0 then return end
	len = len - ((2 + len * self.recoilPosDecay) * dt)
	len = math.max(len, 0)
	self.recoilPos = VecScale(VecNormalize(self.recoilPos), len)
end

function baseWeap:decayAngRecoil(dt)
	if VecLength(self.recoilAng) > 0.03 or VecLength(self.recoilAngVel) > 0.03 then
		self.recoilAng = VecAdd(self.recoilAng, VecScale(self.recoilAngVel, dt))
		local damping = 1 - (self.recoilAngDamp * dt)
		
		if damping < 0 then 
			damping = 0
		end

		self.recoilAngVel = VecScale(self.recoilAngVel, damping)
		
		-- torsional spring
		-- UNDONE: Per-axis spring constant?
		local springForceMagnitude = self.recoilAngSpring * dt
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
	if tolerance then
		local check = VecLength(self.recoilAngVel) + VecLength(self.recoilAng)

		if tolerance > 0 and check > tolerance then
			return
		elseif tolerance < 0 and check < (tolerance*-1) then
			return
		end
	end

	self.recoilAng 	 = Vec(0,0,0)
	self.recoilAngVel = Vec(0,0,0)
end

--=========================================================================
--	NETWORKING
--	Used to servercall to a player's weapon
--=========================================================================

function baseWeap:SV_StartFire() self.inPrimary = true end
function baseWeap:SV_StopFire() self.inPrimary = false end
function baseWeap:SV_StartAltFire() self.inSecondary = true end
function baseWeap:SV_StopAltFire() self.inSecondary = false end

function server.ReceiveSVcall(func, owner, slot, ...)
	local wpn = PLAYER_WEAPONS[owner][slot]
	wpn[func](wpn, ...)
end

function baseWeap:ServerWpnCall(func, ...)
	ServerCall("server.ReceiveSVcall", func, self.owner, self.weaponSlot, ...)
end

--=========================================================================
--	UTIL FUNCS
--=========================================================================

function baseWeap:ShouldWeaponIdle()
	return false -- override me!
end

function baseWeap:CanAttack(attack_time, curtime)
	return (attack_time <= curtime) and GetPlayerCanUseTool(self.owner) == true
end

-- GetNextAttackDelay - Accurate way of getting the next primary fire time.
function baseWeap:GetNextAttackDelay(delay)
    local curTime = GetTime()

	if self.lastFireTime == 0.0 or self.prevPrimFireTime == -1 then
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

-- IsUseable - this function determines whether or not a
-- weapon is useable by the player in its current state.
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

function baseWeap:DefaultReload(fDelay)
	if self.ammoTotal <= 0 then return false end

	local j = math.min(self.ammoLoadedMax - self.ammoLoaded, self.ammoTotal)
	if j <= 0 then return false end

	local curTime = GetTime()

	self.nextFire = curTime + fDelay
	self.nextAltFire = self.nextFire

	self.inReload = true

	self.timeWeaponIdle = curTime + 3

	return true
end

function baseWeap:DepleteAmmo(amount)
	amount = amount or 1
	local ammo = GetToolAmmo(self.toolID, self.owner)

	if ammo < 9999 then
		SetToolAmmo(self.toolID, ammo-amount, self.owner)
	end
end

--=========================================================================
--	DEBUG FUNCS
--=========================================================================

function baseWeap:DumpGlobals()
	local prefix = "SV "
	if client then prefix = "CL "
		
		DebugWatch(prefix .. "inReload", 			self.inReload)

		
		DebugWatch(prefix .. "ammoLoaded", 			self.ammoLoaded)
		DebugWatch(prefix .. "ammoAltTotal",		self.ammoAltTotal)
	end

	--DebugWatch(prefix .. "ammoTotal", 		self.ammoTotal)

	if server or self.isLocal then
		DebugWatch(prefix .. "inPrimary", 			self.inPrimary)
		DebugWatch(prefix .. "inSecondary", 		self.inSecondary)
	end

	DebugWatch(prefix .. "nextFire",			string.format("%.5f", math.max(0, self.nextFire - GetTime())))
	DebugWatch(prefix .. "nextAltFire", 		string.format("%.5f", math.max(0, self.nextAltFire - GetTime())))

	DebugWatch(prefix .. "prevPrimFireTime", 	self.prevPrimFireTime)
	DebugWatch(prefix .. "lastFireTime", 		self.lastFireTime)

	-- unused
	--DebugWatch(prefix .. "timeWeaponIdle", 	self.timeWeaponIdle)

	DebugWatch(prefix .. "holstered", 			self.holstered)
end