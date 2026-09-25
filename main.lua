--[[------------------------------------------------------------------------------------------
-- INFO
----------------------------------------------------------------------------------------------

this file calls all weapon functions.

weapon systems are built to function like the weapon systems from Half-Life: 1 / Counter Strike
and can fully support weapons from both with (near) minimal adaptation.

----------------------------------------------------------------------------------------------
-- USAGE
----------------------------------------------------------------------------------------------

Tools in PWB2 use LUA's "class" system in order to abstract away the complicated portions.
to make a mod using this base, you can either copy an existing weapon or start from scratch.

to make a simple new weapon, define the class (MUST BE PREFIXED WITH 'C_'), static variables, SFX and then override
common functions if/when needed (PrimaryAttack(), SecondaryAttack(), Reload(), initVars() etc).
To hook the weapon into main, just include it's file, main.lua finds the weapon's class by itself.

Tool HUD order in relation to other tools in this weapon pack is set using the classes
toolPos value or the load order if toolPos is not found.
There's also a few hacks that can be done to get a tool in a specific spot in relation to
all loaded tools using the registry.

if you need help with PWB2 or it's utilization of object oriented programming, message
'Packman.09' on Discord, create a discussion post about it or check the LUA documentation for object oriented programming below

   https://www.lua.org/pil/16.html

-- NEW TOOL ANIMATOR FEATURES: --
- PWB2 tickToolAnimator():
  tickToolAnimator(toolAnimator, dt, defaultPoseTransform, playerId, swingamnts, swingamntsALT, noheldaction)

- swingamnts + fp_actionX name/tag: (only for first person) you can now define a infinite amount of actions that will be randomly chosen.
  it randomly chooses a number 1 through the number inputted into swingamnts for x. Best for melee weapons (just uses 'fp_action' if undefined)
  if it is a negative number, it will force that variation.

- noheldaction: only does fp/tp_action when forced using the forceActionPose bool
  (using this with a weapon that has multiple actions using the above system may lead to undefined behavior)

- fp/tp_secaction and swingamntsALT: a secondary action position, can only activated with the forceSecondaryActionPose bool

-- NEW KEYFRAME ANIMATION SYSTEM (KF_ prefix): --
  Weapons can now optionally have keyframed animations. FORMAT: Anim({shape, pos, rot, [function]}, tbl, 0, tbl, 0, tbl [end])
  Keyframes are defined with 0s as separators. Do multiple tables before a 0 to have multiple shapes moving per keyframe. 
  Do "hand_[r/l]" instead of a shape index to offset the player's third person hands (useful for reloading). [function]() is called once the keyframe is reached.
  The keyframe system works using an indexed table of animations, containing pointers to animation tables.
  an example on how to use the new keyframed animations is in wpns/adsgun.lua and wpns/anims/adsgun.lua.

-- COMPATIBILITY: --
PWB2 has a few ways of communicating with other mods, this section contains all events and exposed information.

Bullet firing event arguments: ("pwb_shot", fire pos, hit location, hit shape, hit player, dmg_world, dmg_plyr)
Player settings can be found at "savegame.mod.pwb.[HERE]" in the registry.

==============================================================================================
==============================================================================================
-- TO-DO
==============================================================================================
   -  alt fire can use another tools ammo (to add ammo pickups)

   -  Source viewpunch and FOV lerping is 'laggy' sometimes (investigate)
============================================================================================]]

#version 2

-- EXTERNAL CREDITS:
-- - VALVe + TWHL (Half-Life: Updated SDK)
-- - Novena (radial spread code)

----------------------------------------------------------------------------------------------
-- WEAPON INCLUDES AND GLOBALS
----------------------------------------------------------------------------------------------

-- GLOBAL VARS
PWB_SETTING = {}

client.PWB_ANIMATOR = {}

client.MAX_TEMPENTS = 128

-- LIBRARYS
#include "script/lib/pwbtoolanimation.lua"
#include "script/lib/custommath.lua"
#include "script/lib/vfx.lua"
#include "script/lib/temp_ent.lua"
#include "script/include/player.lua"
#include "script/lib/util.lua"

-- WEAPON VARS
GLOBAL_1DEGREE    = 0.00873
GLOBAL_2DEGREES   = 0.01745
GLOBAL_3DEGREES   = 0.02618
GLOBAL_4DEGREES   = 0.03490
GLOBAL_5DEGREES   = 0.04362
GLOBAL_6DEGREES   = 0.05234
GLOBAL_7DEGREES   = 0.06105
GLOBAL_8DEGREES   = 0.06976
GLOBAL_9DEGREES   = 0.07846
GLOBAL_10DEGREES  = 0.08716
GLOBAL_15DEGREES  = 0.13053
GLOBAL_20DEGREES  = 0.17365

GLOBAL_HEADSHOTMULT = 2.0

-- MAIN
#include "script/classes/baseWeap.lua"
#include "script/classes/kfAnimations.lua"

-- WEAPONS
#include "script/wpns/testgun.lua"
#include "script/wpns/adsgun.lua"
#include "script/wpns/patterngun.lua"
#include "script/wpns/testshotgun.lua"

#include "script/wpns/meleetool.lua"

-- ANIMATIONS
#include "script/wpns/anims/adsgun.lua"

-- UI
#include "script/lib/menu.lua"

----------------------------------------------------------------------------------------------
-- MAIN GLOBALS
----------------------------------------------------------------------------------------------

-- pointers to each weapon class
local GLOBAL_WEAPONS = loadWeaponClasses()

-- only calculate this once
local GLOBAL_WEAPONS_AMNT = #GLOBAL_WEAPONS

-- pointers to each player's weapons
PLAYER_WEAPONS = {}

--============================================================================================
--============================================================================================
-- MAIN CODE (DO NOT TOUCH UNLESS YOU KNOW WHAT YOU'RE DOING)
--============================================================================================
--============================================================================================

-- Reset player data on death
local function CheckDeathReset()
	local count = GetEventCount("playerdied")
   	for i=1, count do
		local p, _, _ = GetEvent("playerdied", i)

		local wpns = PLAYER_WEAPONS[p]
		for j=1, GLOBAL_WEAPONS_AMNT do
			wpns[j]:initVars(p)
		end
   end
end

-- Sets up weapon classes, pickup amounts, precaches SFX
function server.init()
   for weapon=1, GLOBAL_WEAPONS_AMNT do
      baseWeap.init_sv(GLOBAL_WEAPONS[weapon], weapon)
   end
end

-- Doesn't need used
function server.tick(dt)
   for p in PlayersRemoved() do
      RemovePlayer(p)
   end

   for _, wpns in pairs(PLAYER_WEAPONS) do
      for i=1, GLOBAL_WEAPONS_AMNT do
         wpns[i]:Tick(dt)
      end
   end
end

-- Runs firing code
function server.update(dt)
   AIM_RecoilTick(dt)

   for p in PlayersAdded() do
		AIM_RecoilSet(p, Vec())

      PLAYER_WEAPONS[p] = {}
      for weapon=1, GLOBAL_WEAPONS_AMNT do
         local wpnPlyr = baseWeap:new(GLOBAL_WEAPONS[weapon], p)
		   PLAYER_WEAPONS[p][weapon] = wpnPlyr
         wpnPlyr:init_player()
      end
	end

   CheckDeathReset()

   for p, wpns in pairs(PLAYER_WEAPONS) do
      local tool = GetPlayerTool(p)

      for i=1, GLOBAL_WEAPONS_AMNT do
         local wpnPlyr = wpns[i]

         if tool == wpnPlyr.toolID then
            wpnPlyr:tickPlayer_sv(dt)
         elseif wpnPlyr.holstered == false then
            wpnPlyr:BaseHolster()
         end

         wpnPlyr:Update(dt)
      end
   end
end

-- Sets up weapon classes, precaches SFX and haptics
function client.init()
   client.settingsInit()

   for weapon=1, GLOBAL_WEAPONS_AMNT do
      baseWeap.init_cl(GLOBAL_WEAPONS[weapon], weapon)
   end
end

-- Runs majority of weapon code
function client.tick(dt)
   for p, wpns in pairs(PLAYER_WEAPONS) do
      local tool = GetPlayerTool(p)
      for i=1, GLOBAL_WEAPONS_AMNT do
         local wpnPlyr = wpns[i]
         if tool == wpnPlyr.toolID then
            wpnPlyr:tickPlayer_cl(dt)
         elseif wpnPlyr.holstered == false then
            wpnPlyr:BaseHolster()
         end

         wpnPlyr:Tick(dt)
      end
   end

   client.PUNCH_Apply(dt)

   client.settingsTick()
end

-- Global VFX
function client.update(dt)
   AIM_RecoilTick(dt)

   for p in PlayersAdded() do
      AIM_RecoilSet(p, Vec())
      client.PWB_ANIMATOR[p] = ToolAnimator()
      PLAYER_WEAPONS[p] = {}

      for weapon=1, GLOBAL_WEAPONS_AMNT do
         local wpnPlyr = baseWeap:new(GLOBAL_WEAPONS[weapon], p)
		   PLAYER_WEAPONS[p][weapon] = wpnPlyr
         wpnPlyr:init_player()
      end
	end

   for p in PlayersRemoved() do
      RemovePlayer(p)
   end

   CheckDeathReset()

   for _, wpns in pairs(PLAYER_WEAPONS) do
      for i=1, GLOBAL_WEAPONS_AMNT do
         wpns[i]:Update(dt)
      end
   end

   local tool = GetPlayerTool()
   local wpns = PLAYER_WEAPONS[GetLocalPlayer()]
   for i=1, GLOBAL_WEAPONS_AMNT do
      if tool == wpns[i].toolID then
         wpns[i]:KF_Advance(dt)
         break
      end
   end

   client.FOV_Apply(dt)
   client.PUNCHBASIC_Apply(dt)

   client.VFX_DynLightDraw(dt)

   client.TENT_Update(dt, 10 --[[Gravity]])
end

local function DontDraw()
   return client.settingsDraw() or not PLAYER_WEAPONS or GetPlayerHealth() <= 0 or GetPlayerVehicle() ~= 0
end

function client.draw()
   if DontDraw() then return end

   local tool = GetPlayerTool()
   local wpns = PLAYER_WEAPONS[GetLocalPlayer()]

   for i=1, GLOBAL_WEAPONS_AMNT do
      if tool == wpns[i].toolID then
         wpns[i]:DrawHUD()
         break
      end
   end
end