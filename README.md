# PWB2
A brand new weapons base, loosely based on my previous base PWB.

### INFO
PWB weapon base is built to function like the weapon systems from
Half-Life: 1 / Counter Strike and can fully support weapons from both with minimal adaptation.

### USAGE
weapons in PWB2 use LUA's "class" system in order to abstract away the complicated portions.
to make a mod using this base, you can either copy an existing weapon or start from scratch.

to make a simple new weapon, define the class, static variables, SFX and then override
common functions if/when needed (PrimaryAttack(), SecondaryAttack(), Reload(), initVars() etc)

if you need help with PWB2 or it's utilization of object oriented programming, message
'Packman.09' on Discord or check the LUA documentation for object oriented programming below

   https://www.lua.org/pil/16.html
