 // Prgrammable Flight
//
// Provides manual XYZ and programmed flight of any vehicle. 

// Orientation: 
// Assumes that a cube at <0,0,0> rotation moves forward in +X, left in +Y, and up in +z.

// Flight Programming: 
// Flight scripts are written in indivdidual documents; the name shows up in a list. 
// Waypoints are formatted like
// <128.00000, 42.00000, 21.50000>,<0.00000, 0.01574, -90.00003>, 5, 
// Where the first vector is an XYZ position in the sim, 
// the second vector is XYZ rotation, 
// the last number is the time to get to this point. 
// One of the basic menu functions is "Report". 
// Set the vehicle to a waypoint position and orientation. 
// Click it and select Report. 
// It will tell you the position and rotation for that entry. 
// Copy it from chat and into a notecard. 
// The script will read the selected notecard and generate waypoints.
// Then the flight script will rotate and move the craft 
// while sending proper signals to thrusters.
// The script does not use SL's tweening animation. 

// Doors: 
// The Open and Close commnds link messages "open" and "close" to all prims in the linkset. 
// They can be manually opened and closed form the menu, 
// and the automated flight system sends these commands. 
// And door or hatch should receive those link messages
// and respond appropriately. 

// Timberwoof Lupindo

list gFlightPlanNames = [];
list gKeyFrames = []; // pos, rot, time
integer gNumKeyFrames = 0;

vector pilotCamera = <0.0, 0.0, 2.4>;
vector pilotLookAt = <5.0, 0.0, 2.1>;
vector thirdCamera = <-15, 0.0, 5>;
vector thirdLookAt = <2.0, 0.0, 1.3>;

string gSoundgWhiteNoise = "9bc5de1c-5a36-d5fa-cdb7-8ef7cbc93bdc";
string gHumSound = "46157083-3135-fb2a-2beb-0f2c67893907";

// *************************************
// BFI animated automated flight
rotation gHomeRot;
vector gHomePos;
integer time;
float gTotalTime;

integer gMenuChannel = 0;
integer gMenuListen;

string gNotecardName;
key gNotecardQueryId;
integer gNotecardLine = 0;
float gStepInterval = 0.2; // seconds
integer gFrame;
vector gFrameDetaPos;
vector gFrameDeltaEuler;
integer gStep;
float gSteps;
vector gStepDetaPos;
vector gStepDeltaEuler;
string gNudge;
string gBackNudge; 
integer gThrust;

integer UNKNOWN = -1;
integer CLOSED = 0;
integer OPEN = 1;
integer gPilotHatchState = 0;
integer ghatch = 0;

integer DEBUG = TRUE;
sayDebug(string message){
    if (DEBUG > 0) {
        llOwnerSay(message);
    }
}

// ------ Coordinate Flight ------

vector getWaypointPos(integer frame) {
    return llList2Vector(gKeyFrames, frame*3);
}

rotation getWaypointRot(integer frame) {
    return llList2Rot(gKeyFrames, frame*3+1);
}

float getWaypointTime(integer frame) {
    return llList2Integer(gKeyFrames, frame*3+2);
}

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

thrust() {
    // fwd back up dpwn LEFT RIGHT : translation
    // left right " rotation
    // must compare delta which is in global coordinates to llGetRot()
    // gFrameDetaPos is in global reference frame
    // So we need to conver that into the ship's rocket hrusts
    vector localDeltaPos = gFrameDetaPos / llGetRot();
    
    // Round off the vector to .01 in each axis
    localDeltaPos = (localDeltaPos + <0.05, 0.05, 0.05>) * 10.0 ;
    localDeltaPos.x = llFloor(localDeltaPos.x) / 10.0;
    localDeltaPos.y = llFloor(localDeltaPos.y) / 10.0;
    localDeltaPos.z = llFloor(localDeltaPos.z) / 10.0;
    
    if (localDeltaPos.x > 0) {
        llMessageLinked(LINK_ALL_CHILDREN, llFloor(localDeltaPos.x), "fwd", id);
    }
    if (localDeltaPos.x < 0) {
        llMessageLinked(LINK_ALL_CHILDREN, -llFloor(localDeltaPos.x), "back", id);
    }
    if (localDeltaPos.y > 0) {
        llMessageLinked(LINK_ALL_CHILDREN, llFloor(localDeltaPos.y), "LEFT", id);
    }
    if (localDeltaPos.y < 0) {
        llMessageLinked(LINK_ALL_CHILDREN, -llFloor(localDeltaPos.y), "RIGHT", id);
    }
    if (localDeltaPos.z > 0) {
        llMessageLinked(LINK_ALL_CHILDREN, llFloor(localDeltaPos.z), "up", id);
    }
    if (localDeltaPos.z < 0) {
        llMessageLinked(LINK_ALL_CHILDREN, -llFloor(localDeltaPos.z), "down", id);
    }
    if (gFrameDeltaEuler.z < 0) {
        llMessageLinked(LINK_ALL_CHILDREN, -llFloor(gFrameDeltaEuler.z), "right", id);
    }
    if (gFrameDeltaEuler.z > 0) {
        llMessageLinked(LINK_ALL_CHILDREN, llFloor(gFrameDeltaEuler.z), "left", id);
    }
    gThrust = (integer)llFloor(llVecMag(gFrameDetaPos) + llVecMag(gFrameDeltaEuler));
}

flyAndRotateToNextPosition() {
    vector isPos = llGetPos();
    rotation isRot = llGetRot();
    vector isEuler = llRot2Euler(isRot);
    vector newEuler = llRot2Euler(getWaypointRot(gFrame));
        
    if (gStep == 0) {
        // here is where the back thrust will go
        gSteps = getWaypointTime(gFrame) / gStepInterval;
        if (gSteps == 0) {
            llSay(0,"flyAndRotateToNextPosition ERROR: at gFrame "+(string)gFrame+" gSteps == 0");
            gFrame = gFrame + 1;
            return;
        }
        gFrameDetaPos = getWaypointPos(gFrame) - isPos;
        gFrameDeltaEuler = newEuler - isEuler;
        thrust();
        gStepDetaPos = gFrameDetaPos / gSteps;
        gStepDeltaEuler = gFrameDeltaEuler / gSteps; // could cause problems with 0 crossings
    }
    
    isPos = isPos + gStepDetaPos;
    isEuler = isEuler + gStepDeltaEuler;
    
    llSetLinkPrimitiveParamsFast(LINK_SET, [PRIM_POSITION, isPos]); // limited to 10 meters 10 m / 0.2 sec = 200 m/sec
    llSetRot(llEuler2Rot(isEuler));
    //llSetLinkPrimitiveParamsFast(LINK_SET, [PRIM_ROTATION, llEuler2Rot(isEuler)]); 
    // LINK_SET does a wonderful but terrible rotation of every rpimt
    gStep = gStep + 1;
    if (gStep >= gSteps) {
        gStep = 0;
        gFrame = gFrame + 1;
    }

}

followWaypoints(list waypoints) {
    // waypoints is a list of coordinates to follow 
    integer i;
    integer last = llGetListLength(waypoints);
    for (i = 0; i < last; i = i + 1) {
        vector nextPosition = llList2Vector(waypoints, i);
        rotateAzimuthToPosition(nextPosition);
        flyToPosition(nextPosition);
    }
}


automatedFlightPlansMenu(key avatar) {
    llWhisper(0,"automatedFlightPlansMenu");
    
    list buttons = [];
    string message = "Choose a a Flight Plan:\n ";
    integer number_of_notecards = llGetInventoryNumber(INVENTORY_NOTECARD);
    integer index;
    gFlightPlanNames = ["Plan0"];
    for (index = 0; index < number_of_notecards; index++) {
        integer inumber = index+1;
        string flightPlanName = llGetInventoryName(INVENTORY_NOTECARD,index);
        gFlightPlanNames = gFlightPlanNames + [flightPlanName];
        message += "\n" + (string)inumber + " - " + flightPlanName;
        buttons += ["Plan "+(string)inumber];
    }

    gMenuChannel = -(integer)llFrand(8999)+1000; // generate a session menu channel
    gMenuListen = llListen(gMenuChannel, "", avatar, "" );
    llDialog(avatar, message, buttons, gMenuChannel);
    llSetTimerEvent(30);    
    }
    
    
resetFlightPlan() {
    gKeyFrames = [];
    gNotecardLine = 0;
    gTotalTime = 0;
    gFrame = 0;
    gStep = 0;
    gHomePos = llGetPos();
    gHomeRot = llGetRot();
}

readFlightPlan(integer planNumber) {
    resetFlightPlan();
    gNotecardName = llList2String(gFlightPlanNames, planNumber);
    llWhisper(0,"Reading Flight Plan "+(string)planNumber+" '"+gNotecardName+"'");
    gNotecardQueryId = llGetNotecardLine(gNotecardName, gNotecardLine);
}


rotation NormRot(rotation Q)
//        gDeltaRot = NormRot(thisRot/gLastRot);
{
    float MagQ = llSqrt(Q.x*Q.x + Q.y*Q.y +Q.z*Q.z + Q.s*Q.s);
    return <Q.x/MagQ, Q.y/MagQ, Q.z/MagQ, Q.s/MagQ>;
}


handleDataServer(string data) {
    if (llGetSubString(data, 0, 0) != "#" & data != "") {
        // parse the data line into pieces
        list parsed = llParseString2List(data, [";"], []);
        vector thisLoc = (vector)llList2String(parsed, 0);
        vector thisEul = (vector)llList2String(parsed, 1);
        rotation thisRot = llEuler2Rot(thisEul * DEG_TO_RAD);
        float deltaTime = (float)llList2String(parsed, 2);
        gKeyFrames = gKeyFrames + [thisLoc, thisRot, deltaTime];
        gTotalTime = gTotalTime + deltaTime;
        gNumKeyFrames = gNumKeyFrames + 1;
    }
    ++gNotecardLine; //Increment line number (read next line).
    gNotecardQueryId = llGetNotecardLine(gNotecardName, gNotecardLine); //Query the dataserver for the next notecard line.
}



// **********************
// physical manual flight
float LINEAR_TAU = 0.75;             
float TARGET_INCREMENT = 0.5;
float ANGULAR_TAU = 1.5;
float ANGULAR_DAMPING = 0.85;
float THETA_INCREMENT = 0.3;
vector pos;
vector face;
float brake = 0.5;
key gOwnerKey; 
string gOwnerName;
key gToucher;
key Pilot;
float humVolume=1.0;
string instructionNote = "Orbital Prisoner Transport Shuttle";
key id;
vector POSITION; 
integer auto=FALSE;
integer CHANNEL = 6;

float gLastMessage;

travelTo(list destinationsList){
    while (llGetListLength(destinationsList) > 0) {
        vector NextCoord = llList2Vector(destinationsList,0);
        vector NextRot = llList2Vector(destinationsList,1);
        float time = llList2Float(destinationsList,2);
        destinationsList = llDeleteSubList(destinationsList,0,2);
        llRotLookAt(llEuler2Rot(NextRot * DEG_TO_RAD),1.5,0.2);
        llMoveToTarget(NextCoord,time);
        while (llVecDist(llGetPos(), NextCoord) > 5.0) {
            llSleep(0.2);
        }
    }
}

help()
{
    llWhisper(0,"Main Menu:");
    llWhisper(0,"Open/Close Hatch: opens or closes pilot hatch");
    llWhisper(0,"Fly: manual flight mode");
    llWhisper(0,"Report: reports location and attitude");
    llWhisper(0,"View:Pilot: sets eyepoint to pilot's view (do this before sitting)");
    llWhisper(0,"View:3rd: sets eyepoint to 3rd person view (do this before sitting)");
    llWhisper(0," ");
    llWhisper(0,"Flight Menu:");
    llWhisper(0,"Stop: Stops the ship where you are, returns to Main Menu.");
    llWhisper(0,"Report: reports location and attitude");
    llWhisper(0,"__%: Sets power level. Use low power near station.");
    llWhisper(0," ");
    llWhisper(0,"Flight Commands:");
    llWhisper(0,"PgUp or PgDn = Gain or lose altitude");
    llWhisper(0,"Arrow keys = Left, right, Forwards and Back");
    llWhisper(0,"Shift + Left or Right arrow = Rotate but maintain view");
    llWhisper(0,"PgUp + PgDn or combination similar = Set cruise on or off");
}

stop() {
    TARGET_INCREMENT = 0.5;
    auto=FALSE;
    //llSleep(1.5);
    llStopSound();
    llSetStatus(STATUS_PHYSICS, FALSE);
    llSetStatus(STATUS_PHANTOM, TRUE);
    llMessageLinked(LINK_SET, 0, "Power Off", "");
    llSetTimerEvent(0.0);
    llReleaseControls();
    llWhisper(0,"Stopped.");
}

report() {
    vector vPosition = llGetPos();
    string sPosition = (string)vPosition;
    vector vOrientation = llRot2Euler(llGetRot())*RAD_TO_DEG;
    string sOrientation = (string)vOrientation;
    
    llWhisper(0,llReplaceSubString(sPosition, " ", "", 0)+";"+llReplaceSubString(sOrientation, " ", "", 0)+";10;");
}

default
{

    state_entry()
    {
        llWhisper(0,"Power-On Self Test Activated");
        gOwnerKey = llGetOwner();
        gOwnerName = llKey2Name(llGetOwner());
        
        llPreloadSound(gHumSound);
        //llStopSound();
        llLoopSound(gHumSound, humVolume);
        llSetTimerEvent(0.0);
        llMessageLinked(LINK_ALL_CHILDREN, 0, "stop", id);
        llSetLinkPrimitiveParamsFast(LINK_ROOT,
                [PRIM_LINK_TARGET, LINK_ALL_CHILDREN,
                PRIM_PHYSICS_SHAPE_TYPE, PRIM_PHYSICS_SHAPE_PRIM]);
                // deleted PRIM_PHYSICS_SHAPE_TYPE, PRIM_PHYSICS_SHAPE_CONVEX
        llSetStatus(STATUS_PHYSICS, FALSE);
        llSetStatus(STATUS_ROTATE_X | STATUS_ROTATE_Y, FALSE); 
        llSetStatus(STATUS_PHANTOM, TRUE);
        llMoveToTarget(llGetPos(), 0);
        llRotLookAt(llGetRot(), 0, 0);

        llSetSitText("Pilot");

        llSitTarget( <0,0,0> , ZERO_ROTATION );
        llSetCameraEyeOffset( <0,0,0> ); // pilot's view from inside pod
        llSetCameraAtOffset( <0,0,0> );
        
        // mass compensator
        float mass = llGetMass(); // mass of this object
        float gravity = 9.8; // gravity constant
        llSetForce(mass * <0,0,gravity>, FALSE); // in global orientation

        llMessageLinked(LINK_SET, 0, "Power Off", "");
        llMessageLinked(LINK_ALL_CHILDREN, 0, "Open Hatch", "");

        llWhisper(0,"Power-On Self Test Completed");
        state StateListening;
    }
    
} // end default

state StateListening
{
    state_entry()
    {
        llStopSound();
        llLoopSound(gHumSound, humVolume);
        llSetLinkPrimitiveParamsFast(LINK_ROOT,
                [PRIM_PHYSICS_SHAPE_TYPE, PRIM_PHYSICS_SHAPE_PRIM,
                PRIM_LINK_TARGET, LINK_ALL_CHILDREN,
                PRIM_PHYSICS_SHAPE_TYPE, PRIM_PHYSICS_SHAPE_PRIM]);
        llWhisper(0,"Pilot Command Systems Are Ready.");
    } // end state_entry
    
    touch_start(integer total_number) 
    {
        //if (llSameGroup(llDetectedKey(0)))
        //{
            string message = "Select Flight Command";
            list buttons = ["Help"];
            
            if (gPilotHatchState == CLOSED){
                buttons += ["Open Hatch"];
            } else buttons += ["Close Hatch"];
            
            buttons += ["View:Pilot","View:3rd"];
            
            buttons += ["Fly Manual"];      
            buttons += ["Flight Plan"];   
            buttons += ["Report"];   
            
            gMenuChannel = -(integer)llFrand(8999)+1000;
            gMenuListen = llListen(gMenuChannel, "", llDetectedKey(0), "" );
            llDialog(llDetectedKey(0), message, buttons, gMenuChannel);
            llSetTimerEvent(30); 
        //}
        //else
        //{
        //    llSay(0,"((Sorry, you must have your Black Gazza Guard group tag active to use this shuttle.))");
        //}    
    } // end touch_start

    
    listen(integer CHANNEL, string name, key id, string msg)
    {
        llSay(0,"listen "+msg);
        if (msg == "Help") 
        {
            help();
        }
        else if (msg == "View:Pilot") 
        {
            llSetCameraEyeOffset(pilotCamera); // pilot's view from inside pod
            llSetCameraAtOffset(pilotLookAt);
        }
        else if (msg == "View:3rd") 
        {
            llSetCameraEyeOffset(thirdCamera); // up and back 
            llSetCameraAtOffset(thirdLookAt);
        }
        else if (msg == "Report") 
        {
                report();
        }
        else if (msg == "Open Hatch") 
        {
            llMessageLinked(LINK_ALL_CHILDREN, 0, "Open Hatch", "");
        }
        else if (msg == "Close Hatch") 
        {
            llMessageLinked(LINK_ALL_CHILDREN, 0, "Close Hatch", "");
        }
        else if (msg == "Stop") 
        {
            help();
        }
        else if (msg == "Fly Manual") 
        {
            Pilot = id;
            state StateFlying;
        }
        else if (msg == "Flight Plan") 
        {
            automatedFlightPlansMenu(id);
        }
        else if (llSubStringIndex(msg, "Plan") > -1) {
            readFlightPlan((integer)llGetSubString(msg, 5, -1));
        }
        else 
        {
            llMessageLinked(LINK_ALL_CHILDREN, 0, msg, "");
        } 

    } // end listen
    
    link_message(integer sender_num, integer num, string msg, key id) 
    {
        if (msg == "Hatch") {
            if (num == 1) {
                gPilotHatchState = OPEN;
            } else {
                gPilotHatchState = CLOSED;
            }
        }
    } // end link_message
    
    dataserver(key query_id, string data) 
    {
        if (data == EOF) //Reached end of notecard (End Of File).
        {
            
            sayDebug("dataserver got EOF. Frames:"+(string)gNumKeyFrames);
            llWhisper(0,"Closing hatches. Beginning automatic flight mode.");
            llMessageLinked(LINK_ALL_CHILDREN, 0, "Close Hatch", "");
            llSleep(2);
            state AutomatedFlight;
        } else {
            //llWhisper(0,"dataserver '"+data+"'");
            if (query_id == gNotecardQueryId)
            {
                handleDataServer(data);
            }
        }
    }

} // end StateListening

state StateFlying
{

    state_entry()
    {
        llWhisper(0,"Manual Flight ontrols Activated.");
        llStopSound();
        llLoopSound(gHumSound, humVolume);
        llMessageLinked(LINK_SET, 0, "Power On", "");
        llMessageLinked(LINK_ALL_CHILDREN, 0, "Close Hatch", "");
        
        llRequestPermissions(Pilot, PERMISSION_TAKE_CONTROLS);
        llRotLookAt(llGetRot(), ANGULAR_TAU, 1.0);

        llListen(CHANNEL, "", "", "");

        llSetLinkPrimitiveParamsFast(LINK_ROOT,
                [PRIM_PHYSICS_SHAPE_TYPE, PRIM_PHYSICS_SHAPE_PRIM,
                PRIM_LINK_TARGET, LINK_ALL_CHILDREN,
                PRIM_PHYSICS_SHAPE_TYPE, PRIM_PHYSICS_SHAPE_PRIM]);
        llSetStatus(STATUS_PHANTOM, FALSE);
        llSetStatus(STATUS_PHYSICS, TRUE);
        llSetStatus(STATUS_ROTATE_X | STATUS_ROTATE_Y, FALSE); 

        llMoveToTarget(llGetPos(), LINEAR_TAU);

        gLastMessage = llGetTime();
        float mass = llGetMass(); // mass of this object
        float gravity = 9.8; // gravity constant
        llSetForce(mass * <0,0,gravity>, FALSE); // in global orientation
        TARGET_INCREMENT = 0.1;
    } // end state_entry
    
    touch_start(integer total_number)
    {
        if (llSameGroup(llDetectedKey(0)))
        {
            string message = "Select Flight Command";
            list buttons = ["Stop","1%","2%","5%","10%","20%","50%","100%","Report"];
            gMenuChannel = -(integer)llFrand(8999)+1000;
            key avatarKey = llDetectedKey(0);
            gMenuListen = llListen(gMenuChannel, "", avatarKey, "" );
            llDialog(avatarKey, message, buttons, gMenuChannel);
            llSetTimerEvent(30);
        }
        else
        {
            llSay(0,"((Sorry, you must have your Black Gazza Guard group tag active tio use this shuttle.))");
        }    
    } // end touch_start
        
    listen(integer CHANNEL, string name, key id, string msg)
    {
        if (id==Pilot)
        {
            if (msg == "Stop")
            {
                stop();
                state StateListening;
            }
            if (msg == "Report") 
            {
                report();
            }
            if (msg == "1%")
            {
                TARGET_INCREMENT = 0.1;
            }
            if (msg == "2%")
            {
                TARGET_INCREMENT = 0.2;
            }
            if (msg == "5%")
            {
                TARGET_INCREMENT = 0.5;
            }
            if (msg == "10%")
            {
                TARGET_INCREMENT = 1.0;
            }
            if (msg == "20%")
            {
                TARGET_INCREMENT = 2.0;
            }
            if (msg == "50%")
            {
                TARGET_INCREMENT = 5.0;
            }
            if (msg == "100%")
            {
                TARGET_INCREMENT = 10.0;
            }
            
            THETA_INCREMENT = TARGET_INCREMENT;
            
            if (TARGET_INCREMENT > 0) {
                llWhisper(0,"Power: " + llGetSubString((string)(TARGET_INCREMENT * 10.0),0,3) + "%");
            }
        }
    } // end listen

    run_time_permissions(integer perm)
    {
        if (perm == PERMISSION_TAKE_CONTROLS)
        {
            llMessageLinked(LINK_ALL_CHILDREN, 0, "slow", id);
            integer LEVELS = CONTROL_FWD | CONTROL_BACK | CONTROL_ROT_LEFT | CONTROL_ROT_RIGHT | CONTROL_UP | CONTROL_DOWN | CONTROL_LEFT | CONTROL_RIGHT | CONTROL_ML_LBUTTON;
            llTakeControls(LEVELS, TRUE, FALSE);
        }
        else
        {
            llWhisper(0,"Stopped");
            llMessageLinked(LINK_ALL_CHILDREN, 0, "STOP", id);
            llSetTimerEvent(0.0);
            llSleep(1.5);
            state default;
        }
    }
    
    control(key Pilot, integer levels, integer edges)
    {
        pos *= brake;
        face.x *= brake;
        face.z *= brake;
        if (levels & CONTROL_FWD)
        {
            if (pos.x < 0) { pos.x=0; }
            else { pos.x += TARGET_INCREMENT; }
            gNudge = "fwd";
        }
        if (levels & CONTROL_BACK)
        {
            if (pos.x > 0) { pos.x=0; }
            else { pos.x -= TARGET_INCREMENT; }
            gNudge =  "back";
        }
        if (levels & CONTROL_UP)
        {
            if(pos.z<0) { pos.z=0; }
            else { pos.z += TARGET_INCREMENT; }
            face.x=0;
            gNudge = "up";
        }
        if (levels & CONTROL_DOWN)
        {
            if(pos.z>0) { pos.z=0; }
            else { pos.z -= TARGET_INCREMENT; }
            face.x=0;
            gNudge =  "down";
        }
        if ((levels) & (CONTROL_LEFT))
        {
            if (pos.y < 0) { pos.y=0; }
            else { pos.y += TARGET_INCREMENT; }
            gNudge = "LEFT";
        }
        if ((levels) & (CONTROL_RIGHT))
        {
            if (pos.y > 0) { pos.y=0; }
            else { pos.y -= TARGET_INCREMENT; }
            gNudge = "RIGHT";
        }
        if ((levels) & (CONTROL_ROT_LEFT))
        {
            if (face.z < 0) { face.z=0; }
            else { face.z += THETA_INCREMENT; }
            gNudge = "left";
        }
        if ((levels) & (CONTROL_ROT_RIGHT))
        {
            if (face.z > 0) { face.z=0; }
            else { face.z -= THETA_INCREMENT; }
            gNudge = "right";
        }
        if ((levels & CONTROL_UP) && (levels & CONTROL_DOWN))
        {
            if (auto) 
            { 
                auto=FALSE;
                llWhisper(0,"Cruise off"); 
                llSetTimerEvent(0.0);
            }
            else 
            { 
                auto=TRUE; 
                llWhisper(0,"Cruise on");
                llSetTimerEvent(0.5);
            }
            llSleep(0.5); 
        }
        
        if (gNudge != "")
        {
            vector world_target = pos * llGetRot(); 
            llMoveToTarget(llGetPos() + world_target, LINEAR_TAU);
    
            vector eul = face; 
            eul *= DEG_TO_RAD; 
            rotation quat = llEuler2Rot( eul ); 
            rotation rot = quat * llGetRot();
            llRotLookAt(rot, ANGULAR_TAU, ANGULAR_DAMPING);
            
            if (llGetTime() > (gLastMessage + 0.5)) {
                llMessageLinked(LINK_ALL_CHILDREN, (integer)TARGET_INCREMENT, gNudge, id);
                llPlaySound(gSoundgWhiteNoise,TARGET_INCREMENT/10.0);
                gLastMessage = llGetTime();
            }
        }
    }
    
    timer()
    {
        pos *= brake;
        if (pos.x < 0) { pos.x=0; }
        else { pos.x += TARGET_INCREMENT; }
        vector world_target = pos * llGetRot(); 
        llMoveToTarget(llGetPos() + world_target, LINEAR_TAU);
    }
    
    link_message(integer sender_num, integer num, string msg, key id) 
    {
        if (msg == "Hatch") {
            if (num == 1) {
                gPilotHatchState = OPEN;
            } else {
                gPilotHatchState = CLOSED;
            }
        }
    } // end link_message
}

state AutomatedFlight
{
    state_entry()
    {
        sayDebug("AutomatedFlight state_entry");
        llMessageLinked(LINK_SET, 0, "Power On", "");
        llWhisper(0,"Manual control systems deactivated. Flight controls are now automatic.");
        llMessageLinked(LINK_SET, 0, "Power On", "");
        llMessageLinked(LINK_ALL_CHILDREN, 0, "Close Hatch", "");
        
        vector MyPos = llGetPos();
        if (llVecDist(MyPos, gHomePos) > 5)
        {
            llSay(0,"You must be within 5 meters of the starting position to follow an automated flight path.");
            llSay(0,"Please fly manually to "+(string)gHomePos);
            resetFlightPlan();
            state StateListening;
        }
            
        llSetPos(gHomePos);
        llSetRot(gHomeRot);
        
        flyAndRotateToNextPosition();
        llSetTimerEvent(gStepInterval);   
    }
    
    timer()
    {
        if (gFrame < gNumKeyFrames) {
            // automated flight
            flyAndRotateToNextPosition();        
        } else { 
            // finished
            llSetTimerEvent(0);
            llWhisper(0,"Flight Plan Complete. Resetting systems.");
            llSetKeyframedMotion([], [KFM_COMMAND, KFM_CMD_STOP]);
            resetFlightPlan();
            llSetStatus(STATUS_PHYSICS, FALSE);
            llSetStatus(STATUS_PHANTOM, TRUE);
            llSetStatus(STATUS_ROTATE_X | STATUS_ROTATE_Y, FALSE); 
            llMessageLinked(LINK_ALL_CHILDREN, 0, "Open Hatch", "");
            llMessageLinked(LINK_SET, 0, "Power Off", "");
            state default;
        }
    }

    link_message(integer sender_num, integer num, string msg, key id) 
    {
        if (msg == "Hatch") {
            if (num == 1) {
                gPilotHatchState = OPEN;
            } else {
                gPilotHatchState = CLOSED;
            }
        }
    } // end link_message
}
