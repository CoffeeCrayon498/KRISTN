// ══════════════════════════════════════════════════════════
// KRISTN - DEORBIT & LANDING SCRIPT v2
// deorbit.ks — Kerbin deorbit + propulsive landing
// Fixes: Engine activation check, direct burn (no node), 
//        better landing burn timing
// ══════════════════════════════════════════════════════════
@LAZYGLOBAL OFF.
RUNONCEPATH("0:/gui_lib.ks").

CLEARSCREEN.
gui_telemetry("DEORBIT PREP").

LOCAL g0 IS 9.80665.
LOCAL deorbit_peri IS 30000.   // 30km periapsis target
LOCAL touchdown_speed IS 3.    // m/s at touchdown

// ══════════════════════════════════════
// PHASE 1: UNDOCK (if docked)
// ══════════════════════════════════════
LOCAL my_ports IS SHIP:DOCKINGPORTS.
FOR p IN my_ports {
    IF p:STATE:CONTAINS("Docked") {
        gui_status("Undocking...").
        p:UNDOCK.
        WAIT 1.
        RCS ON.
        SET SHIP:CONTROL:FORE TO -0.5.
        WAIT 3.
        SET SHIP:CONTROL:FORE TO 0.
        SET SHIP:CONTROL:NEUTRALIZE TO TRUE.
        WAIT 2.
        RCS OFF.
        gui_status("Undocked.").
        WAIT 5.
    }
}

// ══════════════════════════════════════
// PHASE 2: ENGINE CHECK
// ══════════════════════════════════════
gui_status("Checking engine...").

// Force-activate all engines
LOCAL eng_list IS LIST().
LIST ENGINES IN eng_list.
FOR e IN eng_list {
    IF NOT e:IGNITION {
        gui_status("Activating engine: " + e:NAME).
        e:ACTIVATE.
        WAIT 0.5.
    }
}

// Verify we have thrust available
LIST ENGINES IN eng_list.
LOCAL has_thrust IS FALSE.
FOR e IN eng_list {
    IF e:IGNITION AND NOT e:FLAMEOUT AND e:AVAILABLETHRUST > 0 {
        SET has_thrust TO TRUE.
    }
}

IF NOT has_thrust {
    gui_status("ERROR: No engine thrust available!").
    PRINT "Check engine activation and fuel." AT (0, 12).
    PRINT "LF: " + ROUND(SHIP:LIQUIDFUEL, 0) AT (0, 13).
    PRINT "Available thrust: " + SHIP:AVAILABLETHRUST AT (0, 14).
    SAS ON.
    // Don't exit, just warn — maybe staging is needed
}

PRINT "Thrust available: " + ROUND(SHIP:AVAILABLETHRUST, 0) + " kN" AT (0, 12).
PRINT "Mass: " + ROUND(SHIP:MASS, 1) + " t" AT (0, 13).

// ══════════════════════════════════════
// PHASE 3: CALCULATE DEORBIT BURN
// ══════════════════════════════════════
gui_status("Calculating deorbit burn...").

LOCAL r_current IS BODY:RADIUS + ALTITUDE.
LOCAL r_peri IS BODY:RADIUS + deorbit_peri.
LOCAL current_sma IS ORBIT:SEMIMAJORAXIS.
LOCAL new_sma IS (r_current + r_peri) / 2.

LOCAL v_current IS SQRT(BODY:MU * (2/r_current - 1/current_sma)).
LOCAL v_new IS SQRT(BODY:MU * (2/r_current - 1/new_sma)).
LOCAL dv_deorbit IS ABS(v_current - v_new).

gui_status("Deorbit dV: " + ROUND(dv_deorbit, 1) + " m/s retrograde").
PRINT "Target periapsis: " + ROUND(deorbit_peri/1000, 1) + " km" AT (0, 14).

// ══════════════════════════════════════
// PHASE 4: ORIENT RETROGRADE
// ══════════════════════════════════════
gui_status("Orienting retrograde...").
SAS OFF.
LOCK STEERING TO RETROGRADE.

// Wait for alignment
LOCAL orient_start IS TIME:SECONDS.
WAIT UNTIL VANG(SHIP:FACING:FOREVECTOR, (-1) * SHIP:VELOCITY:ORBIT:NORMALIZED) < 3
    OR TIME:SECONDS > orient_start + 45.

LOCAL align_error IS VANG(SHIP:FACING:FOREVECTOR, (-1) * SHIP:VELOCITY:ORBIT:NORMALIZED).
IF align_error > 10 {
    gui_status("WARNING: Poor alignment (" + ROUND(align_error) + "°)").
    WAIT 5.  // Give it more time
}

gui_status("Aligned. Starting deorbit burn.").
WAIT 2.

// ══════════════════════════════════════
// PHASE 5: DEORBIT BURN (direct retrograde)
// ══════════════════════════════════════
gui_status("DEORBIT BURN").
LOCK STEERING TO RETROGRADE.

// Start at half throttle
LOCK THROTTLE TO 0.5.

LOCAL burn_done IS FALSE.
LOCAL burn_start_time IS TIME:SECONDS.
LOCAL initial_peri IS PERIAPSIS.

UNTIL burn_done {
    gui_telemetry("DEORBIT BURN").
    PRINT "Target peri: " + ROUND(deorbit_peri/1000, 1) + " km   " AT (0, 11).
    PRINT "Current peri: " + ROUND(PERIAPSIS/1000, 1) + " km   " AT (0, 12).
    PRINT "Thrust: " + ROUND(SHIP:AVAILABLETHRUST * THROTTLE, 0) + " kN   " AT (0, 13).

    // Check if periapsis is actually dropping
    IF TIME:SECONDS > burn_start_time + 5 AND PERIAPSIS >= initial_peri - 100 {
        gui_status("WARNING: Periapsis not dropping! Check orientation.").
    }

    // Throttle management based on how close we are
    LOCAL peri_error IS PERIAPSIS - deorbit_peri.
    IF peri_error < 3000 {
        LOCK THROTTLE TO MAX(0.02, peri_error / 15000).
    } ELSE IF peri_error < 10000 {
        LOCK THROTTLE TO 0.2.
    } ELSE {
        LOCK THROTTLE TO 0.5.
    }

    // Done when periapsis reaches target
    IF PERIAPSIS <= deorbit_peri + 500 {
        SET burn_done TO TRUE.
    }

    // Safety timeout
    IF TIME:SECONDS > burn_start_time + 90 {
        gui_status("Burn timeout — stopping.").
        SET burn_done TO TRUE.
    }

    WAIT 0.
}

LOCK THROTTLE TO 0.
gui_status("Deorbit burn complete.").
PRINT "New orbit: " + ROUND(APOAPSIS/1000, 1) + " x " + ROUND(PERIAPSIS/1000, 1) + " km" AT (0, 14).
WAIT 3.

// ══════════════════════════════════════
// PHASE 6: COAST TO ATMOSPHERE
// ══════════════════════════════════════
gui_status("Coasting to atmosphere...").
LOCK STEERING TO SRFRETROGRADE.

IF ALTITUDE > 75000 {
    gui_status("Warping to atmosphere...").
    // Warp until closer to atmosphere
    KUNIVERSE:TIMEWARP:WARPTO(TIME:SECONDS + ETA:PERIAPSIS - 120).
    WAIT UNTIL ALTITUDE < 75000 OR VERTICALSPEED < -50.
    KUNIVERSE:TIMEWARP:CANCELWARP().
    WAIT UNTIL SHIP:UNPACKED.
    WAIT 2.
}

// ══════════════════════════════════════
// PHASE 7: REENTRY
// ══════════════════════════════════════
gui_status("REENTRY — holding retrograde").
LOCK STEERING TO SRFRETROGRADE.

WAIT UNTIL ALTITUDE < 40000.
gui_status("Through max heating.").

// ══════════════════════════════════════
// PHASE 8: PROPULSIVE LANDING
// ══════════════════════════════════════
WAIT UNTIL ALTITUDE < 20000.
gui_status("Preparing landing burn...").
LOCK STEERING TO SRFRETROGRADE.

LOCAL burn_started IS FALSE.

UNTIL SHIP:STATUS = "LANDED" OR SHIP:STATUS = "SPLASHED" OR ALT:RADAR < 2 {
    gui_telemetry("LANDING").

    LOCAL radar IS ALT:RADAR.
    LOCAL v_spd IS ABS(VERTICALSPEED).  // Positive = descending speed
    LOCAL h_spd IS GROUNDSPEED.
    LOCAL total_spd IS SHIP:VELOCITY:SURFACE:MAG.

    PRINT "Radar:  " + ROUND(radar) + " m   " AT (0, 11).
    PRINT "V spd:  " + ROUND(v_spd, 1) + " m/s   " AT (0, 12).
    PRINT "H spd:  " + ROUND(h_spd, 1) + " m/s   " AT (0, 13).

    // Calculate suicide burn parameters
    LOCAL max_accel IS SHIP:AVAILABLETHRUST / SHIP:MASS.
    LOCAL local_g IS BODY:MU / (BODY:RADIUS + ALTITUDE)^2.
    LOCAL net_decel IS max_accel - local_g.
    IF net_decel <= 0 { SET net_decel TO 0.1. }

    // Stopping distance from current total surface speed
    LOCAL stop_dist IS (total_spd^2) / (2 * net_decel).

    // Add 30% safety margin
    LOCAL burn_alt IS stop_dist * 1.3 + 100.

    PRINT "Burn at: " + ROUND(burn_alt) + " m   " AT (0, 14).

    // Start burn when radar altitude drops below burn altitude
    IF NOT burn_started AND radar < burn_alt AND VERTICALSPEED < -10 {
        SET burn_started TO TRUE.
        gui_status("LANDING BURN").
    }

    IF burn_started {
        LOCK STEERING TO SRFRETROGRADE.

        IF total_spd > 50 {
            // Still fast — full thrust
            LOCK THROTTLE TO 1.0.
        } ELSE IF v_spd > touchdown_speed + 2 {
            // Approaching touchdown speed
            LOCAL needed_accel IS local_g + (v_spd - touchdown_speed) * 0.5.
            LOCK THROTTLE TO MIN(1.0, MAX(0.05, needed_accel / max_accel)).
        } ELSE IF v_spd > 1 {
            // Gentle descent
            LOCAL hover IS local_g / max_accel.
            LOCK THROTTLE TO MIN(1.0, MAX(0.01, hover)).
        } ELSE {
            LOCK THROTTLE TO 0.
        }

        // Deploy gear close to ground
        IF radar < 500 {
            GEAR ON.
        }

        // Cut engine at touchdown
        IF radar < 10 AND v_spd < 5 {
            LOCK THROTTLE TO 0.
        }
    } ELSE {
        LOCK THROTTLE TO 0.
    }

    WAIT 0.
}

// ══════════════════════════════════════
// PHASE 9: LANDED
// ══════════════════════════════════════
LOCK THROTTLE TO 0.
UNLOCK STEERING.
UNLOCK THROTTLE.
SAS ON.

CLEARSCREEN.
gui_telemetry("LANDED").
gui_status("WORKHORSE has landed!").
PRINT " " AT (0, 12).
PRINT "Lat: " + ROUND(SHIP:GEOPOSITION:LAT, 2) AT (0, 13).
PRINT "Lng: " + ROUND(SHIP:GEOPOSITION:LNG, 2) AT (0, 14).
PRINT "dV remaining: ~" + ROUND(calc_dv()) + " m/s" AT (0, 15).
PRINT " " AT (0, 16).
PRINT "Recovery complete. WORKHORSE ready for reuse." AT (0, 17).
