// ============================================================
// KRISTN AUTOPILOT — lib_common.ks
// Shared utility functions for all scripts
// ============================================================
@LAZYGLOBAL OFF.

// ── PHYSICS HELPERS ─────────────────────────────────

FUNCTION ks_twr {
    // Current TWR (all active engines vs current gravity)
    LOCAL g IS BODY:MU / (BODY:RADIUS + ALTITUDE)^2.
    LOCAL thr IS SHIP:AVAILABLETHRUST.
    IF g = 0 OR SHIP:MASS = 0 RETURN 0.
    RETURN thr / (SHIP:MASS * g).
}

FUNCTION ks_surface_twr {
    // TWR at sea-level gravity
    LOCAL g IS BODY:MU / BODY:RADIUS^2.
    RETURN SHIP:AVAILABLETHRUST / (SHIP:MASS * g).
}

FUNCTION ks_aoa {
    // Angle of attack (degrees between velocity and ship facing)
    IF SHIP:AIRSPEED < 1 RETURN 0.
    RETURN VANG(SHIP:FACING:FOREVECTOR, SHIP:SRFPROGRADE:FOREVECTOR).
}

FUNCTION ks_dynamic_pressure {
    // Q in kPa (approximate)
    RETURN SHIP:Q * CONSTANT:ATMtokPa.
}

FUNCTION ks_time_to_alt {
    PARAMETER target_alt.
    // Rough ETA to an altitude based on vertical speed
    IF SHIP:VERTICALSPEED <= 0 RETURN 9999.
    RETURN (target_alt - ALTITUDE) / SHIP:VERTICALSPEED.
}

// ── ORBITAL HELPERS ─────────────────────────────────

FUNCTION ks_circ_dv {
    // Delta-v for circularization at current apoapsis
    LOCAL r IS BODY:RADIUS + SHIP:APOAPSIS.
    LOCAL v_circ IS SQRT(BODY:MU / r).
    LOCAL v_at_ap IS SQRT(BODY:MU * (2/r - 1/(SHIP:ORBIT:SEMIMAJORAXIS))).
    RETURN v_circ - v_at_ap.
}

FUNCTION ks_hohmann_dv {
    PARAMETER target_alt.
    // Hohmann transfer delta-v from current circular orbit
    LOCAL r1 IS BODY:RADIUS + ALTITUDE.
    LOCAL r2 IS BODY:RADIUS + target_alt.
    LOCAL a_transfer IS (r1 + r2) / 2.
    LOCAL dv1 IS SQRT(BODY:MU / r1) * (SQRT(2 * r2 / (r1 + r2)) - 1).
    LOCAL dv2 IS SQRT(BODY:MU / r2) * (1 - SQRT(2 * r1 / (r1 + r2))).
    RETURN LIST(ABS(dv1), ABS(dv2)).
}

FUNCTION ks_burn_time {
    PARAMETER dv.
    // Tsiolkovsky burn time estimate
    IF SHIP:AVAILABLETHRUST = 0 RETURN 9999.
    LOCAL isp IS 0.
    LOCAL eng_list IS LIST().
    LIST ENGINES IN eng_list.
    FOR e IN eng_list {
        IF e:IGNITION AND NOT e:FLAMEOUT {
            SET isp TO e:ISP.
            BREAK.
        }
    }
    IF isp = 0 RETURN 9999.
    LOCAL exhaust_v IS isp * CONSTANT:g0.
    LOCAL mass_ratio IS CONSTANT:E ^ (dv / exhaust_v).
    RETURN SHIP:MASS * exhaust_v * (1 - 1/mass_ratio) / SHIP:AVAILABLETHRUST.
}

// ── LANDING HELPERS ─────────────────────────────────

FUNCTION ks_terrain_height {
    // Terrain height below ship
    RETURN ALTITUDE - ALT:RADAR.
}

FUNCTION ks_geo_dist {
    PARAMETER geo1.
    PARAMETER geo2.
    // Great-circle distance between two geopositions (meters)
    LOCAL lat1 IS geo1:LAT * CONSTANT:DEGTORAD.
    LOCAL lat2 IS geo2:LAT * CONSTANT:DEGTORAD.
    LOCAL dlon IS (geo2:LNG - geo1:LNG) * CONSTANT:DEGTORAD.
    LOCAL a IS SIN((lat2-lat1)/2)^2 + COS(lat1)*COS(lat2)*SIN(dlon/2)^2.
    LOCAL c IS 2 * ARCTAN2(SQRT(a), SQRT(1-a)) * CONSTANT:DEGTORAD.
    RETURN BODY:RADIUS * c.
}

FUNCTION ks_ksc_runway {
    // KSC runway 09 threshold geoposition
    RETURN LATLNG(-0.0486, -74.724).
}

FUNCTION ks_ksc_runway_27 {
    // KSC runway 27 threshold
    RETURN LATLNG(-0.0502, -74.490).
}

// ── ENGINE HELPERS ──────────────────────────────────

FUNCTION ks_engines_on {
    LOCAL eng_list IS LIST().
    LIST ENGINES IN eng_list.
    FOR e IN eng_list {
        IF NOT e:IGNITION { e:ACTIVATE. }
    }
}

FUNCTION ks_engines_off {
    LOCAL eng_list IS LIST().
    LIST ENGINES IN eng_list.
    FOR e IN eng_list {
        IF e:IGNITION { e:SHUTDOWN. }
    }
}

FUNCTION ks_active_engine_count {
    LOCAL cnt IS 0.
    LOCAL eng_list IS LIST().
    LIST ENGINES IN eng_list.
    FOR e IN eng_list {
        IF e:IGNITION AND NOT e:FLAMEOUT SET cnt TO cnt + 1.
    }
    RETURN cnt.
}

// ── DISPLAY HELPERS ─────────────────────────────────

FUNCTION ks_print_bar {
    PARAMETER label.
    PARAMETER val.
    PARAMETER max_val.
    PARAMETER row.
    LOCAL pct IS 0.
    IF max_val > 0 SET pct TO MIN(1, val / max_val).
    LOCAL bar_len IS 20.
    LOCAL filled IS ROUND(pct * bar_len).
    LOCAL bar IS "".
    FROM { LOCAL i IS 0. } UNTIL i >= bar_len STEP { SET i TO i + 1. } DO {
        IF i < filled SET bar TO bar + "█".
        ELSE SET bar TO bar + "░".
    }
    PRINT (label + " " + bar + " " + ROUND(pct*100) + "%"):PADRIGHT(48) AT(0, row).
}

FUNCTION ks_log {
    PARAMETER msg.
    PARAMETER logfile IS "0:/logs/autopilot.log".
    LOG ROUND(MISSIONTIME,1) + " | " + msg TO logfile.
}

PRINT "lib_common loaded.".
