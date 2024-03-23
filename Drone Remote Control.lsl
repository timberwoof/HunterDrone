integer droneChannel = -4413251;
integer menuChannel;
integer menuListen;
key guardGroupKey = "b3947eb2-4151-bd6d-8c63-da967677bc69";
key inmateGroupKey = "ce9356ec-47b1-5690-d759-04d8c8921476";
key welcomeGroupKey = "49b2eab0-67e6-4d07-8df1-21d3e03069d0";

integer DEBUG=0;
sayDebug(string message){
    if (DEBUG > 0) {
        llOwnerSay(message);
    }
}

default
{
    state_entry()
    {
        llSay(0, "Hello, Avatar!");
    }

    touch_start(integer total_number)
    {
        key target = llDetectedKey(0);
        menuChannel = llFloor(llFrand(10000)+1000);
        menuListen = llListen(menuChannel, "", target, "");
        string text = "Select Command Fucktion "+(string)menuChannel;
        list buttons = ["Report", "Home", "Reset", "Patrol", "Debug OFF", "Debug ON"];
        llSetTimerEvent(30);
        llDialog(target, text, buttons, menuChannel);
    }

    listen(integer channel, string name, key target, string message) {
        string command;
        if (channel == menuChannel){
            sayDebug("listen command:"+message);
            llRegionSay(droneChannel, message);
            llListenRemove(menuListen);
            menuListen = 0;
            menuChannel = 0;
            llSetTimerEvent(1);
        }
    }
}
