string pose = "Misc-Shy-Falling Pneumatic Tube";
key sound = "dd7a57dc-89dc-3584-3c1a-36727424bedf";
particle_scan_on(key target) {
    llLoopSound(sound, 1.0);
llParticleSystem([
PSYS_PART_FLAGS, PSYS_PART_TARGET_POS_MASK | PSYS_PART_FOLLOW_SRC_MASK | PSYS_PART_EMISSIVE_MASK | PSYS_PART_INTERP_SCALE_MASK | PSYS_PART_INTERP_COLOR_MASK,
PSYS_SRC_PATTERN, 4, 
PSYS_PART_START_ALPHA, 0.5,
PSYS_PART_END_ALPHA, 0.5,
PSYS_PART_START_COLOR, <0.0, 1.0, 0.0>,
PSYS_PART_END_COLOR, <0.5, 1.0, 0.0>,
PSYS_PART_START_SCALE, <0.5, 0.5, 0.0>,
PSYS_PART_END_SCALE, <0.5, 0.5, 0.0>,
PSYS_PART_MAX_AGE, 2.0,
PSYS_SRC_MAX_AGE, 0.0,
PSYS_SRC_ACCEL, <0.0, 0.0, -12.0>,
PSYS_SRC_ANGLE_BEGIN, 4.0,
PSYS_SRC_ANGLE_END, 5,
PSYS_SRC_BURST_PART_COUNT, 10,
PSYS_SRC_BURST_RATE, 0.1,
PSYS_SRC_BURST_RADIUS, 0.0,
PSYS_SRC_BURST_SPEED_MIN, 2.0,
PSYS_SRC_BURST_SPEED_MAX, 3.0,
PSYS_SRC_OMEGA, <0.0, 0.0, 30.0>,
PSYS_SRC_TARGET_KEY,llGetKey(), 
PSYS_SRC_TEXTURE, ""]);

}

particle_scan_off() {
    llParticleSystem([]);
    llStopSound();
}
// Stop all animations
stop_anims(key agent)
{
    list l = llGetAnimationList(agent);
    integer lsize = llGetListLength(l);
    integer i;
    for (i = 0; i < lsize; i++)
    {
        llStopAnimation(llList2Key(l, i));
    }
}

// ===================================================================================
default
{
    on_rez (integer param)
    {
       llResetScript();
    }

    state_entry() 
    {
        llSetText("",<0,0,0>,0);
        llSetSitText("Transport");
        llSitTarget(<0.0, 0.0, -2.0> , ZERO_ROTATION);
        particle_scan_off();
    }

    run_time_permissions(integer permissions)
    {
        if (permissions & PERMISSION_TRIGGER_ANIMATION)
        {
            key agent = llGetPermissionsKey();
            if (llGetAgentSize(agent) != ZERO_VECTOR)
            { // agent is still in the sim.
                // Sit the agent
                stop_anims(agent);
                particle_scan_on(agent);
                llStartAnimation(pose);
            }
        }
        else
        {
            llResetScript();
        }
    }

    changed(integer change){
        if (change & CHANGED_LINK) {
            key agent = llAvatarOnSitTarget();
            if (agent) {
                llRequestPermissions(agent, PERMISSION_TRIGGER_ANIMATION);
            } else {    // Stood up (or maybe crashed!)
                // Get agent to whom permissions were granted
                agent = llGetPermissionsKey();
                if (llGetAgentSize(agent) != ZERO_VECTOR) {
                    // agent is still in the sim.
                    if (llGetPermissions() & PERMISSION_TRIGGER_ANIMATION) {
                        // Only stop anis if permission was granted previously.
                        stop_anims(agent);
                        particle_scan_off();
                    }
                    llResetScript();
                }
            }
        }
    }    
}
