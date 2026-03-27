// ══════════════════════════════════════════════════════════
// KRISTN - BACKGROUND FLIGHT RECORDER (PERSISTENT)
// flight_recorder.ks — Runs as a background trigger alongside missions
// Auto-labels flights, logs everything, always on
// ══════════════════════════════════════════════════════════
@LAZYGLOBAL OFF.

// ── Persistent ID Management ──
GLOBAL flight_id IS "UNLABELED".
GLOBAL flight_label IS "STANDBY".
GLOBAL recorder_logfile IS "".

// Check if we are resuming a flight after a scene change
IF EXISTS("1:/current_flight.txt") {
    LOCAL saved_data IS OPEN("1:/current_flight.txt"):READALL():STRING.
    LOCAL parts IS saved_data:SPLIT(",").
    IF parts:LENGTH >= 2 {
        SET flight_id TO parts[0].
        SET flight_label TO parts[1].
        SET recorder_logfile TO "0:/logs/" + flight_id + ".csv".
        PRINT "Recorder Resumed: " + flight_id.
    }
}

// ── Set flight label (called from boot.ks when mission is selected) ──
FUNCTION set_flight_label {
    PARAMETER mission_type.
    
    // Generate a smart, readable ID: SHIPNAME-MISSION-TIMESTAMP
    SET flight_label TO mission_type.
    SET flight_id TO SHIP:NAME + "-" + mission_type + "-" + ROUND(TIME:SECONDS).
    SET recorder_logfile TO "0:/logs/" + flight_id + ".csv".
    
    // Save to local drive so it survives scene changes
    IF EXISTS("1:/current_flight.txt") { DELETEPATH("1:/current_flight.txt"). }
    LOG flight_id + "," + flight_label TO "1:/current_flight.txt".
    
    // Write metadata
    LOCAL metafile IS "0:/logs/" + flight_id + "_meta.txt".
    IF EXISTS(metafile) { DELETEPATH(metafile). }
    LOG "flight_id: " + flight_id TO metafile.
    LOG "label: " + flight_label TO metafile.
    LOG "ship: " + SHIP:NAME TO metafile.
    LOG "body: " + BODY:NAME TO metafile.
    LOG "start_ut: " + TIME:SECONDS TO metafile.
    LOG "mass_wet: " + SHIP:MASS TO metafile.
    LOG "mass_dry: " + SHIP:DRYMASS TO metafile.
    LOG "parts: " + SHIP:PARTS:LENGTH TO metafile.
}

// ── Create logs directory if needed ──
IF NOT EXISTS("0:/logs") { CREATEDIR("0:/logs"). }

// ── CSV Header (Only write if starting a fresh file) ──
FUNCTION write_header_if_needed {
    IF NOT EXISTS(recorder_logfile) AND recorder_logfile <> "" {
        LOCAL header IS "met,alt,radar_alt,apo,peri,srf_speed,orb_speed,v_speed,h_speed,pitch,heading,aoa,sideslip,throttle,thrust,avail_thrust,twr,max_twr,mass,dry_mass,lf,lf_max,ox,ox_max,lh2,lh2_max,ec,dyn_pressure,g_force,sas,rcs,gear,lat,lng,body,status,inc,ecc,sma,eta_apo,eta_peri,phase,label".
        LOG header TO recorder_logfile.
    }
}

// ── Helper functions ──
FUNCTION rec_get_res { PARAMETER rname. FOR r IN SHIP:RESOURCES { IF r:NAME = rname { RETURN r:AMOUNT. } } RETURN 0. }
FUNCTION rec_get_res_max { PARAMETER rname. FOR r IN SHIP:RESOURCES { IF r:NAME = rname { RETURN r:CAPACITY. } } RETURN 0. }
FUNCTION rec_get_pitch { RETURN 90 - VANG(SHIP:UP:FOREVECTOR, SHIP:FACING:FOREVECTOR). }
FUNCTION rec_get_heading {
    LOCAL vel IS SHIP:VELOCITY:SURFACE.
    IF vel:MAG < 1 { RETURN 0. }
    LOCAL east IS VCRS(SHIP:UP:FOREVECTOR, SHIP:NORTH:FOREVECTOR):NORMALIZED.
    RETURN ARCTAN2(VDOT(vel:NORMALIZED, east), VDOT(vel:NORMALIZED, SHIP:NORTH:FOREVECTOR)).
}
FUNCTION rec_get_aoa { IF SHIP:VELOCITY:SURFACE:MAG < 1 { RETURN 0. } RETURN VANG(SHIP:FACING:FOREVECTOR, SHIP:VELOCITY:SURFACE). }
FUNCTION rec_get_sideslip { IF SHIP:VELOCITY:SURFACE:MAG < 1 { RETURN 0. } LOCAL vel_body IS SHIP:FACING:INVERSE * SHIP:VELOCITY:SURFACE. RETURN ARCTAN2(vel_body:X, vel_body:Z). }
FUNCTION rec_get_twr { LOCAL local_g IS BODY:MU / (BODY:RADIUS + ALTITUDE)^2. IF SHIP:MASS <= 0 { RETURN 0. } RETURN SHIP:AVAILABLETHRUST / (SHIP:MASS * local_g). }
FUNCTION rec_get_max_twr {
    LOCAL local_g IS BODY:MU / (BODY:RADIUS + ALTITUDE)^2.
    IF SHIP:MASS <= 0 { RETURN 0. }
    LOCAL eng_list IS LIST(). LIST ENGINES IN eng_list. LOCAL t IS 0.
    FOR e IN eng_list { IF e:IGNITION AND NOT e:FLAMEOUT { SET t TO t + e:POSSIBLETHRUST. } }
    RETURN t / (SHIP:MASS * local_g).
}
FUNCTION rec_get_gforce {
    LOCAL local_g IS BODY:MU / (BODY:RADIUS + ALTITUDE)^2.
    IF SHIP:MASS <= 0 { RETURN 1. }
    LOCAL thrust_accel IS SHIP:AVAILABLETHRUST * THROTTLE / SHIP:MASS.
    RETURN (thrust_accel + local_g * COS(rec_get_pitch())) / 9.80665.
}
FUNCTION rec_get_phase {
    IF SHIP:STATUS = "PRELAUNCH" { RETURN "PRELAUNCH". }
    IF SHIP:STATUS = "LANDED" AND VERTICALSPEED > 1 { RETURN "LIFTOFF". }
    IF SHIP:STATUS = "LANDED" { RETURN "LANDED". }
    IF SHIP:STATUS = "SPLASHED" { RETURN "SPLASHED". }
    IF ALTITUDE < 1000 AND VERTICALSPEED > 0 { RETURN "LIFTOFF". }
    IF ALTITUDE < 45000 AND APOAPSIS < 75000 AND VERTICALSPEED > 0 { RETURN "GRAVITY_TURN". }
    IF APOAPSIS > 70000 AND PERIAPSIS < 10000 AND VERTICALSPEED > 0 { RETURN "COAST_TO_APO". }
    IF APOAPSIS > 70000 AND PERIAPSIS < 10000 AND VERTICALSPEED <= 0 { RETURN "PAST_APO". }
    IF PERIAPSIS > 65000 AND APOAPSIS < PERIAPSIS * 1.5 { RETURN "ORBIT". }
    IF PERIAPSIS > 65000 { RETURN "ORBIT_ELLIPTIC". }
    IF ALTITUDE > 70000 AND VERTICALSPEED < -10 { RETURN "DEORBIT_COAST". }
    IF ALTITUDE < 70000 AND ALTITUDE > 20000 AND VERTICALSPEED < 0 { RETURN "REENTRY". }
    IF ALTITUDE < 20000 AND VERTICALSPEED < 0 AND THROTTLE > 0.05 { RETURN "LANDING_BURN". }
    IF ALTITUDE < 20000 AND VERTICALSPEED < 0 { RETURN "DESCENT". }
    IF SHIP:STATUS = "ORBITING" { RETURN "ORBIT". }
    RETURN "UNKNOWN".
}

// ── Background recording trigger ──
GLOBAL recorder_start_time IS TIME:SECONDS.
GLOBAL recorder_samples IS 0.
GLOBAL recorder_active IS TRUE.

WHEN recorder_active THEN {
    LOCAL met IS TIME:SECONDS - recorder_start_time.
    LOCAL dominated IS SHIP:VELOCITY:SURFACE:MAG > 0.5 OR THROTTLE > 0 OR ALTITUDE > 200 OR SHIP:STATUS = "ORBITING".
    
    IF dominated AND recorder_logfile <> "" {
        LOCAL line IS ROUND(met, 2) + ",".
        SET line TO line + ROUND(ALTITUDE, 1) + "," + ROUND(ALT:RADAR, 1) + ",".
        SET line TO line + ROUND(APOAPSIS, 1) + "," + ROUND(PERIAPSIS, 1) + ",".
        SET line TO line + ROUND(SHIP:VELOCITY:SURFACE:MAG, 2) + ",".
        SET line TO line + ROUND(SHIP:VELOCITY:ORBIT:MAG, 2) + ",".
        SET line TO line + ROUND(VERTICALSPEED, 2) + ",".
        SET line TO line + ROUND(GROUNDSPEED, 2) + ",".
        SET line TO line + ROUND(rec_get_pitch(), 2) + "," + ROUND(rec_get_heading(), 2) + ",".
        SET line TO line + ROUND(rec_get_aoa(), 2) + "," + ROUND(rec_get_sideslip(), 2) + ",".
        SET line TO line + ROUND(THROTTLE, 4) + ",".
        SET line TO line + ROUND(SHIP:AVAILABLETHRUST * THROTTLE, 2) + ",".
        SET line TO line + ROUND(SHIP:AVAILABLETHRUST, 2) + ",".
        SET line TO line + ROUND(rec_get_twr(), 4) + "," + ROUND(rec_get_max_twr(), 4) + ",".
        SET line TO line + ROUND(SHIP:MASS, 4) + "," + ROUND(SHIP:DRYMASS, 4) + ",".
        SET line TO line + ROUND(rec_get_res("LiquidFuel"), 1) + ",".
        SET line TO line + ROUND(rec_get_res_max("LiquidFuel"), 1) + ",".
        SET line TO line + ROUND(rec_get_res("Oxidizer"), 1) + ",".
        SET line TO line + ROUND(rec_get_res_max("Oxidizer"), 1) + ",".
        SET line TO line + ROUND(rec_get_res("LqdHydrogen"), 1) + ",".
        SET line TO line + ROUND(rec_get_res_max("LqdHydrogen"), 1) + ",".
        SET line TO line + ROUND(rec_get_res("ElectricCharge"), 1) + ",".
        SET line TO line + ROUND(SHIP:DYNAMICPRESSURE, 4) + "," + ROUND(rec_get_gforce(), 3) + ",".
        SET line TO line + SAS + "," + RCS + "," + GEAR + ",".
        SET line TO line + ROUND(SHIP:GEOPOSITION:LAT, 4) + ",".
        SET line TO line + ROUND(SHIP:GEOPOSITION:LNG, 4) + ",".
        SET line TO line + BODY:NAME + "," + SHIP:STATUS + ",".
        SET line TO line + ROUND(ORBIT:INCLINATION, 4) + ",".
        SET line TO line + ROUND(ORBIT:ECCENTRICITY, 6) + ",".
        SET line TO line + ROUND(ORBIT:SEMIMAJORAXIS, 1) + ",".
        SET line TO line + ROUND(ETA:APOAPSIS, 1) + "," + ROUND(ETA:PERIAPSIS, 1) + ",".
        SET line TO line + rec_get_phase() + "," + flight_label.

        LOG line TO recorder_logfile.
        SET recorder_samples TO recorder_samples + 1.
    }

    IF recorder_active { PRESERVE. }
    
    // Clean up tiny logs if we stop and have less than 50 samples
    IF NOT recorder_active AND recorder_samples < 50 AND recorder_logfile <> "" {
        IF EXISTS(recorder_logfile) { DELETEPATH(recorder_logfile). }
        LOCAL metafile IS "0:/logs/" + flight_id + "_meta.txt".
        IF EXISTS(metafile) { DELETEPATH(metafile). }
    }
    
    RETURN recorder_active.
}