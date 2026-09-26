# PWB2
A brand new weapons base, loosely based on my previous base PWB.

### INFO
PWB weapon base is built to function like the weapon systems from
Half-Life: 1 / Counter Strike and can fully support weapons from both with minimal adaptation.

### USAGE
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

#### NEW TOOL ANIMATOR FEATURES:
- PWB tickToolAnimator():
  tickToolAnimator(toolAnimator, dt, defaultPoseTransform, playerId, swingamnts, swingamntsALT, noheldaction)

- swingamnts + fp_actionX name/tag: (only for first person) you can now define a infinite amount of actions that will be randomly chosen.
  it randomly chooses a number 1 through the number inputted into swingamnts for x. Best for melee weapons (just uses 'fp_action' if undefined)
  if it is a negative number, it will force that variation.

- noheldaction: only does fp/tp_action when forced using the forceActionPose bool
  (using this with a weapon that has multiple actions using the above system may lead to undefined behavior)

- fp/tp_secaction and swingamntsALT: a secondary action position, can only activated with the forceSecondaryActionPose bool

- NEW KEYFRAME ANIMATION SYSTEM (KF_ prefix):
  Weapons can now optionally have keyframed animations. FORMAT: Anim({shape, pos, rot, [function]}, tbl, 0, tbl, 0, tbl [end])
  Keyframes are defined with 0s as separators. Do multiple tables before a 0 to have multiple shapes moving per keyframe. 
  Do "hand_[r/l]" instead of a shape index to offset the player's third person hands (useful for reloading). [function]() is called once the keyframe is reached.
  The keyframe system works using an indexed table of animations, containing pointers to animation tables.
  an example on how to use the new keyframed animations is in wpns/adsgun.lua and wpns/anims/adsgun.lua.
  
### COMPATIBILITY:
PWB2 has a few ways of communicating with other mods, this section contains all events and exposed information.

Weapon firing event arguments: ("pwb_shot", fire pos, hit location, hit shape, hit player, dmg_world, dmg_plyr)
Player settings can be found at "savegame.mod.pwb.[HERE]" in the registry.
