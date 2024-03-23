// BG Controller for ~Isil~ Mobile Holding Cell
list playerKeys;
list playerCountdowns;
list playerNames;
integer DoorLink = 3;
integer DoorClosed;
integer MenuListener;
integer normalTime = 600; // seconds
integer timerInterval = 30; // seconds 
integer DEBUG = FALSE;
integer droneChannel = -4413251; // also for dialogs to keep things simple
integer RLVRelayChannel = -1812221819;

string BEEPS = "a4a9945e-8f73-58b8-8680-50cd460a3f46";

sayDebug(string message) {
    if (DEBUG) {
        llSay(0,message);
    }
}

ResetDoor() {  // door;<-1.80190, 0.00000, -0.02830>;<0.00000, 0.00000, 0.00000, 1.00000>;<0.21159, 1.68026, 2.53878>
    DoorClosed = TRUE;
    OpenDoor();
}

OpenDoor() {
    if (DoorClosed) {
        vector Size = llGetScale(); // <4.11480, 4.76610, 3.60009>
        float Scale = 4.11480 / Size.x; 
        llSetLinkPrimitiveParamsFast(DoorLink, [PRIM_POS_LOCAL, <-0.96349 * Scale, 0.87683 * Scale, -0.02832 * Scale>,
                                                PRIM_ROT_LOCAL, <0.00000, 0.00000, 0.77301, 0.63439>]);
        DoorClosed = FALSE;
    }
}

CloseDoor() {
    if (!DoorClosed) {
        vector Size = llGetScale(); // <4.11480, 4.76610, 3.60009>
        float Scale = 4.11480 / Size.x; 
        llSetLinkPrimitiveParamsFast(DoorLink, [PRIM_POS_LOCAL, <-1.80190 * Scale, 0.00000, -0.02830 * Scale>,
                                                PRIM_ROT_LOCAL, <0.00000, 0.00000, 0.00000, 1.00000>]);
        DoorClosed = TRUE;
    }
}


AddPlayer(key id, integer time) {
    sayDebug("AddPlayer");
    // adds player's ID and interval to the lists. 
    if(llListFindList(playerKeys, [id]) == -1) {
        playerKeys += [id];
        playerCountdowns += [time]; // convert time in minutes to intervals
        playerNames += [llGetDisplayName(id)];
        llSay(RLVRelayChannel, "BGCell," + (string)id + ",@tploc=n|@tplm=n|@tplure=n|@sittp=n|@standtp=n");
    }
    llSetTimerEvent(timerInterval);  // 30 seconds for reasonably fine release timing
}

RemovePlayer(key id) {
    sayDebug("RemovePlayer");
    // remove player form the lists and remove RLV restrictions
    integer index = llListFindList(playerKeys, [id]);
    if(index != -1) {
        playerKeys = llDeleteSubList(playerKeys, index, index);
        playerCountdowns = llDeleteSubList(playerCountdowns, index, index);
        playerNames = llDeleteSubList(playerNames, index, index);
        llSay(RLVRelayChannel, "BGCell," + (string)id + ",!release");
        llSay(RLVRelayChannel, "BGCell," + (string)id + ",@unsit=force");
    }
}

sitEverybody() {
    sayDebug("sitEverybody");
    integer i;
    for (i = 0; i < llGetListLength(playerKeys); i = i + 1) {
        key id = llList2Key(playerKeys, i);
        llSay(RLVRelayChannel, "BGCell," + (string)id + ",@sitground=force");
        llSleep(1);
        llSay(RLVRelayChannel, "BGCell," + (string)id + ",@unsit=n");
    }
}

unsitEverybody() {
    sayDebug("unsitEverybody");
    integer i;
    for (i = 0; i < llGetListLength(playerKeys); i = i + 1) {
        key id = llList2Key(playerKeys, i);
        llSay(RLVRelayChannel, "BGCell," + (string)id + ",@unsit=y");
        llSleep(1);
        llSay(RLVRelayChannel, "BGCell," + (string)id + ",@unsit=force");
    }
}

removeAllPlayers() {
    sayDebug("removeAllPlayers");
    integer i;
    for (i = 0; i < llGetListLength(playerKeys); i = i + 1) {
        key id = llList2Key(playerKeys, i);
        RemovePlayer(id);
    }
}

integer IsInside(key id) {
    vector PlayerPos = (vector)llList2String(llGetObjectDetails(id, [OBJECT_POS]), 0);
    if(PlayerPos == ZERO_VECTOR) return FALSE;
    
    vector Difference = (PlayerPos - llGetPos()) / llGetRot();
    vector Scale = llGetScale();
    
    if( (llFabs(Difference.x) < Scale.x * 0.45) && 
        (llFabs(Difference.y) < Scale.y * 0.45) && 
        (llFabs(Difference.z) < Scale.z * 0.45) ) {
        return 1;
    }
    return 0;
}

letOnePlayerOut(integer i) {
    key id = llList2Key(playerKeys, i);
    string name = llList2String(playerNames, i);
    if ((id != NULL_KEY) && (name != "")) {
        llPlaySound(BEEPS, 1);
        llSay(0, "Stand clear of the door.");
        llSay(0, name + ", you are free to go. For now.");    
        RemovePlayer(id);
        sitEverybody();                
        OpenDoor();
        llSleep(10);
        CloseDoor();
        unsitEverybody();
        
        playerKeys = llListReplaceList(playerKeys, [], i, i);
        playerCountdowns = llListReplaceList(playerCountdowns, [], i, i);
        playerNames = llListReplaceList(playerNames, [], i, i);
    }
}

stop_anims(key id)
{
    list    l = llGetAnimationList(id);
    integer    lsize = llGetListLength(l);
    integer i;
    for (i = 0; i <lsize; i++)
    {
        llStopAnimation(llList2Key(l, i));
    }
}

announceMyself() {
    llRegionSay(droneChannel,"HOLDING"+(string)llGetPos());
}

default
{
    on_rez (integer param)
    {
        llResetScript();
    }

    state_entry() 
    {
        llVolumeDetect(FALSE);
        llSetSitText("Holding");
        llSitTarget(<0.0, 0.0, -1.0> , llEuler2Rot(<0,0,180>*DEG_TO_RAD));        
        ResetDoor();
        MenuListener = llListen(droneChannel, "", NULL_KEY, "");
        //announceMyself(); do this if we need more cells
        llSensor("", NULL_KEY, AGENT, 3, PI);
    }

    changed(integer change) 
    {
        sayDebug("changed");
        if (change & CHANGED_LINK)
        {
            // If someone sat down, stand them up and apply RLV restrictions
            key id = llAvatarOnSitTarget();
            if (id) {
                CloseDoor();
                llUnSit(id);
                AddPlayer(id, normalTime);
            }
        }
    }

    touch_start(integer num_detected) {
        sayDebug("touch");
        key id = llDetectedKey(0);
        if (llSameGroup(id) || (llGetOwnerKey(llGetKey()) == id)) {
            integer i = llListFindList(playerKeys, [id]);
            if (i > -1) {
                sayDebug("letting guard or owner out");
                letOnePlayerOut(i);
            } else {
                string message = "BG Airport Holding Cell";
                list buttons = [];
                if (DoorClosed) {
                    buttons = buttons + ["Open"];
                } else {
                    buttons = buttons + ["Close"];
                }
                llDialog(id, message, buttons, droneChannel);
            }
        }
    }

    listen(integer channel, string name, key id, string message) {
        if(message == "Open") {
            OpenDoor();
            removeAllPlayers();
        } else if(message == "Close") {
            CloseDoor();
        } else if(message == "OPENCELL") {
            sitEverybody();
            OpenDoor();
        } else if(message == "CLOSECELL") {
            CloseDoor();
            unsitEverybody();
        } else if(message == "ANNOUNCECELL") {
            announceMyself();
        }
    }

    timer() {
        sayDebug("timer");        
        integer i;
        integer numinside =  llGetListLength(playerCountdowns);
        if (numinside > 0) {
            for (i = 0; i < numinside; i = i + 1) {
                // decrement everybodys time
                integer time = llList2Integer(playerCountdowns, i);
                if (time > 0) {
                    time = time - timerInterval; 
                    playerCountdowns = llListReplaceList(playerCountdowns, [time], i, i);
                } else if (time <= 0) {
                    letOnePlayerOut(i);
                }
            }
        } else {
            llSetTimerEvent(0);
        }
    }
    
    sensor(integer num_detected) {
        // This only happens at startup as a failsafe. 
        sayDebug("releasing from sensor");
        integer i;
        for (i = 0; i < num_detected; i = i + 1)  {
            key id = llDetectedKey(i);
            llSay(RLVRelayChannel, "BGCell," + (string)id + ",!release");
        }
    }
}
