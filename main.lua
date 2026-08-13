--[[------------------------------------------------------------------------------------------
-- INFO
----------------------------------------------------------------------------------------------

this file calls all weapon functions. To add your weapon just add a pointer to it's class
in GLOBAL_WEAPONS (make sure to '#include' it's lua file).

weapon systems are built to function like the weapon systems from
Half-Life: 1 / Counter Strike and can fully support weapons from both with minimal adaptation.

Weapon HUD order is set by the order they are listed in the GLOBAL_WEAPONS table

----------------------------------------------------------------------------------------------
-- USAGE
----------------------------------------------------------------------------------------------

weapons in PWB2 use LUA's "class" system in order to abstract away the complicated portions.
to make a mod using this base, you can either copy an existing weapon or start from scratch.

to make a simple new weapon, define the class, static variables, SFX and then override
common functions if/when needed (PrimaryAttack(), SecondaryAttack(), Reload(), initVars() etc)

if you need help with PWB2 or it's utilization of object oriented programming, message
'Packman.09' on Discord or check the LUA documentation for object oriented programming below

   https://www.lua.org/pil/16.html 

==============================================================================================
-- WEAPON DEFINITION EXAMPLE
==============================================================================================

-- local for the table, global for the reference
local demoWeap = {}   -- demoWeap is turned into a class on init
g_demoWeap = demoWeap -- g_demoWeap goes in GLOBAL_WEAPONS

--=========================================================================
-- Define the weapon's SFX
--=========================================================================

function demoWeap:WeaponSounds()
	return {
		{"MOD/snd/sfx.ogg", "sv", 10}
	}
end

--=========================================================================
-- Define the weapon and it's variables
--=========================================================================

-- Values for this specific weapon
demoWeap.model				   = "MOD/models/xml/smg1.xml"-- path to the XML model file
demoWeap.toolID 			   = "demoWeap"				   -- used by the engine. lowercase and no spaces
demoWeap.toolName 			= "PWB2 Weapon"			   -- shown in killfeed
demoWeap.toolSlot			   = 3
demoWeap.ammoLoadedMax 	   = 45						      -- max clip 	 	-- -1 for no clip (pulls from reserve)
demoWeap.ammoAltLoadedMax	= -1 						      -- max alt clip 	-- -1 for no clip (pulls from reserve) 0 for no alt fire
demoWeap.ammoPickupSize	   = demoWeap.ammoLoadedMax	-- defaults to full mag
demoWeap.flags				   = 0							   -- weapon flags
demoWeap.snds				   = 0							   -- temp value, will be set to the sound array on init

-- override initVars to add new variables
function demoWeap:initVars(owner)
	if client then
		self.timeFiring = 0
	end

	baseWeap.initVars(self, owner)
end

==============================================================================================
-- TO-DO
==============================================================================================
   -  Loop based sound system, will make it so sounds follow the player proper
      (only on firing client?)
============================================================================================]]

#version 2

-- EXTERNAL CREDITS:
-- - VALVe + TWHL (Half-Life: Updated SDK)
-- - Novena (radial spread code)

----------------------------------------------------------------------------------------------
-- WEAPON INCLUDES AND GLOBALS
----------------------------------------------------------------------------------------------

-- LIBRARYS
#include "script/lib/bit_ops.lua"
#include "script/lib/pwbtoolanimation.lua"

GLOBAL_HEADSHOTMULT = 3.0 -- use actual value since guns do less damage in HL2DM

GLOBAL_MAX_TEMPENTS = 1200

GLOBAL_1DEGREE = 0.00873
GLOBAL_2DEGREES = 0.01745
GLOBAL_3DEGREES = 0.02618
GLOBAL_4DEGREES = 0.03490
GLOBAL_5DEGREES = 0.04362
GLOBAL_6DEGREES = 0.05234
GLOBAL_7DEGREES = 0.06105
GLOBAL_8DEGREES = 0.06976
GLOBAL_9DEGREES = 0.07846
GLOBAL_10DEGREES = 0.08716
GLOBAL_15DEGREES = 0.13053
GLOBAL_20DEGREES = 0.17365

-- GLOBALS
#include "script/baseclass.lua"
#include "script/include/player.lua"
#include "script/temp_ent.lua"
#include "script/util.lua"

-- WEAPONS
#include "script/childclass.lua"
#include "script/testgun.lua"

-- MELEE

-- SPECIAL

-- ITEMS

----------------------------------------------------------------------------------------------
-- MAIN GLOBALS
----------------------------------------------------------------------------------------------

-- pointers to each weapon's class
GLOBAL_WEAPONS = {
   g_childWeapon,
   g_testWeapon,
}

GLOBAL_WEAPONS_AMNT = #GLOBAL_WEAPONS -- only calculate this once

-- pointers to each player's weapons
PLAYER_WEAPONS = {}

--============================================================================================
--============================================================================================
-- MAIN CODE (DO NOT TOUCH UNLESS YOU KNOW WHAT YOU'RE DOING)
--============================================================================================
--============================================================================================

-- Declares weapons, pickup amounts
-- Server doesn't have an option to be turned off since all weapons need it. Could automate that in the future though!
function server.init()
   for weapon=1, GLOBAL_WEAPONS_AMNT do
      baseWeap.init_sv(GLOBAL_WEAPONS[weapon])
   end
end

function server.tick(dt)
   for p in PlayersAdded() do
      PLAYER_WEAPONS[p] = {}
      local pushback = table.insert
      for weapon=1, GLOBAL_WEAPONS_AMNT do
         local wpnPlyr = baseWeap:new(GLOBAL_WEAPONS[weapon], p)
		   pushback(PLAYER_WEAPONS[p], wpnPlyr)
         SetToolEnabled(wpnPlyr.toolID, true, p)
		   SetToolAmmo(wpnPlyr.toolID, 9999, p)
      end
	end

   for p in PlayersRemoved() do
      PLAYER_WEAPONS[p] = nil
   end
end

function server.update(dt)
   checkDeathReset()
end

-- Load haptics, amongst other things
function client.init()
   for weapon=1, GLOBAL_WEAPONS_AMNT do
      baseWeap.init_cl(GLOBAL_WEAPONS[weapon])
   end
end

-- Runs most weapon code
function client.tick(dt)
   for p in PlayersAdded() do
      PLAYER_WEAPONS[p] = {}
      local pushback = table.insert
      for weapon=1, GLOBAL_WEAPONS_AMNT do
         local wpnPlyr = baseWeap:new(GLOBAL_WEAPONS[weapon], p)
		   pushback(PLAYER_WEAPONS[p], wpnPlyr)
      end
	end

   for p in PlayersRemoved() do
      PLAYER_WEAPONS[p] = nil
   end

   for p, wpns in pairs(PLAYER_WEAPONS) do
      local tool = GetPlayerTool(p)
      for i=1, GLOBAL_WEAPONS_AMNT do
         if tool == wpns[i].toolID then
            wpns[i]:tickPlayer(dt)
         else
            wpns[i].holstered = true
         end
      end
   end

   client.SRC_ApplyPlayerPunch(dt)
end

-- Global VFX
function client.update(dt)
   checkDeathReset()

   client.GS_ApplyPlayerPunch(dt)

   HUD_TempEntUpdate_(
   dt,	-- Simulation time
	GetTime(), -- Absolute time on client
	10)	-- True gravity on client
end

-- Draws the magazine hud and scopes
function client.draw()
   if not PLAYER_WEAPONS then return end

   if GetPlayerHealth() <= 0 or GetPlayerVehicle() ~= 0 then return end

   local tool = GetPlayerTool()
   local wpns = PLAYER_WEAPONS[GetLocalPlayer()]
   for i=1, GLOBAL_WEAPONS_AMNT do
      if tool == wpns[i].toolID then
         wpns[i]:DrawHUD()
         break
      end
   end
end