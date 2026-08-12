#version 2

-- EXTERNAL CREDITS:
-- - VALVe (Half-Life: 2)
-- - Novena (radial spread code)
-- - Verbatim Man (AR2 ball and crossbow bolt use code loosely based on his pellet launcher's code)

----------------------------------------------------------------------------------------------

-- LIBRARYS
#include "script/lib/bit_ops.lua"
#include "script/lib/pwbtoolanimation.lua"

----------------------------------------------------------------------------------------------
-- WEAPON GLOBALS
----------------------------------------------------------------------------------------------

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

----------------------------------------------------------------------------------------------

-- GLOBALS
#include "script/baseclass.lua"
#include "script/include/player.lua"
#include "script/temp_ent.lua"
#include "script/util.lua"

-- WEAPONS
#include "script/childclass.lua"

-- MELEE

-- SPECIAL

-- ITEMS

----------------------------------------------------------------------------------------------
-- MAIN GLOBALS
----------------------------------------------------------------------------------------------

-- pointers to each weapon's class
------------------------------------------------------------------
-- add players via 'PLCHILD = baseWeap.new(CHILD, PLCHILD, owner)' 
-- and then add PLCHILD's functions to the tick arrays
------------------------------------------------------------------
GLOBAL_WEAPONS = {
   g_childWeap,
}

-- pointers to every player's weapons
PLAYER_WEAPONS = {}

GLOBAL_WEAPONS_AMNT = #GLOBAL_WEAPONS -- only calculate this once

for weapon=1, GLOBAL_WEAPONS_AMNT do
   if server then
      --server.weaponTicks = {}
      --table.insert( server.weaponTicks, GLOBAL_WEAPONS[i]:)
   else
      client.weaponTicks = {}
      table.insert( client.weaponTicks, GLOBAL_WEAPONS[i]:tickPlayer() )

      client.weaponDraws = {}
      table.insert( client.weaponDraws, GLOBAL_WEAPONS[i]:DrawHUD() )
   end
end

----------------------------------------------------------------------------------------------

-- this file calls all weapon functions. To add your weapon just add it's functions here (make sure to #include it's lua file).

-- to make a mod using this base, choose a weapon to base your weapon off of, then copy it's xml, vox and lua file (or you can make new ones completely)
-- in the .LUA file, replace all instances of the weapons name (suffix on the functions, some variables) and then add it's suffix here in the weapons list above
-- To remove unused/unwanted weapons, remove it's lua file, xml file(s), vox, sounds and then it's name in the weapons list and also its #include from this file

-- Weapon order in the HUD is set by the order they are written in the weapons list

----------------------------------------------------------------------------------------------

-- TO-DO: 
-- -  figure out classes. Each weapon has it's own class to override certain things in order to do it's unique functions but
--    they all have the same baseclass which contains most of the shared code. Main.lua then calls the objects functions (tick, init etc.)
--    (basically maximizing abstraction)

-- -  Loop based sound system, will make it so sounds follow the player proper (only on firing client?)

-- -  Use death event to reset dead player's data

-- -  Make every player have their own table with all their weapons in it
----------------------------------------------------------------------------------------------

-- Declares weapons, pickup amounts
-- Server doesn't have an option to be turned off since all weapons need it. Could automate that in the future though!
function server.init()
   for weapon=1, GLOBAL_WEAPONS_AMNT do
      GLOBAL_WEAPONS_AMNT[i]:init_sv()
   end
end

function server.tick(dt)
   for p in PlayersAdded() do
      PLAYER_WEAPONS[p] = {}
      local pushback = table.insert
      for weapon=1, GLOBAL_WEAPONS_AMNT do
         local wpnPlyr = baseWeap.new(GLOBAL_WEAPONS_AMNT[weapon], wpnPlyr, p) -- make a new weapon for this player
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
   local count = GetEventCount("playerdied")
   for i=1, count do
      local pos, playerThrew, dir = GetEvent("playerdied", i)
   end
end

-- Load haptics, amongst other things
function client.init()
   for weapon=1, GLOBAL_WEAPONS_AMNT do
      GLOBAL_WEAPONS_AMNT[i]:init_cl()
   end
end

-- Runs most weapon code
function client.tick(dt)
   for p in PlayersAdded() do
      PLAYER_WEAPONS[p] = {}
      local pushback = table.insert
      for weapon=1, GLOBAL_WEAPONS_AMNT do
         local wpnPlyr = baseWeap.new(GLOBAL_WEAPONS_AMNT[weapon], wpnPlyr, p) -- make a new weapon for this player
		   pushback(PLAYER_WEAPONS[p], wpnPlyr)
      end
	end

   for p in PlayersRemoved() do
      PLAYER_WEAPONS[p] = nil
   end

   for p in Players() do
      local tool = GetPlayerTool(p)
      local wpns = PLAYER_WEAPONS[p]
      for i=1, #wpns do
         if tool == wpns[i].toolID then
            wpns[i]:tickPlayer(dt)
            break
         end
      end
   end

   client.SRC_ApplyPlayerPunch(dt)
end

-- Global VFX
function client.update(dt)
   client.GS_ApplyPlayerPunch(dt)

   HUD_TempEntUpdate_(
   dt,	-- Simulation time
	GetTime(), -- Absolute time on client
	10)	-- True gravity on client
end

-- Draws the magazine hud and scopes
function client.draw()
   local tool = GetPlayerTool(GetLocalPlayer())
   local wpns = PLAYER_WEAPONS[GetLocalPlayer()]
   for i=1, #wpns do
      if tool == wpns[i].toolID then
         wpns[i]:DrawHUD()
         break
      end
   end
end