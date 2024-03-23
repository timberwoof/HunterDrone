float range = 10;

GooOn(key target, float range){
    float speed_min = 10.0; // m/sec min
    float speed_max = speed_min * 1.25;
    float time = range / speed_min + 0.3;
    float angle = llAtan2(1.5, range);
    llLoopSound("256d1401-e3e9-d460-50e4-585eab35c528",1.0);
    llParticleSystem([
PSYS_PART_FLAGS, PSYS_PART_EMISSIVE_MASK | PSYS_PART_FOLLOW_SRC_MASK | PSYS_PART_INTERP_SCALE_MASK,
PSYS_SRC_PATTERN, PSYS_SRC_PATTERN_ANGLE_CONE, 
PSYS_PART_START_ALPHA, 1.0,
PSYS_PART_END_ALPHA, 0.0,
PSYS_PART_START_COLOR, <0.1, 0.1, 0.1>,
PSYS_PART_START_SCALE, <0.05, 0.05, 0.0>,
PSYS_PART_END_SCALE, <2.00, 2.00, 0.0>,
PSYS_PART_MAX_AGE, time,
PSYS_SRC_MAX_AGE, 0.0,
PSYS_SRC_ACCEL, <0.0, 0.0, 0.0>,
PSYS_SRC_ANGLE_BEGIN, 0.0,
PSYS_SRC_ANGLE_END, angle,
PSYS_SRC_BURST_PART_COUNT, 20,
PSYS_SRC_BURST_RATE, 0.0,
PSYS_SRC_BURST_RADIUS, 0.0,
PSYS_SRC_BURST_SPEED_MIN, speed_min,
PSYS_SRC_BURST_SPEED_MAX, speed_max,
PSYS_SRC_OMEGA, <0.0, 0.0, 0.0>,
PSYS_SRC_TARGET_KEY, target, 
PSYS_SRC_TEXTURE, "2d0b4080-3acb-e9dd-a7c2-81efe402521a"]);
}

GooOff() {
    llParticleSystem([]);
    llStopSound();
}

default
{
    state_entry()
    {
        GooOff();
        rotation myRot = llGetRot();
        vector myEuler = llRot2Euler(myRot)*RAD_TO_DEG;
        llSetLocalRot(llEuler2Rot(<180, 90, 0> * DEG_TO_RAD));
    }

    touch_start(integer total_number)
    {
        GooOn(llDetectedKey(0), 10);
        llSetTimerEvent(2.0);
        GooOff();
    }
    
    link_message(integer sender_num, integer num, string message, key id) {
        if (message == "Power On") {
            GooOff();
        } else if (message == "RESET") {
            GooOff();
            llResetScript();
        } else if (message == "GOO_RANGE") {
            range = num;
        } else if (message == "GOO_ANGLE") {
            llSetLocalRot(llEuler2Rot(<180, 180 - num, 0> * DEG_TO_RAD));
        } else if (message == "GOO_SHOOT") {
            GooOn(id, range);
        } else if (message == "GOO_STOP") {
            GooOff();
        }
    }

    timer() 
    {
        GooOff();
        llSetTimerEvent(0.0);
    }
}
