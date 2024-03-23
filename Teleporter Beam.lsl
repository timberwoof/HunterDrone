teleporter_beam_on(key target) {
    llPlaySound("0a265d7c-837d-0025-2417-7e379cf4ea76",1);
    llParticleSystem([
            PSYS_PART_FLAGS, PSYS_PART_EMISSIVE_MASK | PSYS_PART_INTERP_COLOR_MASK,
            PSYS_SRC_PATTERN, PSYS_SRC_PATTERN_ANGLE_CONE,
            PSYS_SRC_ANGLE_BEGIN, PI_BY_TWO,
            PSYS_SRC_ANGLE_END, PI_BY_TWO,
            PSYS_PART_START_COLOR, <0.0, 1.0, 0.0>,
            PSYS_PART_END_COLOR, <1.0, 0.0, 0.0>,
            PSYS_PART_START_ALPHA, 0.75,
            PSYS_PART_END_ALPHA, 0.75,
            PSYS_PART_START_SCALE, <0.5, 2.0, 0.0>,
            PSYS_PART_END_SCALE, <0.5, 2.0, 0.0>,
            PSYS_PART_MAX_AGE, 2,
            PSYS_SRC_ACCEL, <0.0, 0.0, -2.0>,
            PSYS_SRC_BURST_RATE, 0.1,
            PSYS_SRC_BURST_PART_COUNT, 8,
            PSYS_SRC_BURST_RADIUS, 0.5,
            PSYS_SRC_BURST_SPEED_MIN, 0.1,
            PSYS_SRC_BURST_SPEED_MAX, 0.1]);   
}

teleporter_beam_off() {
    llParticleSystem([]);
    llStopSound();
}



default 
{
    state_entry()
    {
        teleporter_beam_off();
    }
    
    on_rez(integer parameter) {
        teleporter_beam_off();
    }

    link_message(integer sender_num, integer num, string message, key target) {
        if (message == "Power On") {
            teleporter_beam_off();
        } else if (message == "BEAM_START") {
            teleporter_beam_on(target);
        } else if (message == "BEAM_STOP") {
            teleporter_beam_off();
        } else if (message == "RESET") {
            teleporter_beam_off();
            llResetScript();
        }
    }
    
}

