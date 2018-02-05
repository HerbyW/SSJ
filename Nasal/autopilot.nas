## Jump to next waypoint earlier
#
#  frank-deng committed on 22 Nov 
#
var next_waypoint = func {
	if ("LNAV" == getprop("/instrumentation/afds/ap-modes/roll-mode")
		and getprop("/autopilot/route-manager/active")) {

		var max_wpt=getprop("/autopilot/route-manager/route/num");
		var atm_wpt=getprop("/autopilot/route-manager/current-wp");
		var eta_seconds = getprop("/autopilot/route-manager/wp/eta-seconds");
		var wp_dist = getprop("/autopilot/route-manager/wp/dist");

		if (eta_seconds != nil and wp_dist != nil
			and eta_seconds < 39 and wp_dist < 30) {

			if (getprop("/autopilot/route-manager/current-wp")<=max_wpt){
				atm_wpt+=1;
				setprop("/autopilot/route-manager/current-wp", atm_wpt);
			}

		}

	}

	settimer(next_waypoint, 0);
}
settimer(next_waypoint, 0);
