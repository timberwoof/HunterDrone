// Identification
string myKey="X0000";

// Command and Communications
integer rlvChannel = -1812221819; // RLVRS
integer RLVListen = 0;
integer commandChannel = -4413251;
integer commandListen;
integer menuChannel;
integer menuListen;
string command; // commands, sensor reports
string mission;

// Operating Parameters
float sensorRange = 30; 
float patrolAltitude = 28;
float transportAltitude = 35;

// Patrol
// Debug has restircted range of operation
list normalXPointList = [2, 60, 104, 152, 202, 254];
list normalYPointList = [58, 94.5, 161.5, 210];
list debugXPointList = [104, 152, 202];
list debugYPointList = [58, 94.5];
list XPointList;
list YPointList;
integer xMax;
integer yMax;
vector positionIndex;   // which point we're going to now
vector homeIndex;       // which point home is based off
vector home;            // home coordinates
rotation heading;
vector previousDeltaIndex = <0,0,0>; 

// Transport
list toAirport = [<181, 28, 35>, <181, 30, 25.15>, <181, 40, 25.15>, <185, 40, 25.15>, <188, 40, 25.15>];
string airportCellUUID = "4659fc78-c4a2-47e2-8356-9ee292ff9b4e";
list toRocketPod = [<181, 28, 35>, <181, 26, 25.5>, <181, 23, 25.5>];
string rocketPodUUID = "02e3a6eb-5d5d-6a0d-7daf-746d98a008d3";

// Sensing Operations
key guardGroupKey = "b3947eb2-4151-bd6d-8c63-da967677bc69";
key inmateGroupKey = "ce9356ec-47b1-5690-d759-04d8c8921476";
key welcomeGroupKey = "49b2eab0-67e6-4d07-8df1-21d3e03069d0";
vector gooTargetPos = <0,0,0>;
key gooTarget = NULL_KEY;
float RLVPingTime;

// IF someone is in these spheres, leave them alone
// Zen Garden wall, mobile cell in airport, airplane hangars, theater, theater
list ignoreLocations = [<128,128,23>, <188,40.5,23>, <134, 34, 23>, <128, 181, 22>, <128, 94, 22>];
list ignoreRadiuses = [28, 10, 20, 12, 12];

list RLVPingList; // people whose RLV relay status we are seeking
list avatarHasRLVList; // people we know have RLV relay
list noRLVList; // people we know have no relay

// teleport
vector teleportInmate = <116, 128, 1222>;
vector teleportFugitive = <128, 102, 1372>;
vector teleportTimber = <181, 37, 24>;

// ******** debug *************
integer DEBUG = FALSE;
setDebug(integer newstate){
    // Turns debug on and off,
    // sets opersting range and home position
    if (newstate) {
        sayDebug("Switching Debug ON");
        XPointList = debugXPointList;
        YPointList = debugYPointList; 
        homeIndex = <1,0,0>;
    } else {
        sayDebug("Switching Debug OFF");
        XPointList = normalXPointList;
        YPointList = normalYPointList;
        homeIndex = <3,0,0>;
    }    
    xMax = llGetListLength(XPointList) - 1;
    yMax = llGetListLength(YPointList) - 1;
    DEBUG = newstate;
    sayDebug("debug is on");
}

sayDebug(string message){
    if (DEBUG > 0) {
        llOwnerSay(message);
    }
}

// ************** Utilities ****************

integer pickOneInteger(list listOIntegers) {
    integer llength = llGetListLength(listOIntegers);
    integer index = (integer)llFrand(llength);
    return (integer)llList2Integer(listOIntegers, index);
}

integer hexToDecimal(string hex) {
    // ignores characters that are not hexadecimal digits
    // converts the rest into a decimal number 
    string digits = "0123456789ABCDEF";
    integer value = 0;
    integer iChar;
    integer iDigit;
    for (iChar = 0; iChar < llStringLength(hex); iChar = iChar + 1) {
        iDigit = llSubStringIndex(digits, llGetSubString(hex, iChar, iChar));
        if (iDigit > -1) {
            value = value * 16 + (integer)iDigit;
        }
    }
    return value;
}

vector vectorSetZ(vector start, float z) {
    // return a vector whose Z is set to this.
    // Where you see the pattern
    //      vector newVector = someVector;
    //      newVector.z = someAltitude;
    //      doSomethingWith(newVector);
    // and newVector is never used again, 
    // replace it with
    //      doSomethingWith(vectorSetZ(someVector, someAltitude))
    start.z = z;
    return start;
}

// ************** initialize ****************

initialize() {
    sayDebug("initialize");
    setDebug(DEBUG); // side effect sets home index
    
    // set this drone's number
    myKey = "x" + llToUpper(llGetSubString((string)llGetKey(), -4, -1));
    llSetObjectName("Inmate Hunter Drone "+myKey);
    
    llMessageLinked(LINK_ALL_CHILDREN, 0, "RESET", "");

    commandListen = llListen(commandChannel, "", NULL_KEY, "");
       
    // set Home
    positionIndex = homeIndex;
    home = indexToPosition(positionIndex);
    integer i = hexToDecimal(llGetSubString(myKey, -1, -1));
    // Roof of airport is 25 x 20 meters at 179.5, 42
    // This calculates each drone's position on the roof landing pads
    home.x = 170.125 + (i % 4) * 6.25;
    home.y = 34.5 + (i / 4) * 5;
    home.z = 28;
    goHome();

    // los gehts!
    llSetTimerEvent(2);
    sayDebug("initialize done "+(string)llGetPos());
}

// ****** Flight *******

// ------ Index Flight ------

vector indexToPosition(vector indexVector) {
    // an indexvector is a two dimensional index.
    // this converts that into a vector of real-world positions
    integer xindex = (integer)indexVector.x;
    integer yindex = (integer)indexVector.y;
    float xcoord = llList2Float(XPointList,xindex);
    float ycoord = llList2Float(YPointList,yindex);
    return <xcoord, ycoord, patrolAltitude>;
}

flyToIndex(vector newPositionIndex) {
    // pick an adjacent grid position to fly to 
    // point the drone toward that point
    // go there
    // set positionIndex
    vector newPosition = indexToPosition(newPositionIndex); 
    //sayDebug("flyToIndex("+(string)newPositionIndex+"):"+(string)newPosition);
    flyToPosition(newPosition);
    positionIndex = newPositionIndex;
}

vector getNearestIndex(vector target) {
    // From an XYZ location, search for the nearest standard coordinate. 
    sayDebug("getNearestIndex(" + (string)target + ")");
    integer x;
    integer y;
    float nearestDistance = 1000;
    vector nearestIndexVector = homeIndex; // failsafe default vector
    for (x = 0; x <= xMax; x = x + 1) {
        for (y = 0; y <= yMax; y = y + 1) {
            vector searchPosition = indexToPosition(<x, y, 0>);
            float distance = llVecDist(searchPosition, target);
            sayDebug((string)x+","+(string)y+": "+(string)searchPosition+" is "+(string)distance+" away");
            if (distance > 1000) {
                // something went very badly wrong.
                sayDebug("error in getNearestIndex: distance was "+(string)distance);
                mission = "HOME";
                command = "HOME";
                goHome();
                llResetScript();
            }
            if (distance < nearestDistance) {
                nearestDistance = distance;
                nearestIndexVector = <x, y, 0>;
            }            
        }
    }
    sayDebug("getNearestIndex(" + (string)target + ") found nearest at "+(string)nearestIndexVector);
    return nearestIndexVector;
}

vector pickAnAdjacentIndex(vector indexVector) {
    // Starting at a locations designated by the index,
    // pick a direction to move in.
    // If at edges, don't go beyond egdes. 
    // side effect: update previousDeltaIndex
    vector deltaIndex = <0,0,0>;
    
    integer found = FALSE;

    while (!found) {
        found = TRUE;
        // pick which way to go in X
        // clamp at edges
        list possibleXDirections = [];
        if (indexVector.x == 0) {
            possibleXDirections = [0, 1];
        } else if (indexVector.x == xMax) {
            possibleXDirections = [-1, 0];
        } else {
            possibleXDirections = [-1, 0, 1];
        }
        integer possibleX = pickOneInteger(possibleXDirections);
    
        // pick which way to go in Y
        // clamp at edges
        list possibleYDirections = [];
        if (indexVector.y == 0) {
            possibleYDirections = [0, 1];
        } else if (indexVector.y == yMax) {
            possibleYDirections = [-1, 0];
        } else {
            possibleYDirections = [-1, 0, 1];
        }
        integer possibleY = pickOneInteger(possibleYDirections);
    
        // only go in one direction
        if ((possibleX != 0) && (possibleY != 0)) {
            if (pickOneInteger([0, 1])) {
                possibleY = 0;
            } else {
                possibleX = 0;
            }
        }
        
        deltaIndex = <possibleX, possibleY, 0>;

        // have to go somewhere.         
        if (deltaIndex == <0,0,0>) {
            found = FALSE;
        }
        // don't go back
        //sayDebug("previousDeltaIndex:"+(string)previousDeltaIndex+"  deltaIndex:"+(string)deltaIndex);
        if (deltaIndex == -previousDeltaIndex) {
            found = FALSE;
        }
    }
    
    vector newIndex = indexVector + deltaIndex;
    previousDeltaIndex = deltaIndex;
    //sayDebug("pickAnAdjacentIndex("+(string)indexVector+") + "+(string)deltaIndex+ " returns "+(string)newIndex);
    return newIndex;
}

// ------ Coordinate Flight ------

flyToPosition(vector destination) {
    // moves object from where it is to destination
    // blocks while flying
    
    vector here = llGetPos();
    //sayDebug("flyToPosition from "+(string)here+" to "+(string)destination);
    vector bigdelta = (destination - here);
    float distance = llVecMag(bigdelta); // meters
    float loopInterval = 0.2; // seconds
    //sayDebug("flyToPosition bigdelta:"+(string)bigdelta+" distance:"+(string)distance);
    // we want to take this many steps to travel distance at speed meters per second
    integer steps = llFloor(distance / (5 * loopInterval));
    if (steps == 0) {
        // we're here.
        return;
    }
    vector smalldelta = bigdelta / steps;
    //sayDebug("flyToPosition smalldelta:"+(string)smalldelta+" in "+(string)steps+" steps");
    integer i;
    for (i = 0; i < steps; i = i + 1) {
        here = here + smalldelta;
        //sayDebug("flyToPosition llSetPos("+(string)here+")");
        llSetPos(here);
    }
}

flyHighToPosition(vector target) {
    if (llVecDist(llGetPos(), target) > 1.0) {
        rotateAzimuthToPosition(target);
        
        // fly up here to transport altitude
        flyToPosition(vectorSetZ(llGetPos(), transportAltitude));
        
        // calculate the target position up high and fly there
        flyToPosition(vectorSetZ(target, transportAltitude));
        
        // fly down to target altitude
        flyToPosition(target);
    }
}

flyToAvatar(key target, integer high) {
    //sayDebug("flyToAvatar");
    // Go to the target    
    vector targetPos = llList2Vector(llGetObjectDetails(target, [OBJECT_POS]), 0);
    targetPos.z = targetPos.z + 2;
    rotateAzimuthToTarget(target);
    if (high) {
        flyHighToPosition(targetPos);
    } else {
        flyToPosition(targetPos);
    }
}

// ------ Rotations ------

rotateAzimuthToPosition(vector targetPos) {
    // smoothly rotates the object on global Z so its X axis points to the global Z axis of the target.
    // get this object's positiom and rotation
    vector myPos = llGetPos();
    rotation isRot = llGetRot();
    vector isEuler = llRot2Euler(isRot);
    //sayDebug("rotateAzimuthToPosition "+(string)targetPos+"  MyPos:"+(string)myPos);
    
    // get angle to target object
    targetPos.z = myPos.z; 
    vector fwd = targetPos - myPos;
    vector left = fwd * <0.0, 0.0, llSin(PI_BY_TWO * 0.5), llCos(PI_BY_TWO * 0.5)>; //rotate 90 at z-axis
    left.z = 0.0;
    fwd = llVecNorm(fwd);
    left = llVecNorm(left);
    rotation targetRot = llAxes2Rot(fwd, left, fwd % left);
    vector targetEuler = llRot2Euler(targetRot);
    if (targetEuler.z == 0) {
        //sayDebug("rotateAzimuthToPosition returning targetEuler:"+(string)targetRot);
        return;
    }
    vector deltaEuler = targetEuler - isEuler;

    // if it's too far, go in the other direction
    if (deltaEuler.z > PI) {
        deltaEuler.z = TWO_PI - deltaEuler.z;
        targetEuler.z = isEuler.z - deltaEuler.z;
    } else if (deltaEuler.z < -PI) {
        deltaEuler.z = TWO_PI + deltaEuler.z;
        targetEuler.z = isEuler.z + deltaEuler.z;
    } 
    //sayDebug("targetEuler:"+(string)targetEuler+" - isEuler:"+(string)isEuler+" => deltaEuler:"+(string)deltaEuler);
    
    // do the rotation
    vector increment = <0, 0, PI/15.0>;
    if (deltaEuler.z > 0) {
        //sayDebug("deltaEuler.z:"+(string)deltaEuler.z+">0  targetEuler:"+(string)targetEuler);
        while (isEuler.z < targetEuler.z) {
            isEuler = isEuler + increment;
            llSetRot(llEuler2Rot(isEuler));
        }
    } else {
        //sayDebug("deltaEuler.z:"+(string)deltaEuler.z+"<=0  targetEuler:"+(string)targetEuler);
        while (isEuler.z > targetEuler.z) {
            isEuler = isEuler - increment;
            llSetRot(llEuler2Rot(isEuler));
        }
    }
    llSetRot(targetRot);
}

rotateAzimuthToTarget(key target) {
    // rotate object so its X points to the target's azimuth
    // (this does not aim anything up or down)
    vector targetPos = llList2Vector(llGetObjectDetails(target, [OBJECT_POS]), 0);
    //sayDebug("rotateAzimuthToTarget targetPos:"+(string)targetPos);
    rotateAzimuthToPosition(targetPos);
}

rotateAzimuthToIndex(vector index) {
    // rotate object so its X points to the target's azimuth
    // (this does not aim anything up or down)
    vector targetPos = indexToPosition(index);
    //sayDebug("rotateAzimuthToIndex("+(string)index+") targetPos:"+(string)targetPos);
    rotateAzimuthToPosition(targetPos);
}

// ------ Waypoint Flight ------

followWaypoints(list waypoints, integer there, string magicWord) {
    // waypoints is a list of coordinates to follow to deliver a miscreant
    // if there, then follow them forward; 
    //    before the last position, say the magic word to open a cell
    // if !there, then follow them backward from the next-to-last one. 
    //    before leaving, say the magic word to close the cell
    integer i;
    if (there) {
        integer last = llGetListLength(waypoints);
        for (i = 0; i < last; i = i + 1) {
            if (i == last -1) {
                llWhisper(commandChannel, magicWord);
                llSleep(2);
            }
            vector nextPosition = llList2Vector(waypoints, i);
            rotateAzimuthToPosition(nextPosition);
            flyToPosition(nextPosition);
        }
    } else {
        llWhisper(commandChannel, magicWord);
        llSleep(1);
        for (i = llGetListLength(waypoints)-1; i >= 0; i = i - 1) {
            vector nextPosition = llList2Vector(waypoints, i);
            rotateAzimuthToPosition(nextPosition);
            flyToPosition(nextPosition);
        }
    }
}

// ****** People ******

integer avatarIsInGroup(key avatar, key group)
{
    list attachList = llGetAttachedList(avatar);
    integer item;
    while(item < llGetListLength(attachList))
    {
        if(llList2Key(llGetObjectDetails(llList2Key(attachList, item), [OBJECT_GROUP]), 0) == group) {
            return TRUE;
        }
        item++;
    }
    return FALSE;
}

key extractKeyFromRLVStatus(string message, string unwanted) {
    // message is like RELEASED284ba63f-378b-4be6-84d9-10db6ae48b8d
    // unwanted is like RELEASED
    integer j = llStringLength(unwanted);
    string thekey = llGetSubString(message, j, -1);
    //sayDebug("extractKeyFromRLVStatus("+message+", "+unwanted+") returns "+thekey);
    return (key)thekey;
}

list addKeyToList(list theList, key target, string what) {
    sayDebug("addKeyToList("+what+","+llGetDisplayName(target)+")");
    theList = theList + [target];
    return theList;
}

list removeKeyFromList(list theList, key target, string what) {
    sayDebug("removeKeyFromList("+what+","+llGetDisplayName(target)+")");
    integer index = llListFindList(theList, [target]);
    if (index > -1) {
        sayDebug("removeKeyFromList("+llGetDisplayName(target)+") removed "+llGetDisplayName(target));
        theList = llDeleteSubList(theList, index, index);
    }
    return theList;
}

integer isKeyInList(list theList, key target, string what) {
    integer result = llListFindList(theList, [target]) > -1;
    sayDebug("isKeyInList("+what+","+llGetDisplayName(target)+") returns "+(string)result);
    return result;
}

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

carryAvatarSomewhere(key target, list waypoints, key sitHere, string magicWord1, string magicWord2) {
    //sayDebug("carryAvatarSomewhere");
    // We're already at the target
    
    // force-sit the target with hang animation. 
    //This "should" work in one command but it doesn't.
    string rlvCommand = "carry," + (string)target + ",@sit:" + (string)llGetKey() + "=force";
    //sayDebug(rlvCommand);
    llSay(rlvChannel, rlvCommand);
    rlvCommand = "carry," + (string)target + ",@unsit=n";
    //sayDebug(rlvCommand);
    llSay(rlvChannel, rlvCommand);

    flyToAvatar(target, TRUE);    
    flyToPosition(vectorSetZ(llGetPos(), transportAltitude));    
    
    // follow waypoints to the drop location
    followWaypoints(waypoints, TRUE, magicWord1);
    
    // drop target
    rlvCommand = "release," + (string)target + ",@unsit=y";
    //sayDebug(rlvCommand);
    llSay(rlvChannel, rlvCommand);
    rlvCommand = "release," + (string)target + ",@unsit=force";
    //sayDebug(rlvCommand);
    llSay(rlvChannel, rlvCommand);
    llSleep(1);
    
    // Make target sit on destination object
    rlvCommand = "sit," + (string)target + ",@sit:" + (string)sitHere + "=force";
    //sayDebug(rlvCommand);
    llSay(rlvChannel, rlvCommand);
    // we do NOT want to prevent unsit here because that wil break the rocket pod
    llSleep(1);
    
    // follow waypoints back to start
    followWaypoints(waypoints, FALSE, magicWord2);
    
    // then go back to where we were
    rotateAzimuthToPosition(llGetPos());
    flyHighToPosition(llGetPos()); 
}

aimGooGuns(key target) {
    sayDebug("aim GooGuns at "+llKey2Name(target));
    gooTarget = target;
    gooTargetPos = llList2Vector(llGetObjectDetails(target, [OBJECT_POS]), 0);
    
    // fly to a nearby firing position wihtin 10 meters but not aways the same place
    float x = llFrand(10) - 5.0;
    float y = llFrand(10) - 5.0;
    float z = llSqrt(100 - x * x - y * y);
    vector firingPosDelta = <x, y, z>;
    vector firingPos = gooTargetPos + firingPosDelta;  // have to be within 10 meters of target
    //sayDebug("fireGooGuns firingPos:"+(string)firingPos);
    rotateAzimuthToPosition(firingPos);
    flyHighToPosition(firingPos);
    rotateAzimuthToTarget(target);

    // get a range and bearing on the target
    vector deltaPos = gooTargetPos - firingPos;
    float deltaPosZ = deltaPos.z;
    deltaPos.z = 0;
    float range = llVecMag(deltaPos);
    float angle = llAtan2(range, deltaPosZ)*RAD_TO_DEG;
    
    // command the goo guns
    llMessageLinked(LINK_SET, (integer)range, "GOO_RANGE", NULL_KEY);
    llMessageLinked(LINK_SET, (integer)angle, "GOO_ANGLE", NULL_KEY);

    // dramatic pause in case anyone is watching
    llSleep(2);
    
    // make sure there's no goo present
    llSensor("Goo Trap", NULL_KEY, ACTIVE, 30, PI);
    sayDebug("aim GooGuns done");
}

fireGooGuns(key target) {
    // send the fire command
    // rez the goo
    // reset the googun elevation
    
    vector targetPos = llList2Vector(llGetObjectDetails(target, [OBJECT_POS]), 0);
    sayDebug("fireGooGuns at "+llGetDisplayName(target)+ "@" + (string)targetPos);

    llMessageLinked(LINK_SET, 0, "GOO_SHOOT", target);
    llSleep(2);

    // calculate the actual rez point just a little lower than the avatar
    targetPos.z = targetPos.z - 0.8; 
    //sayDebug("Attempting to rez goo at "+(string)gooPos);
    llRezAtRoot("Goo Trap", targetPos, <0,0,0>, llEuler2Rot(<0,90,0>*DEG_TO_RAD), DEBUG);
    
    // another dramatic pause, then reset the cannon.
    llSleep(2);    
    resetGooGuns();
    sayDebug("fireGooGuns done");
}

resetGooGuns() {
    sayDebug("resetGooGuns");
    llMessageLinked(LINK_SET, 0, "SCAN_STOP", NULL_KEY);
    llMessageLinked(LINK_SET, 0, "GOO_STOP", NULL_KEY);
    llMessageLinked(LINK_SET, 90, "GOO_ANGLE", NULL_KEY);    
    // clean up after goo
    gooTargetPos = <0,0,0>;
    gooTarget = NULL_KEY;
    command = mission;
    sayDebug("resetGooGuns done");
}

integer avatarIsInIgnoreArea(key target) {
    integer i;
    for (i = 0; i < llGetListLength(ignoreLocations); i = i + 1) {
        vector targetPos = llList2Vector(llGetObjectDetails(target, [OBJECT_POS]), 0);
        vector ignorePos = llList2Vector(ignoreLocations, i);
        float distance = llVecDist(targetPos, ignorePos);
        float radius = llList2Float(ignoreRadiuses, i);
        sayDebug("is "+llGetDisplayName(target)+" at "+(string)targetPos+" InIgnoreArea "+(string)ignorePos+"?");
        if (distance < radius) {
            sayDebug("yes");
            return TRUE;
        }
    }
    return FALSE;
}

respondToAvatar(key target, integer avatarHasRLV) {
    // point drone at the avatar being sensed
    // determine its group membership
    // tack at it or goo it
    string name = llGetDisplayName(target);
    sayDebug("respondToAvatar "+name+" "+(string)avatarHasRLV);
    
    if (!avatarIsInIgnoreArea(target)) {
        vector myPos = llGetPos();
        if (avatarIsInGroup(target, inmateGroupKey)){
            flyToAvatar(target, TRUE);
            if (avatarHasRLV) {
                llSay(0, "Inmate "+name+": Halt! You will now be taken to the airport for transport to Black Gazza.");
                carryAvatarSomewhere(target, toRocketPod, rocketPodUUID, "", "");
            } else {
                llSay(0, "Inmate "+name+"! Halt! You must return to Glack Gazza at once!");
                integer x = llFloor(myPos.x);
                integer y = llFloor(myPos.y);
                llShout(0,"An escaped inmate has been seen on the surface near coordinates "+(string)x+" by "+(string)y+".");
            }
        } else if (avatarIsInGroup(target, welcomeGroupKey)) {
            flyToAvatar(target, TRUE);
            if (avatarHasRLV) {
                llSay(0, "Fugitive "+name+"! Halt! You will be taken to the airport for transpotrt.");
                carryAvatarSomewhere(target, toAirport, airportCellUUID, "OPENCELL", "CLOSECELL");
            } else {
                llSay(0, "Fugitive "+name+"! Halt! You must return to Glack Gazza at once!");
                integer x = llFloor(myPos.x);
                integer y = llFloor(myPos.y);
                llShout(0,"A fugitive has been seen on the surface near coordinates "+(string)x+" by "+(string)y+".");
            }
        } else {
            llSay(0,"Welcome to Black Gazza, "+name+". May your stay be as long as you deserve.");
             if (avatarHasRLV) {
                aimGooGuns(target); // does all the flying
            }
        }
    }
}

// ************ Command and Control **********

goHome() {
    sayDebug("goHome:"+(string)home);
    flyHighToPosition(home);
    llSetRot(llEuler2Rot(<0,0,90>*DEG_TO_RAD));
    mission = "HOME";
    llMessageLinked(LINK_ALL_CHILDREN, 0, "Power Off", "");
}

goOnPatrol() {
    llMessageLinked(LINK_ALL_CHILDREN, 0, "Power On", "");
    llSleep(5);
    flyHighToPosition(indexToPosition(getNearestIndex(llGetPos())));
    mission = "PATROL";
    command = "PATROL";
}

reportPosition() {
    vector primPosition = llGetPos();
    vector primEuler = llRot2Euler(llGetRot());
    llOwnerSay("Position:"+(string)primPosition + ";  Rotation:" + (string)primEuler);
}

commandMenu(key avatar) 
{
    menuChannel = llFloor(llFrand(10000)+1000);
    menuListen = llListen(menuChannel, "", avatar, "");
    string text = "Select Command Fucktion "+(string)menuChannel;
    list buttons = ["Report", "Home", "Reset",  "Patrol", "Sense", "Cell", "Rocketpod", "Goo", "Beam"];
    if (DEBUG) {
        buttons = buttons + ["Debug OFF"];
    } else {
        buttons = buttons + ["Debug ON"];
    }
    llSetTimerEvent(30);
    llDialog(avatar, text, buttons, menuChannel);
}

default
{
    state_entry()
    {
        initialize();
    }
    
    on_rez(integer startParameter) {
        initialize();
    }
    
    touch_start(integer num)
    {
        key target = llDetectedKey(0);
        if (DEBUG) {
            commandMenu(target);
        } else {
            if (avatarIsInGroup(target, guardGroupKey)) {
                commandMenu(target);
            } else {
                llSensor("",NULL_KEY, AGENT, sensorRange, PI);
                command = "SENSOR";
            }
            // thread gets pikced up at sensor, same as for a patrol. 
        }
    }
    
    listen(integer channel, string name, key target, string message) {
        if (channel == menuChannel){
            llListenRemove(menuListen);
            menuListen = 0;
            llSetTimerEvent(2);
        }
        if ((channel == menuChannel) || (channel == commandChannel)){
            sayDebug("listen command:"+message);
            if (message == "Report") {
                reportPosition();
            } else if (message == "Home") {
                mission = "HOME";
                command = "HOME";
            } else if (message == "Reset") {
                llMessageLinked(LINK_ALL_CHILDREN, 0, "RESET", "");
                llResetScript();
            } else if (message == "Patrol") {
                goOnPatrol();
            } else if (message == "Sense") {
                llSensor("",target, AGENT, 20, PI);
                command = "SENSOR";
            } else if (message == "Cell") {
                flyToAvatar(target, TRUE);
                carryAvatarSomewhere(target, toAirport, airportCellUUID, "OPENCELL", "CLOSECELL");
            } else if (message == "Rocketpod") {
                flyToAvatar(target, TRUE);
                carryAvatarSomewhere(target, toRocketPod, rocketPodUUID, "", "");
            } else if (message == "Goo") {
                aimGooGuns(target);
            } else if (message == "Beam") {
                flyToAvatar(target, FALSE);
                teleportAvatarToCoordinates(target, teleportTimber);
            } else if (message == "Debug OFF") {
                sayDebug("Switching Debug off.");
                setDebug(FALSE);
            } else if (message == "Debug ON") {
                setDebug(TRUE);
            } else {
                sayDebug("Error: Could not process message: "+message);
            }
        }
        if (channel == menuChannel){
            menuChannel = 0;
        }
        if (channel == rlvChannel) {
            // sayDebug("listen on rlvChannel name:"+name+" target:"+(string)target+" message:"+message);
            // status message looks like
            // status,20f3ae88-693f-3828-5bad-ac9a7b604953,!getstatus,
            // but we don't care what that UUID is.
            list responseList = llParseString2List(message, [","], []);
            string status = llList2String(responseList,0);
            string getstatus = llList2String(responseList,2);
            integer avatarHasRLV = ((status == "status") && (getstatus == "!getstatus"));
            //sayDebug("status:"+status+"  getstatus:"+getstatus+"  avatarHasRLV:"+(string)avatarHasRLV);
            target = llGetOwnerKey(target); // convert relay UUID to its wearer UUID
            sayDebug("avatar:"+(string)target+" name:"+llKey2Name(target));
            if (isKeyInList(RLVPingList, target, "rlvPing")) {
                RLVPingList = removeKeyFromList(RLVPingList, target, "RLVPing");
                if (avatarHasRLV) {
                    sayDebug("avatar:"+llKey2Name(target)+" has RLV");
                    avatarHasRLVList = addKeyToList(avatarHasRLVList, target, "avatarHasRLV");
                } else {
                    sayDebug("avatar:"+llKey2Name(target)+" does not have RLV");
                    noRLVList = addKeyToList(noRLVList, target, "noRLV");
                }
                command = "HANDLE";
                llSetTimerEvent(2);
            } else {
                sayDebug("listen rlvChannel ignores "+llGetDisplayName(target)+" because not pinged");
            }
        }
        //sayDebug("listen message:\""+message+"\" command:"+command);        
    } 
    
    timer() {
        //sayDebug("timer enter command:"+command+ "menuChannel:"+(string)menuChannel);        
        if (menuChannel != 0) {
            sayDebug("timer end menu");
            llListenRemove(menuListen);
            menuListen = 0;
            menuChannel = 0;
            llSetTimerEvent(2);
        } else if (command == "HOME") {
            sayDebug("timer command:"+command);
            command = "";
            goHome();
        } else if (command == "PATROL") {
            sayDebug("timer command:"+command);
            vector newPositionIndex = pickAnAdjacentIndex(positionIndex);
            rotateAzimuthToIndex(newPositionIndex);
            flyToIndex(newPositionIndex);
            llSensor("",NULL_KEY, AGENT, sensorRange, PI);
        } else if (command == "SENSOR_PINGS") {
            // we didn't get any for some reason. Fail safe, contrinue patrolling
            sayDebug("timer command:"+command);
            if ((llGetListLength(RLVPingList) > 0) && (llGetTime()-RLVPingTime > 5)) {
                command = "HANDLE";            
            }
        } else if (command == "HANDLE") {
            sayDebug("timer command:"+command);        
            integer i;
            // everybody still in the ping list, assume no RLV relay
            if (llGetListLength(RLVPingList) > 0) {
                noRLVList = noRLVList + RLVPingList;
                RLVPingList = [];
                llListenRemove(RLVListen);
                RLVListen = 0;
            }
            
            // handle the no RLV list first
            for (i = 0; i < llGetListLength(noRLVList); i = i + 1) {
                respondToAvatar(llList2Key(noRLVList, i), FALSE);                
            }
            noRLVList = [];
            
            // handle everyone with RLV
            for (i = 0; i < llGetListLength(avatarHasRLVList); i = i + 1) {
                respondToAvatar(llList2Key(avatarHasRLVList, i), TRUE);
            }
            avatarHasRLVList = [];
            
            command = mission;
            sayDebug("end timer command:"+command);        
        }
    }
    
    sensor(integer avatars_found) {
        if (gooTarget == NULL_KEY) {
            integer i;
            for (i = 0; i < avatars_found; i = i + 1) {
                key target = llDetectedKey(i);
                string name = llGetDisplayName(target);
                if (avatarIsInIgnoreArea(target)) {
                    sayDebug("sensor ignores "+name+" because in ignore area");
                } else {
                    sayDebug("sensor "+name);
                    llMessageLinked(LINK_ALL_OTHERS, 0, "SCAN_START", target);
                    if (avatarIsInGroup(target, guardGroupKey)) {
                        llSay(0,"Greetings, "+name+". Keep up the good work.");
                    } else {
                        // avatar is not in guard group. ask for RLV. 
                        sayDebug("sensor test for RLV relays");
                        if (RLVListen == 0) {
                            RLVListen = llListen(rlvChannel, "", NULL_KEY, "");
                        }
                        RLVPingTime = llGetTime();
                        RLVPingList = addKeyToList(RLVPingList, target, "RLVPing");
                        llSay(rlvChannel,"status," + (string)target + ",!getstatus");
                        command = "SENSOR_PINGS";
                        // if relay responds
                        // then thread gets picked up in listen rlv chanel
                        // else thread gets picked up in timer rlv channel
                        // so we have to give it time to respond
                    }
                llSleep(2); // gives time for waves effect and response
                llMessageLinked(LINK_ALL_OTHERS, 0, "SCAN_STOP", target);
                }
            }
        } else {
            // deal with the goo
            // we had a non-zero gooTargetPos, and there was goo,
            // so don'gt do anything
            sayDebug("ewww, there's goo!");
            resetGooGuns();
        }
        // pick up in Listen (with RLV) or in Timer (without)
    }
    
    no_sensor() {
        //sayDebug("no_sensor");
        if (gooTarget == NULL_KEY) {
            resetGooGuns();
        } else {
            // we had targeted goo and there wasn't any, so squir goo. 
            sayDebug("The Goo must flow!");
            fireGooGuns(gooTarget);
            resetGooGuns();
        }
    }
}
