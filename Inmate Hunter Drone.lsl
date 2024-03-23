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
list toAirport = [<181, 28, 55>, <181, 30, 25.5>, <181, 40, 25.5>, <185, 40, 25.5>, <187, 40, 25.5>];
string airportCellUUID = "4659fc78-c4a2-47e2-8356-9ee292ff9b4e";
list toRocketPod = [<181, 28, 55>, <181, 26, 25.5>, <181, 23, 25.5>];
string rocketPodUUID = "02e3a6eb-5d5d-6a0d-7daf-746d98a008d3";

// Sensing Operaitons
key guardGroupKey = "b3947eb2-4151-bd6d-8c63-da967677bc69";
key inmateGroupKey = "ce9356ec-47b1-5690-d759-04d8c8921476";
key welcomeGroupKey = "49b2eab0-67e6-4d07-8df1-21d3e03069d0";

// IF someone is in these spheres, leave them alone
// Zen Garden wall, mobile cell in airport, airplane hangars
list ignoreLocations = [<128,128,23>, <188,40.5,23>, <134, 34, 23>];
list ignoreRadiuses = [28,10,20];

list RLVPingList; // people whose RLV relay status we are seeking
list avatarHasRLVList; // people we know have RLV relay
list noRLVList; // people we know have no relay

// teleport
vector teleportInmate = <116, 128, 1222>;
vector teleportFugitive = <128, 102, 1372>;
vector teleportTimber = <181, 37, 24>;

// ******** debug *************
integer DEBUG = TRUE;
setDebug(integer newstate){
    // Turns debug on and off,
    // sets opersting range and home position
    if (newstate) {
        sayDebug("Switching Debug OFF");
        XPointList = debugXPointList;
        YPointList = debugYPointList; 
        homeIndex = <1,0,0>;
    } else {
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

// ************** initialize ****************

initialize() {
    sayDebug("initialize");
    
    // set this drone's number
    myKey = "x" + llToUpper(llGetSubString((string)llGetKey(), -4, -1));
    sayDebug(myKey);
    llSetObjectName("Inmate Hunter Drone "+myKey);
    
    llMessageLinked(LINK_ALL_CHILDREN, 0, "RESET", "");

    // set operating parameters
    string description = llToUpper(llGetObjectDesc());
    setDebug((llSubStringIndex(description,"DEBUG") > -1));
    if (llSubStringIndex(description,"HOME") > -1) {
        setCommand("HOME");
    }
    if (llSubStringIndex(description,"PATROL") > -1) {
        setCommand("PATROL");
    }

    commandListen = llListen(commandChannel, "", NULL_KEY, "");
       
    // set Home
    positionIndex = homeIndex;
    home = indexToPosition(positionIndex);
    float eastness = hexToDecimal(llGetSubString(myKey, -1, -1)) * 2;
    sayDebug("eastness:"+(string)eastness);
    home.x = home.x + eastness;
    home.z = 22;
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

flyToAvatar(key target) {
    //sayDebug("flyToAvatar");
    // Go to the target
    vector myPos = llGetPos();
    vector targetPos = llList2Vector(llGetObjectDetails(target, [OBJECT_POS]), 0);
    targetPos.z = targetPos.z+2;  // go a little higher than the avatar
    rotateAzimuthToTarget(target);
    flyToPosition(targetPos);
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

goHome() {
    sayDebug("goHome:"+(string)home);
    rotateAzimuthToPosition(home);
    flyToPosition(home);
    llSetRot(<0,0,0,0>);
}

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
            }
            vector nextPosition = llList2Vector(waypoints, i);
            rotateAzimuthToPosition(nextPosition);
            flyToPosition(nextPosition);
        }
    } else {
        llWhisper(commandChannel, magicWord);
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
    llSay(rlvChannel,rlvCommand);

    // Go way up high to clear buldings
    vector targetPos = llGetPos();
    targetPos.z = transportAltitude;  // go a little higher than the avatar
    flyToPosition(targetPos);
    
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
    rotateAzimuthToPosition(targetPos);
    flyToPosition(targetPos); // next command will go to correct latitude 
}

aimAndFireGooGuns(key target) {
    // calculate the range and elevation for the target
    // send range and elevation angle to the googuns
    // send the fire command
    // reset the googun elevation
    
    vector targetPos = llList2Vector(llGetObjectDetails(target, [OBJECT_POS]), 0);
    //sayDebug("aimAndFireGooGuns at "+llGetDisplayName(target)+ "@" + (string)targetPos);

    // fly to a nearby firing position wihtin 10 meters but not aways the same place
    float x = llFrand(10) - 5.0;
    float y = llFrand(10) - 5.0;
    float z = llSqrt(100 - x * x - y * y);
    vector firingPosDelta = <x, y, z>;
    vector firingPos = targetPos + firingPosDelta;  // have to be within 10 meters of target
    if (firingPos.z > patrolAltitude) {
        firingPos.z = patrolAltitude;
    }
    //sayDebug("aimAndFireGooGuns firingPos:"+(string)firingPos);
    rotateAzimuthToPosition(firingPos);
    flyToPosition(firingPos);
    rotateAzimuthToTarget(target);

    // get a range and bearing on the target
    vector deltaPos = targetPos - firingPos;
    float deltaPosZ = deltaPos.z;
    deltaPos.z = 0;
    float range = llVecMag(deltaPos);
    float angle = llAtan2(range, deltaPosZ)*RAD_TO_DEG;
    
    // command the goo guns
    llMessageLinked(LINK_SET, (integer)range, "GOO_RANGE", target);
    llMessageLinked(LINK_SET, (integer)angle, "GOO_ANGLE", target);
    llMessageLinked(LINK_SET, 0, "GOO_SHOOT", target);
    
    // dramatic pause in case anyone is watching
    llSleep(3);
    
    // calculate the actual rez point - on the surface
    vector gooPos = targetPos;
    gooPos.z = 21.6;
    //sayDebug("Attempting to rez goo at "+(string)gooPos);
    llRezAtRoot("Goo Trap", gooPos, <0,0,0>, llEuler2Rot(<0,90,0>*DEG_TO_RAD), DEBUG);
    
    // another dramatic pause, then fly back to where we were
    llSleep(2);
    llMessageLinked(LINK_SET, 0, "GOO_STOP", target);
    llMessageLinked(LINK_SET, 90, "GOO_ANGLE", target);
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
            flyToAvatar(target);
            if (avatarHasRLV) {
                llSay(0, "Inmate "+name+": Halt! You will now be taken to the airport for transport to Black Gazza.");
                carryAvatarSomewhere(target, toRocketPod, rocketPodUUID, "", "");
            } else {
                llSay(0, "Inmate "+name+"! Halt! You must return to Glack Gazza at once!");
                integer x = llFloor(myPos.x);
                integer y = llFloor(myPos.y);
                llRegionSay(0,"An escaped inmate has been seen on the surface near coordinates "+(string)x+" by "+(string)y+".");
            }
        } else if (avatarIsInGroup(target, welcomeGroupKey)) {
            flyToAvatar(target);
            if (avatarHasRLV) {
                llSay(0, "Fugitive "+name+"! Halt! You will be taken to the airport for transpotrt.");
                carryAvatarSomewhere(target, toAirport, airportCellUUID, "OPENCELL", "CLOSECELL");
            } else {
                llSay(0, "Fugitive "+name+"! Halt! You must return to Glack Gazza at once!");
                integer x = llFloor(myPos.x);
                integer y = llFloor(myPos.y);
                llRegionSay(0,"A fugitive has been seen on the surface near coordinates "+(string)x+" by "+(string)y+".");
            }
        } else {
            llSay(0,"Welcome to Black Gazza, "+name+". May your stay be as long as you deserve.");
             if (avatarHasRLV) {
                aimAndFireGooGuns(target); // does all the flying
            }
        }
        rotateAzimuthToPosition(myPos);
        flyToPosition(myPos);
    }
}

// ************ Command and Control **********

reportPosition() {
    vector primPosition = llGetPos();
    vector primEuler = llRot2Euler(llGetRot());
    llOwnerSay("Position:"+(string)primPosition + ";  Rotation:" + (string)primEuler);
}

setCommand(string newCommand) {
    if (command != newCommand) {
        sayDebug("setCommand("+newCommand+")");
        command = newCommand;
    }
}

commandMenu(key avatar) 
{
    menuChannel = llFloor(llFrand(10000)+1000);
    menuListen = llListen(menuChannel, "", avatar, "");
    string text = "Select Command Fucktion "+(string)menuChannel;
    list buttons = ["Report", "Patrol", "Home", "Sense", "Cell", "Rocketpod", "Goo", "Beam"];
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
                setCommand("SENSOR");
            }
            // thread gets pikced up at sensor, same as for a patrol. 
        }
    }
    
    listen(integer channel, string name, key target, string message) {
        if ((channel == menuChannel) || (channel == commandChannel)){
            sayDebug("listen command:"+message);
            if (message == "Report") {
                reportPosition();
            } else if (message == "Patrol") {
                llMessageLinked(LINK_ALL_CHILDREN, 0, "Power On", "");
                setCommand("PATROL");
            } else if (message == "Home") {
                llMessageLinked(LINK_ALL_CHILDREN, 0, "Power Off", "");
                llResetScript();
            } else if (message == "Debug OFF") {
                sayDebug("Switching Debug off.");
                setDebug(FALSE);
            } else if (message == "Debug ON") {
                setDebug(TRUE);
            } else if (message == "Sense") {
                llSensor("",target, AGENT, 20, PI);
                setCommand("SENSOR");
            } else if (message == "Beam") {
                flyToAvatar(target);
                teleportAvatarToCoordinates(target, teleportTimber);
                setCommand("HOME");
            } else if (message == "Cell") {
                vector myPos = llGetPos();
                flyToAvatar(target);
                carryAvatarSomewhere(target, toAirport, airportCellUUID, "OPENCELL", "CLOSECELL");
                rotateAzimuthToPosition(myPos);
                flyToPosition(myPos);
                setCommand("HOME");
            } else if (message == "Rocketpod") {
                vector myPos = llGetPos();
                flyToAvatar(target);
                carryAvatarSomewhere(target, toRocketPod, rocketPodUUID, "", "");
                rotateAzimuthToPosition(myPos);
                flyToPosition(myPos);
                setCommand("HOME");
            } else if (message == "Goo") {
                aimAndFireGooGuns(target);
                setCommand("HOME");
            } else {
                sayDebug("Error: Could not process message: "+message);
            }
        }
        if (channel == menuChannel){
            llListenRemove(menuListen);
            menuListen = 0;
            menuChannel = 0;
            llSetTimerEvent(2);
        }
        if (channel == rlvChannel) {
            // sayDebug("listen on rlvChannel name:"+name+" target:"+(string)target+" message:"+message);
            // status message looks like
            // status,20f3ae88-693f-3828-5bad-ac9a7b604953,!getstatus,
            // but we don't care what that UUID is. .
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
                    avatarHasRLVList = addKeyToList(avatarHasRLVList, target, "avatarHasRLV");
                } else {
                    noRLVList = addKeyToList(noRLVList, target, "noRLV");
                }
                setCommand("HANDLE");
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
            llSetTimerEvent(1);
        } else if (command == "PATROL") {
            sayDebug("timer command:"+command);
            vector newPositionIndex = pickAnAdjacentIndex(positionIndex);
            rotateAzimuthToIndex(newPositionIndex);
            flyToIndex(newPositionIndex);
            llSensor("",NULL_KEY, AGENT, sensorRange, PI);
        } else if (command == "SENSOR_PINGS") {
            // we didn't get any for some reason. Fails afe, contrinue patrolling
            sayDebug("timer command:"+command);
            if (llGetListLength(RLVPingList) <= 0) {
                setCommand("PATROL");            
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
            
            setCommand("PATROL");
            sayDebug("end timer command:"+command);        
        }
    }
    
    sensor(integer avatars_found) {
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
                    if (RLVListen == 0) {
                       RLVListen = llListen(rlvChannel, "", NULL_KEY, "");
                    }
                    RLVPingList = addKeyToList(RLVPingList, target, "RLVPing");
                    llShout(rlvChannel,"status," + (string)target + ",!getstatus");
                    setCommand("SENSOR_PINGS");
                    // if relay responds
                    // then thread gets picked up in listen rlv chanel
                    // else thread gets picked up in timer rlv channel
                    // so we have to give it time to respond
                }
                llSleep(2); // gives time for waves effect and response
                llMessageLinked(LINK_ALL_OTHERS, 0, "SCAN_STOP", target);
            }
        }
        // pick up in Listen or in Timer
    }
    
    no_sensor() {
        //sayDebug("no_sensor");
        llMessageLinked(LINK_SET, 0, "SCAN_STOP", NULL_KEY);
        setCommand("PATROL");
    }
}
