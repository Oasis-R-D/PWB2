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

-- {func suffix, main flags}
GLOBAL_WEAPONS = {
   { "CRBR",    addFlag(0, MF_CL_NODRAW) },
   { "STNSTK",  addFlag(0, MF_CL_NODRAW) },

   { "SMG1",    0  },
   { "AR2",     0  },
   { "PYTH",    0  },
   { "PIST9MM", 0  },
   { "SG",      0  },

   { "CROSS",   addFlag(0, MF_CL_NODRAW) },

   { "FRAG",    addFlag(0, MF_CL_NODRAW) },
   { "SLAM",    addFlag(0, MF_CL_NODRAW) },

   { "MED",     addFlags(0, MF_CL_NODRAW, MF_CL_NOINIT, MF_CL_NOTICK) },
}

GLOBAL_WEAPONS_AMNT = #GLOBAL_WEAPONS -- only calculate this once

----------------------------------------------------------------------------------------------

-- GLOBALS
#include "script/include/player.lua"
#include "script/temp_ent.lua"
#include "script/util.lua"

-- WEAPONS
#include "script/weapon_pistol.lua"

-- MELEE

-- SPECIAL

-- ITEMS

server.weaponTicks = {}
client.weaponTicks = {}
client.weaponDraws = {}
----------------------------------------------------------------------------------------------

-- this file calls all weapon functions. To add your weapon just add it's functions here (make sure to #include it's lua file).

-- to make a mod using this base, choose a weapon to base your weapon off of, then copy it's xml, vox and lua file (or you can make new ones completely)
-- in the .LUA file, replace all instances of the weapons name (suffix on the functions, some variables) and then add it's suffix here in the weapons list above
-- To remove unused/unwanted weapons, remove it's lua file, xml file(s), vox, sounds and then it's name in the weapons list and also its #include from this file

-- Weapon order in the HUD is set by the order they are written in the weapons list

----------------------------------------------------------------------------------------------

-- TO-DO: 
-- - figure out classes. Each weapon is it's own class but has the same baseclass. Main.lua then calls the objects functions (tick, init etc.)
-- - Loop based sound system, will make it so sounds follow the player proper (only on firing client?)

----------------------------------------------------------------------------------------------

-- Declares weapons, pickup amounts
-- Server doesn't have an option to be turned off since all weapons need it. Could automate that in the future though!
function server.init()
   for i = 1, GLOBAL_WEAPONS_AMNT do
      server["init" .. GLOBAL_WEAPONS[i][1]]()
      table.insert(server.weaponTicks, server["tick" .. GLOBAL_WEAPONS[i][1]]) 
   end
end

function server.tick(dt)
   for i = 1, GLOBAL_WEAPONS_AMNT do
      server.weaponTicks[i](dt)
   end
end

-- Load haptics, amongst other things
function client.init()
   for i = 1, GLOBAL_WEAPONS_AMNT do

      -- check init
      if not hasFlag(GLOBAL_WEAPONS[i][2], MF_CL_NOINIT) then
         client["init" .. GLOBAL_WEAPONS[i][1]]()
      end

      -- check tick
      if not hasFlag(GLOBAL_WEAPONS[i][2], MF_CL_NOTICK) then
         table.insert(client.weaponTicks, client["tick" .. GLOBAL_WEAPONS[i][1]])
      end

      -- check HUD draw
      if not hasFlag(GLOBAL_WEAPONS[i][2], MF_CL_NODRAW) then
         table.insert(client.weaponDraws, client["draw" .. GLOBAL_WEAPONS[i][1]])
      end
   end

   GLOBAL_WEAPON_CL_TICKS_AMNT = #client.weaponTicks
   GLOBAL_WEAPON_DRAWS_AMNT = #client.weaponDraws
end

-- Runs most weapon code
function client.tick(dt)
   if not GLOBAL_WEAPON_CL_TICKS_AMNT then return end

   for i = 1, GLOBAL_WEAPON_CL_TICKS_AMNT do
      client.weaponTicks[i](dt)
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
   if not GLOBAL_WEAPON_DRAWS_AMNT then return end
   
	if GetPlayerHealth() <= 0 or GetPlayerVehicle() ~= 0 then return end
   
   for i = 1, GLOBAL_WEAPON_DRAWS_AMNT do
      client.weaponDraws[i]()
   end
end