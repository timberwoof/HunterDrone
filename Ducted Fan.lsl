key jet_loop = "a6fede89-6bc5-76cc-bd3a-01ef326ea239";
key jet_start = "1e6e6eec-737b-0bf7-25a1-9e6e4e2f7580";
key jet_loop_fade = "41bcdb2a-d789-13f9-cb7f-0c5d05d8b5dd";
integer powerOn = FALSE;

off() {
    if (powerOn) {
        llPlaySound(jet_loop_fade,1);
        llStopSound();
    }
    llParticleSystem([]);
    llSetTextureAnim(FALSE, ALL_SIDES, 0, 0, 0, 0, 0);
    powerOn = FALSE;
}

on() {
    if (!powerOn) {
        llPlaySound(jet_start,0.1);
        llSleep(5);
        llLoopSound(jet_loop,.1);

        llSetTextureAnim(ANIM_ON | SMOOTH | ROTATE | LOOP, ALL_SIDES,1,1,0, TWO_PI,-12);
        llParticleSystem([
PSYS_PART_FLAGS, 3,
PSYS_SRC_PATTERN, 8, 
PSYS_PART_START_ALPHA, 0.02,
PSYS_PART_END_ALPHA, 0.00,
PSYS_PART_START_COLOR, <1.0, 1.0, 1.0>,
PSYS_PART_END_COLOR, <1.0, 1.0, 1.0>,
PSYS_PART_START_SCALE, <0.80, 0.80, 0.0>,
PSYS_PART_END_SCALE, <1.80, 1.80, 0.0>,
PSYS_PART_MAX_AGE, 0.50,
PSYS_SRC_MAX_AGE, 0.0,
PSYS_SRC_ACCEL, <0.0, 0.0, 3.0>,
PSYS_SRC_ANGLE_BEGIN, 3.0, // 0.785398,
PSYS_SRC_ANGLE_END, 3.0, // 2.356194,
PSYS_SRC_BURST_PART_COUNT, 1,
PSYS_SRC_BURST_RATE, 0.0,
PSYS_SRC_BURST_RADIUS, 0.0,
PSYS_SRC_BURST_SPEED_MIN, 5.0,
PSYS_SRC_BURST_SPEED_MAX, 10.0,
PSYS_SRC_OMEGA, <0.0, 0.0, 0.0>,
PSYS_SRC_TARGET_KEY,(key)"", 
PSYS_SRC_TEXTURE, "d1df5743-efa9-8fab-0d2f-8c206931299b"]);
        llLoopSound(jet_loop,0.01);
        powerOn = TRUE;
    }
}

default
{
    state_entry()
    {
        off();
    }
    

    link_message(integer Sender, integer Number, string message, key Key)
    {
        if (message == "Power On") {
            on();
        } else if (message == "Power Off") {
            off();
        } else if (message == "RESET") {
            llStopSound();
            powerOn = FALSE;
            llParticleSystem([]);
            llResetScript();
        }
    }
}
