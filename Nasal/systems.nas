# SSJ systems


var gsnull = maketimer (2, func {

if(getprop("/instrumentation/afds/ap-modes/pitch-mode") != "G/S")
setprop("/instrumentation/nav[0]/gs-rate-of-climb", 0);
});
gsnull.start();

#

 var setbank = maketimer (0.33, func {
    var banklimit= getprop("instrumentation/afds/inputs/bank-limit-switch");
    if(banklimit == 0)
    {
	trueSpeedKts = getprop("/instrumentation/airspeed-indicator/true-speed-kt");
	if (trueSpeedKts > 400) 
	{
		setprop("/instrumentation/afds/settings/bank-max", 15);
		setprop("/instrumentation/afds/settings/bank-min", -15);
	} else if (trueSpeedKts > 320)
	{
		setprop("/instrumentation/afds/settings/bank-max", 20);
		setprop("/instrumentation/afds/settings/bank-min", -20);
	} else {
		setprop("/instrumentation/afds/settings/bank-max", 25);
		setprop("/instrumentation/afds/settings/bank-min", -25);
	}
	}
	});
	
setbank.start();

###

# Flaps and Slats Control with speed limits
# prevent demage of flaps due to speed

setlistener("/controls/flight/flaps", func
 { 
 setprop("/controls/flight/slats", getprop("/controls/flight/flaps"));
 if ((getprop("/controls/flight/flaps") > 0  ) and (getprop("/instrumentation/airspeed-indicator/indicated-speed-kt") > 240  ))
  {
    setprop("/controls/flight/flaps", 0);
    setprop("/controls/flight/slats", 0);
    setprop("/sim/flaps/current-setting", 0);
    setprop("/sim/messages/copilot", "Do you want to destroy the flaps due to overspeed (max 240)????");    
  }  
});

##############
# wheels roll effect in air

var rollspeed = maketimer (0.1, func
  {    
   if (getprop("/gear/gear/position-norm") ==nil) return;
   if (getprop("/position/gear-agl-ft") ==nil) return;
            
    if ((getprop("/position/gear-agl-ft") > 0.5) and (getprop("/gear/gear/position-norm") > 0.9))
    {
      setprop("/controls/gear/roll", getprop("/velocities/airspeed-kt") / 70);
    }
      else
      {
      setprop("/controls/gear/roll", getprop("/gear/gear[1]/rollspeed-ms"));
      }
});

rollspeed.start();
##############

# runway effect


setprop("/controls/gear/runway", 0);

setlistener("/gear/gear[1]/wow", func
{
  if (getprop("/gear/gear[1]/wow") == 0)
    interpolate("/controls/gear/runway", 0 , 0.1);
  else
  {
  if ( ( getprop("/gear/gear[1]/compression-norm") > 0.20 ) and ( getprop("/gear/gear[1]/rollspeed-ms") > 60)  and ( getprop("/velocities/speed-down-fps") > 2))
    interpolate("/controls/gear/runway", 1 , 0.3, 0 , 0.3);
  }
}
);

setlistener("/controls/gear/brake-parking", func
{
  if (getprop("/controls/gear/brake-parking") == 0)
    interpolate("/controls/gear/runway", 0 , 0.1);
  else
  {
  if ( ( getprop("/controls/gear/brake-parking") == 1 ) and ( getprop("/gear/gear[1]/rollspeed-ms") > 30) )
    interpolate("/controls/gear/runway", 1 , 1.2, 0 , 1.2);
  }
}
);

##########


var iasmach = maketimer (0.1, func {
    
    if (getprop("/instrumentation/afds/inputs/ias-mach-selected") == 0)
    {
      setprop("/instrumentation/afds/inputs/speed-src",getprop("/autopilot/settings/target-speed-kt"));
    }
      else
      {
      setprop("/instrumentation/afds/inputs/speed-src",getprop("/autopilot/settings/target-speed-mach")*300);
      }
});

iasmach.start();

####################################################################################################

var SndOut = props.globals.getNode("/sim/sound/Ovolume",1);
var FHmeter = aircraft.timer.new("/instrumentation/clock/flight-meter-sec", 10).stop();
var fuel_density =0;
aircraft.livery.init("Aircraft/SSJ/Models/Liveries");

#EFIS specific class
# ie: var efis = EFIS.new("instrumentation/efis");
var EFIS = {
    new : func(prop1){
        var m = { parents : [EFIS]};
        m.mfd_mode_list=["APP","VOR","MAP","PLAN"];

        m.efis = props.globals.initNode(prop1);
        m.mfd = m.efis.initNode("mfd");
        m.pfd = m.efis.initNode("pfd");
        m.eicas = m.efis.initNode("eicas");
        m.mfd_mode_num = m.mfd.initNode("mode-num",2,"INT");
        m.mfd_display_mode = m.mfd.initNode("display-mode",m.mfd_mode_list[2]);
        m.std_mode = m.efis.initNode("inputs/setting-std",0,"BOOL");
        m.previous_set = m.efis.initNode("inhg-previous",29.92);
        m.kpa_mode = m.efis.initNode("inputs/kpa-mode",0,"BOOL");
        m.kpa_output = m.efis.initNode("inhg-kpa",29.92);
        m.kpa_prevoutput = m.efis.initNode("inhg-kpa-previous",29.92);
        m.temp = m.efis.initNode("fixed-temp",0);
        m.alt_meters = m.efis.initNode("inputs/alt-meters",0,"BOOL");
        m.fpv = m.efis.initNode("inputs/fpv",0,"BOOL");
        m.nd_centered = m.efis.initNode("inputs/nd-centered",0,"BOOL");

        m.mins_mode = m.efis.initNode("inputs/minimums-mode",0,"BOOL");
        m.mins_mode_txt = m.efis.initNode("minimums-mode-text","RADIO","STRING");
        m.minimums = m.efis.initNode("minimums",250,"INT");
        m.minimums_baro= m.efis.initNode("minimums-baro",250,"INT");
        m.minimums_radio= m.efis.initNode("minimums-radio",250,"INT");
        m.mk_minimums = props.globals.getNode("instrumentation/mk-viii/inputs/arinc429/decision-height");
        m.tfc = m.efis.initNode("inputs/tfc",0,"BOOL");
        m.wxr = m.efis.initNode("inputs/wxr",0,"BOOL");
        m.range = m.efis.initNode("inputs/range-nm",0);
        m.sta = m.efis.initNode("inputs/sta",0,"BOOL");
        m.wpt = m.efis.initNode("inputs/wpt",0,"BOOL");
        m.arpt = m.efis.initNode("inputs/arpt",0,"BOOL");
        m.data = m.efis.initNode("inputs/data",0,"BOOL");
        m.pos = m.efis.initNode("inputs/pos",0,"BOOL");
        m.terr = m.efis.initNode("inputs/terr",0,"BOOL");
        m.rh_vor_adf = m.efis.initNode("inputs/rh-vor-adf",0,"INT");
        m.lh_vor_adf = m.efis.initNode("inputs/lh-vor-adf",0,"INT");
        m.nd_plan_wpt = m.efis.initNode("inputs/plan-wpt-index", 0, "INT");

        m.wptIndexL = setlistener("instrumentation/efis/inputs/plan-wpt-index", func m.update_nd_plan_center());

        m.kpaL = setlistener("instrumentation/altimeter/setting-inhg", func m.calc_kpa());

        m.eicas_msg_alert   = m.eicas.initNode("msg/alert"," ","STRING");
        m.eicas_msg_caution = m.eicas.initNode("msg/caution"," ","STRING");
		m.eicas_msg_advisory = m.eicas.initNode("msg/advisory"," ","STRING");
        m.eicas_msg_info    = m.eicas.initNode("msg/info"," ","STRING");
        m.update_radar_font();
        m.update_nd_center();
        setprop("instrumentation/transponder/mode-switch",0);
        setprop("controls/lighting/overhead-intencity",0.5);
        setprop("controls/lighting/CB-intencity",0.5);
        setprop("controls/lighting/panel-flood-intencity",0.5);
        setprop("controls/lighting/dome-intencity",0.5);
        return m;
    },
#### convert inhg to kpa ####
    calc_kpa : func{
        var kp = getprop("instrumentation/altimeter/setting-inhg");
        kp = kp * 33.8637526;
        me.kpa_output.setValue(kp);
        kp = getprop("instrumentation/efis/inhg-previous");
        kp = kp * 33.8637526;
        me.kpa_prevoutput.setValue(kp);
        },
#### update temperature display ####
    update_temp : func{
        var tmp = getprop("/environment/temperature-degc");
        if(tmp < 0.00){
            tmp = -1 * tmp;
        }
        me.temp.setValue(tmp);
    },
######### Controller buttons ##########
    ctl_func : func(md,val){
        controls.click(3);
        if(md=="range")
        {
            var rng = me.range.getValue();
            if(val ==1){
                rng =rng * 2;
                if(rng > 640) rng = 640;
            }elsif(val =-1){
                rng =rng / 2;
                if(rng < 10) rng = 10;
            }
            me.range.setValue(rng);
        }
        elsif(md=="dh")
        {
            if(me.mins_mode.getValue())
            {
                if(val==0)
                {
                    num=250;
                }
                else
                {
                    num = me.minimums_baro.getValue();
                    num+=val;
                    if(num<0)num=0;
                    if(num>12000)num=12000;
                }
                me.minimums_baro.setValue(num);
            }
            else
            {
                if(val==0)
                {
                    num=250;
                }
                else
                {
                    num =me.minimums_radio.getValue();
                    num+=val;
                    if(num<0)num=0;
                    if(num>2500)num=2500;
                }
                me.minimums_radio.setValue(num);
            }
            me.minimums.setValue(num);
            me.mk_minimums.setValue(num);
        }
        elsif(md=="mins")
        {
            me.mins_mode.setValue(val);
            if (val)
            {
                me.mins_mode_txt.setValue("BARO");
                me.minimums.setValue(me.minimums_baro.getValue());
            }
            else
            {
                me.mins_mode_txt.setValue("RADIO");
                me.minimums.setValue(me.minimums_radio.getValue());
            }
        }
        elsif(md=="display")
        {
            var num =me.mfd_mode_num.getValue();
            num+=val;
            if(num<0)num=0;
            if(num>3)num=3;
            me.mfd_mode_num.setValue(num);
            me.mfd_display_mode.setValue(me.mfd_mode_list[num]);

            # for all modes except plan, acft is up. For PLAN,
            # north is up.
            var isPLAN = (num == 3);
            setprop("instrumentation/nd/aircraft-heading-up", !isPLAN);
            setprop("instrumentation/nd/user-position", isPLAN);
            me.nd_plan_wpt.setValue(getprop("autopilot/route-manager/current-wp"));

            me.update_nd_center();
            me.update_nd_plan_center();
        }
        elsif(md=="rhvor")
        {
            var num =me.rh_vor_adf.getValue();
            num+=val;
            if(num>1)num=1;
            if(num<-1)num=-1;
            me.rh_vor_adf.setValue(num);
        }
        elsif(md=="lhvor")
        {
            var num =me.lh_vor_adf.getValue();
            num+=val;
            if(num>1)num=1;
            if(num<-1)num=-1;
            me.lh_vor_adf.setValue(num);
        }
        elsif(md=="center")
        {
            if(me.mfd_mode_num.getValue() == 3)
            {
                var index = me.nd_plan_wpt.getValue() + 1;
                if(index >= getprop("autopilot/route-manager/route/num")) index = getprop("autopilot/route-manager/current-wp");
                me.nd_plan_wpt.setValue(index);
            }
            else
            {
                var num =me.nd_centered.getValue();
                num = 1 - num;
                me.nd_centered.setValue(num);
                me.update_radar_font();
                me.update_nd_center();
            }
        }
        else
        {
            print("Unsupported mode: ",md);
        }
    },
    update_radar_font : func {
        var fnt=[12,13];
        var linespacing = 0.01;
        var num = me.nd_centered.getValue();
        setprop("instrumentation/radar/font/size",fnt[num]);
        setprop("instrumentation/radar/font/line-spacing",linespacing);
    },
    update_nd_center : func {
        # PLAN mode is always centered
        var isPLAN = (me.mfd_mode_num.getValue() == 3);
        if (isPLAN or me.nd_centered.getValue())
        {
            setprop("instrumentation/nd/y-center", 0.5);
        } else {
            setprop("instrumentation/nd/y-center", 0.15);
        }
    },

    update_nd_plan_center : func {
        # find wpt lat, lon
        var index = me.nd_plan_wpt.getValue();
        if(index >= 0)
        {
            var lat = getprop("autopilot/route-manager/route/wp[" ~ index ~ "]/latitude-deg");
            var lon = getprop("autopilot/route-manager/route/wp[" ~ index ~ "]/longitude-deg");
            if(lon!=nil) setprop("instrumentation/nd/user-longitude-deg", lon);
            if(lat!=nil) setprop("instrumentation/nd/user-latitude-deg", lat);
        }
    },
};
##############################################

##############################################
#Engine control class
# ie: var Eng = Engine.new(engine number);
var Engine = {
    new : func(eng_num){
        m = { parents : [Engine]};
        m.fdensity = getprop("consumables/fuel/tank/density-ppg");
        if(m.fdensity ==nil)m.fdensity=6.90;
        m.eng = props.globals.getNode("engines/engine["~eng_num~"]",1);
        m.running = m.eng.getNode("running",1);
        m.running.setBoolValue(0);
        m.n1 = m.eng.getNode("n1",1);
        m.n2 = m.eng.getNode("n2",1);
        m.rpm = m.eng.getNode("rpm",1);
        m.rpm.setDoubleValue(0);
        m.throttle_lever = props.globals.getNode("controls/engines/engine["~eng_num~"]/throttle-lever",1);
        m.throttle_lever.setDoubleValue(0);
        m.throttle = props.globals.getNode("controls/engines/engine["~eng_num~"]/throttle",1);
        m.throttle.setDoubleValue(0);
        m.cutoff = props.globals.getNode("controls/engines/engine["~eng_num~"]/cutoff",1);
        m.cutoff.setBoolValue(1);
        m.fuel_out = props.globals.getNode("engines/engine["~eng_num~"]/out-of-fuel",1);
        m.fuel_out.setBoolValue(0);
        m.starter = props.globals.getNode("controls/engines/engine["~eng_num~"]/starter",1);
        m.fuel_pph=m.eng.getNode("fuel-flow_pph",1);
        m.fuel_pph.setDoubleValue(0);
        m.fuel_gph=m.eng.getNode("fuel-flow-gph",1);
        m.hpump=props.globals.getNode("systems/hydraulics/pump-psi["~eng_num~"]",1);
        m.hpump.setDoubleValue(0);
    return m;
    },
#### update ####
    update : func{
        if(me.fuel_out.getBoolValue())me.cutoff.setBoolValue(1);
        if(!me.cutoff.getBoolValue()){
        me.rpm.setValue(me.n1.getValue());
        me.throttle_lever.setValue(me.throttle.getValue());
        }else{
            me.throttle_lever.setValue(0);
            if(me.starter.getBoolValue()){
                me.spool_up();
            }else{
                var tmprpm = me.rpm.getValue();
                if(tmprpm > 0.0){
                    tmprpm -= getprop("sim/time/delta-realtime-sec") * 0.5;
                    me.rpm.setValue(tmprpm);
                }
            }
        }
    me.fuel_pph.setValue(me.fuel_gph.getValue()*me.fdensity);
    var hpsi =me.rpm.getValue();
    if(hpsi>60)hpsi = 60;
    me.hpump.setValue(hpsi);
    },

    spool_up : func{
        if(!me.cutoff.getBoolValue()){
        return;
        }else{
            var tmprpm = me.rpm.getValue();
            tmprpm += getprop("sim/time/delta-realtime-sec") * 0.5;
            me.rpm.setValue(tmprpm);
            if(tmprpm >= me.n1.getValue())me.cutoff.setBoolValue(0);
        }
    },

};
##########################

var Wiper = {
    new : func {
        m = { parents : [Wiper] };
        m.direction = 0;
        m.delay_count = 0;
        m.spd_factor = 0;
        m.node = props.globals.getNode(arg[0],1);
        m.power = props.globals.getNode(arg[1],1);
        if(m.power.getValue()==nil)m.power.setDoubleValue(0);
        m.spd = m.node.getNode("arc-sec",1);
        if(m.spd.getValue()==nil)m.spd.setDoubleValue(1);
        m.delay = m.node.getNode("delay-sec",1);
        if(m.delay.getValue()==nil)m.delay.setDoubleValue(0);
        m.position = m.node.getNode("position-norm", 1);
        m.position.setDoubleValue(0);
        m.switch = m.node.getNode("switch", 1);
        if (m.switch.getValue() == nil)m.switch.setBoolValue(0);
        return m;
    },
    active: func{
    if(me.power.getValue()<=5)return;
    var spd_factor = 1/me.spd.getValue();
    var pos = me.position.getValue();
    if(!me.switch.getValue()){
        if(pos <= 0.000)return;
        }
    if(pos >=1.000){
        me.direction=-1;
        }elsif(pos <=0.000){
        me.direction=0;
        me.delay_count+=getprop("/sim/time/delta-sec");
        if(me.delay_count >= me.delay.getValue()){
            me.delay_count=0;
            me.direction=1;
            }
        }
    var wiper_time = spd_factor*getprop("/sim/time/delta-sec");
    pos +=(wiper_time * me.direction);
    me.position.setValue(pos);
    }
};
#####################

var Efis = EFIS.new("instrumentation/efis");
var Efis2 = EFIS.new("instrumentation/efis[1]");
var LHeng=Engine.new(0);
var RHeng=Engine.new(1);
    var wiper = Wiper.new("controls/electric/wipers","systems/electrical/bus-volts");


setlistener("/sim/signals/fdm-initialized", func {
    SndOut.setDoubleValue(0.35);
    setprop("/instrumentation/clock/flight-meter-hour",0);
    setprop("/instrumentation/groundradar/id",getprop("/sim/tower/airport-id"));
    settimer(update_systems,1);
});

setlistener("/sim/signals/reinit", func {
    SndOut.setDoubleValue(0.35);
    setprop("/instrumentation/clock/flight-meter-hour",0);
    Shutdown();
});


setprop("/autopilot/route-manager/route/num", 0);

setlistener("/autopilot/route-manager/route/num", func(wp){
    var wpth = wp.getValue();
    var wpt = wpth - 1;
    
    if(wpt>-1){
    setprop("/instrumentation/groundradar/id",getprop("/autopilot/route-manager/route/wp["~wpt~"]/id"));
    }else{
    setprop("/instrumentation/groundradar/id",getprop("/sim/tower/airport-id"));
    }
},1,0);

setlistener("/sim/current-view/internal", func(vw){
    if(vw.getValue()){
    SndOut.setDoubleValue(0.35);
    }else{
    SndOut.setDoubleValue(1.0);
    }
},1,0);

setlistener("/sim/model/start-idling", func(idle){
    var run= idle.getBoolValue();
    if(run){
    Startup();
    }else{
    Shutdown();
    }
},0,0);

controls.gearDown = func(v) {
    if (v < 0) {
        if(!getprop("gear/gear[1]/wow"))setprop("/controls/gear/gear-down", 0);
    } elsif (v > 0) {
      setprop("/controls/gear/gear-down", 1);
    }
}

stall_horn = func{
    var alert=0;
    var kias=getprop("velocities/airspeed-kt");
    if(kias>150){setprop("sim/sound/stall-horn",alert);return;};
    var wow1=getprop("gear/gear[1]/wow");
    var wow2=getprop("gear/gear[2]/wow");
   
    if(!wow1 or !wow2){
        var grdn=getprop("controls/gear/gear-down");
        var flap=getprop("controls/flight/flaps");
        if(kias<100){
            alert=1;
        }elsif(kias<120){
            if(!grdn )alert=1;
        }else{
            if(flap==0)alert=1;
        }
    }
    setprop("sim/sound/stall-horn",alert);
}

var Startup = func{
setprop("controls/electric/engine[0]/generator",1);
setprop("controls/electric/engine[1]/generator",1);
setprop("controls/electric/engine[0]/bus-tie",1);
setprop("controls/electric/engine[1]/bus-tie",1);
setprop("controls/electric/APU-generator",1);
setprop("controls/electric/avionics-switch",1);
setprop("controls/electric/battery-switch",1);
setprop("controls/electric/inverter-switch",1);
setprop("controls/lighting/instrument-norm",0.8);
setprop("controls/lighting/nav-lights",1);
setprop("controls/lighting/beacon",1);
setprop("controls/lighting/strobe",1);
setprop("controls/lighting/wing-lights",1);
setprop("controls/lighting/taxi-light",1);
setprop("controls/lighting/logo-lights",1);
setprop("controls/lighting/cabin-lights",1);
setprop("controls/lighting/landing-lights",0);
setprop("controls/engines/engine[0]/cutoff",0);
setprop("controls/engines/engine[1]/cutoff",0);
setprop("controls/fuel/tank/boost-pump",1);
setprop("controls/fuel/tank/boost-pump[1]",1);
setprop("controls/fuel/tank[1]/boost-pump",1);
setprop("controls/fuel/tank[1]/boost-pump[1]",1);
setprop("controls/fuel/tank[2]/boost-pump",1);
setprop("controls/fuel/tank[2]/boost-pump[1]",1);
}

var Shutdown = func{
setprop("controls/electric/engine[0]/generator",0);
setprop("controls/electric/engine[1]/generator",0);
setprop("controls/electric/engine[0]/bus-tie",0);
setprop("controls/electric/engine[1]/bus-tie",0);
setprop("controls/electric/APU-generator",0);
setprop("controls/electric/avionics-switch",0);
setprop("controls/electric/battery-switch",0);
setprop("controls/electric/inverter-switch",0);
setprop("controls/lighting/instruments-norm",0);
setprop("controls/lighting/nav-lights",0);
setprop("controls/lighting/beacon",0);
setprop("controls/lighting/strobe",0);
setprop("controls/lighting/wing-lights",0);
setprop("controls/lighting/taxi-light",0);
setprop("controls/lighting/logo-lights",0);
setprop("controls/lighting/cabin-lights",0);
setprop("controls/lighting/landing-lights",0);
setprop("controls/engines/engine[0]/cutoff",1);
setprop("controls/engines/engine[1]/cutoff",1);
setprop("controls/fuel/tank/boost-pump",0);
setprop("controls/fuel/tank/boost-pump[1]",0);
setprop("controls/fuel/tank[1]/boost-pump",0);
setprop("controls/fuel/tank[1]/boost-pump[1]",0);
setprop("controls/fuel/tank[2]/boost-pump",0);
setprop("controls/fuel/tank[2]/boost-pump[1]",0);
}

var click_reset = func(propName) {
    setprop(propName,0);
}

controls.click = func(button) {
    if (getprop("sim/freeze/replay-state"))
        return;
    var propName="sim/sound/click"~button;
    setprop(propName,1);
    settimer(func { click_reset(propName) },0.4);
}

var update_systems = func {
    Efis.calc_kpa();
    Efis.update_temp();
    LHeng.update();
    RHeng.update();
    #wiper.active(); # not implemented yet!
    setprop("instrumentation/efis/mfd/rangearc", (Efis.mfd_display_mode.getValue() == "MAP")
        and (Efis.wxr.getValue() or Efis.terr.getValue() or Efis.tfc.getValue()));
    setprop("instrumentation/efis[1]/mfd/rangearc", (Efis2.mfd_display_mode.getValue() == "MAP")
        and (Efis2.wxr.getValue() or Efis2.terr.getValue() or Efis2.tfc.getValue()));
    stall_horn();
    
    settimer(update_systems,0);
}
