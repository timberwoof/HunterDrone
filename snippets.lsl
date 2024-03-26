// This contains functions that were useful at one time but were removed because they are unused. 
// No, Stephen, I cannot kill these darlings. 

vector positionToNearestIndex(vector target) {
    // From an XYZ location, search for the nearest standard coordinate. 
    integer x;
    integer y;
    float nearestDistance = 500;
    vector nearestPoint = <0, 0, 0>;
    vector nearestIndexVector;
    for (x = 0; x <= xMax; x = x + 1) {
        for (y = 0; y <= yMax; y = y + 1) {
            vector thepoint = indexToPosition(<x, y, 0>);
            float distance = llVecDist(thepoint, target);
            if (distance < nearestDistance) {
                nearestDistance = distance;
                nearestPoint = thepoint;
                nearestIndexVector = <x, y, 0>;
            }            
        }
    }
    //sayDebug("positionToNearestIndex(" + (string)target + ") found " + (string)nearestIndexVector + " " + (string)nearestPoint);
    return nearestIndexVector;
}

warpToPosition(vector destpos) 
 {   
    //R&D by Keknehv Psaltery, 05/25/2006
     //with a little poking by Strife, and a bit more
     //some more munging by Talarus Luan
     //Final cleanup by Keknehv Psaltery
     //Changed jump value to 411 (4096 ceiling) by Jesse Barnett
     // Compute the number of jumps necessary
     integer jumps = (integer)(llVecDist(destpos, llGetPos()) / 10.0) + 1;
     // Try and avoid stack/heap collisions
     if (jumps > 411)
         jumps = 411;
     list rules = [ PRIM_POSITION, destpos ];  //The start for the rules list
     integer count = 1;  
     while ( ( count = count << 1 ) < jumps)
         rules = (rules=[]) + rules + rules;   //should tighten memory use.
     llSetPrimitiveParams( rules + llList2List( rules, (count - jumps) << 1, count) );
     if ( llVecDist( llGetPos(), destpos ) > .001 ) //Failsafe 
         while ( --jumps ) 
             llSetPos( destpos );
}

// teleport
vector teleportInmate = <116, 128, 1222>;
vector teleportFugitive = <128, 102, 1372>;
vector teleportTimber = <181, 37, 24>;

teleportAvatarToCoordinates(key target, vector destLocalCoordinates) {
    // transport the target via RLV
    llMessageLinked(LINK_SET, 0, "BEAM_START", target);
    llSleep(2);
    string destination = "Black Gazza" + 
        "/"+(string)((integer)destLocalCoordinates.x)+
        "/"+(string)((integer)destLocalCoordinates.y)+
        "/"+(string)((integer)destLocalCoordinates.z); 
    llSay(rlvChannel, "teleport,"+(string)target+",@tpto:"+destination+"=force");
    llSleep(1);
    llMessageLinked(LINK_SET, 0, "BEAM_STOP", target);
}

