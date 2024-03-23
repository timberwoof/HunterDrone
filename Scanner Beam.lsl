particle_scan_on(key target) {
llLoopSound("f5ae60d2-9f03-984a-e846-d5f499b64e17",1);
llParticleSystem([
            PSYS_PART_FLAGS, PSYS_PART_EMISSIVE_MASK |
                PSYS_PART_INTERP_COLOR_MASK | 
                PSYS_PART_INTERP_SCALE_MASK | 
                PSYS_PART_FOLLOW_SRC_MASK | 
                PSYS_PART_FOLLOW_VELOCITY_MASK |
                PSYS_PART_TARGET_POS_MASK | 
                PSYS_PART_TARGET_LINEAR_MASK,
             PSYS_SRC_PATTERN, PSYS_SRC_PATTERN_ANGLE_CONE_EMPTY,
             PSYS_PART_START_ALPHA, 0.7,
             PSYS_PART_END_ALPHA, 0.2,
             PSYS_PART_START_COLOR, <0,0.5,1>,
             PSYS_PART_END_COLOR, <0,1,1>,
             PSYS_PART_START_SCALE, <0,0,0>,
             PSYS_PART_END_SCALE, <2,2,2>, 
             PSYS_PART_MAX_AGE,1,
             PSYS_SRC_BURST_RATE, 0.1,
             PSYS_SRC_ACCEL, <0,0,0>,
             PSYS_SRC_BURST_PART_COUNT, 4,
             PSYS_SRC_BURST_RADIUS, 0.1,
             PSYS_SRC_BURST_SPEED_MIN, 1,
             PSYS_SRC_BURST_SPEED_MAX, 1,
             PSYS_SRC_TARGET_KEY, target,
             PSYS_SRC_ANGLE_BEGIN, 1.54, 
             PSYS_SRC_ANGLE_END, 1.55,
             PSYS_SRC_OMEGA, <0,0,2>,
             PSYS_SRC_MAX_AGE, 0,
             PSYS_SRC_TEXTURE, "e5f8a843-044d-a906-225c-aa26ceffad50"
        ]);    
}

particle_scan_off() {
    llParticleSystem([]);
    llStopSound();
}



default 
{
    state_entry()
    {
        particle_scan_off();
    }
    
    on_rez(integer parameter) {
        particle_scan_off();
    }

    link_message(integer sender_num, integer num, string message, key target) {
        if (message == "Power On") {
            particle_scan_off();
        } else if (message == "SCAN_START") {
            particle_scan_on(target);
        } else if (message == "SCAN_STOP") {
            particle_scan_off();
        } else if (message == "RESET") {
            particle_scan_off();
            llResetScript();
        }
    }
    
}

