off() {
    llSetTextureAnim(FALSE, ALL_SIDES, 0, 0, 0, 0, 0);
}

on() {
    integer mode = ANIM_ON | SMOOTH | LOOP | PING_PONG; // PING_PONG doesn't work?
    integer face = ALL_SIDES;
    integer sizex = 1;
    integer sizey = 1;
    float start = 0.0;
    float length = 1.0;
    float rate = 1.0;
    llSetTextureAnim(mode, face, sizex, sizey, start, TWO_PI, rate);
    //llSetTextureAnim(ANIM_ON | LOOP | SMOOTH | PING_PONG, FACE1, 1, 1, 1.0, 1.0, 1.0);
}

default
{
    state_entry()
    {
        on();
    }
    

    link_message(integer Sender, integer Number, string message, key Key)
    {
        if (message == "Power On") {
            on();
        } else if (message == "Power Off") {
            off();
        } else if (message == "RESET") {
            off();
            llResetScript();
        }
    }
}
