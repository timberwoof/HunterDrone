# HunterDrone
Second Life object that flies around the sim and harasses people

Inmate Hunter Drone
Software and SL object by Timberwoof Lupindo
Based on a concept my Otakuwolf Otafuku

Otaku's original concept had the drone flying around to spyar goo at escaped inmates. 
This system increases its abilities to use antigravity to carry 
escaped inmates and fugitives to specific locations. 

The drone patrols the streets of the Black Gazza sim by following a grid ofcoordinates. 
At each corner it stops to make a scan. Then it randomly picks a direciton to go in. 
It will not go back the way it came. At grid edges it will make the right choice. 
There are two grids: 

There is a rectangular grid of coordinates defined by X and Y locations. 
The locations correspond with streets and alleys in the Black Gazza sim. 
"Indexes" are vectors of 0-based integers that correspond with these locations. 
The z component of the vectors is always the cruising altiude. 

Communication with RLV relays complicates the control flow. The flight functions are blocking calls, so messages pile up. The normal Patrol flight has these steps: 

In the Timer, with command set to "PATROL":
pickAnAdjacentIndex
rotateAzimuthToIndex
flyToIndex
llSensor

The control thread is picked up in sensor: 
isAvatarInIgnoreArea - if it is, ignore that avatar
llMessageLinked SCAN_START - to start the scanner beam particles
isAvatarInGroup guardGroupKey - 
  greet the guard
else - 
  listen for RLV messages
  add the avatar to the ping list
  message the avatar to ask for rlv status
llMessageLinked SCAN_STOP - to stop the scanner beam particles

For avatars with RLV relay, the control thread is picked up in listen: 
parse the response message
get the avatar UUID
if UUID is in the ping list (it may ot be; there's other traffic on that channel) -
  remove it from ping list
  add it to the list for with or without rlv

For all avatars the thread is picked up in timer with the command HANDLE
if there's anybody left in the ping list -
  remove them from that list
  add them to the no-rlv list
respondToAvatar all the no-rlv people, clear the no-rlv list
respondToAvatar all the rlv people, clear the rlv list

respondToAvatar does… 
if the avatar is in an ignore area, ignroe them
if the avatar is in the inmate group
  if avatar has rlv, carry them to the rocket pod
  else yell at them
if the avatar is in the welcome group (fugutive)
  if avatar has rlv, carry them to the cell
  else yell at them
if the avatar is in some other group
  yell at them
  if avatar has RLV, goo them

fly back to previous position
return to patrol

