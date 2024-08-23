#!/usr/bin/awk -f
#
# Place it in the top-directory of the SD-Card with the name timelapse_hook.sh.
#
# This script is for taking a timelapse of the geocentric constellations in AtomSwing.
# 1. Set the camera directly above (pan=0 dgree, tilt=180 dgree).
# 2. Move the camera mount to align the camera centre with the Polaris.
# 3. Set the value of tiltAngle to the appropriate angle. Take into account that the pan will rotate with time.
# 4. Set timelapse to start at 18:00, with 720 times in 60-second cycles.
# 5. The next morning, the constellations stand still and the ground rotates, creating a time-lapse video.

BEGIN {

  # Angle from the Polaris
  tiltAngle = 15;

  # Angles at Midnight 00:00-JST.
  # ex. timellapse range 18:00 - 06:00 -> 180 dgree at 00:00-JST.
  anglesAtMidnight = 180;

  # Normally, NORTH as it is aligned with the Polaris.
  # If you want to take a time-lapse video of the southern sky, specify SOUTH.
  # This is related to the direction of rotation of the pan.
  direction = "NORTH"; # NORTH or SOUTH

  # Allows time-lapse videos of cloud movement to be taken during the day.
  daytimePanAngle = 0;
  daytimeTiltAngle = 10;

  # The following remain unchanged.
  secondsOfsiderealDay = 365.2422 / 366.2422 * 24 * 60 * 60;
  timeOffset = anglesAtMidnight * secondsOfsiderealDay / 360;
  "date +%s" | getline GMT;
  JST = GMT + 9 * 60 * 60;

  if(((JST % 86400) >= 8 * 60 * 60) && ((JST % 86400) < 18 * 60 * 60)) {
    cmd = sprintf("/scripts/cmd move %3.3f %d 1 0", daytimePanAngle, 180 - daytimeTiltAngle);
    if((ARGC >=2) && (ARGV[2] == "start")) {
      cmd | getline res;
      sleep 3;
      print "start: " >> "/tmp/log/timelapse_hook.log";
      print cmd >> "/tmp/log/timelapse_hook.log";
      print res >> "/tmp/log/timelapse_hook.log";
    }
    cmd | getline res;
    print cmd >> "/tmp/log/timelapse_hook.log";
    print res >> "/tmp/log/timelapse_hook.log";
  } else {
    dir = 1;
    if(direction == "SOUTH") dir = -1;
    pan = (720 + dir * 360 * ((JST - timeOffset) % 86400) / secondsOfsiderealDay) % 360;
    if(pan < 0) pan = 0;
    if(pan > 355) pan = 355;

    # "/scripts/cmd move 0 0 9 1" | getline res;
    "/scripts/cmd move 355 180 9 1" | getline res;
    cmd = sprintf("/scripts/cmd move %3.3f %d 3 0", pan, 180 - tiltAngle);
    if((ARGC >=2) && (ARGV[2] == "start")) {
      cmd | getline res;
      sleep 3;
      print "start: " >> "/tmp/log/timelapse_hook.log";
      print cmd >> "/tmp/log/timelapse_hook.log";
      print res >> "/tmp/log/timelapse_hook.log";
    }
    for(i = 0; i < 3; i++) {
      cmd | getline res;
      print cmd >> "/tmp/log/timelapse_hook.log";
      print res >> "/tmp/log/timelapse_hook.log";
      if(res != "" && index(res, "error") == 0) break;
    }
  }
}
