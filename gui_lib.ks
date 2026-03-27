// ══════════════════════════════════════════════════════════
// KRISTN - GUI LIBRARY v2
// gui_lib.ks — Shared telemetry display functions
// Updated: Better TWR calc, AoA display
// ══════════════════════════════════════════════════════════
@LAZYGLOBAL OFF.

// ── Telemetry Display ──
FUNCTION gui_telemetry {
    PARAMETER phase IS "IDLE".

    LOCAL local_g IS BODY:MU / (BODY:RADIUS + ALTITUDE)^2.
    LOCAL cur_twr IS 0.
    IF SHIP:AVAILABLETHRUST > 0 AND SHIP:MASS > 0 {
        SET cur_twr TO (SHIP:AVAILABLETHRUST * THROTTLE) / (SHIP:MASS * local_g).
    }

    LOCAL max_twr IS 0.
    IF SHIP:AVAILABLETHRUST > 0 AND SHIP:MASS > 0 {
        SET max_twr TO SHIP:AVAILABLETHRUST / (SHIP:MASS * local_g).
    }

    PRINT "─── KRISTN WORKHORSE TELEMETRY ───" AT (0, 0).
    PRINT "Phase:    " + phase:PADRIGHT(24)          AT (0, 1).
    PRINT "Alt:      " + ROUND(ALTITUDE):TOSTRING:PADRIGHT(12) + "m"   AT (0, 2).
    PRINT "Apo:      " + ROUND(APOAPSIS):TOSTRING:PADRIGHT(12) + "m"  AT (0, 3).
    PRINT "Peri:     " + ROUND(PERIAPSIS):TOSTRING:PADRIGHT(12) + "m" AT (0, 4).
    PRINT "SrfSpd:   " + ROUND(SHIP:VELOCITY:SURFACE:MAG):TOSTRING:PADRIGHT(8) + "m/s" AT (0, 5).
    PRINT "TWR:      " + ROUND(cur_twr, 2) + " / " + ROUND(max_twr, 2) + "   " AT (0, 6).
    PRINT "Throttle: " + ROUND(THROTTLE * 100):TOSTRING:PADRIGHT(8) + "%"  AT (0, 7).
    PRINT "Mass:     " + ROUND(SHIP:MASS, 1):TOSTRING:PADRIGHT(8) + "t"   AT (0, 8).
    PRINT "──────────────────────────────────" AT (0, 9).
}

// ── Simple status line ──
FUNCTION gui_status {
    PARAMETER msg.
    PRINT ">> " + msg:PADRIGHT(35) AT (0, 10).
}

// ── ETA display ──
FUNCTION gui_eta {
    PARAMETER label.
    PARAMETER seconds.

    LOCAL m IS FLOOR(seconds / 60).
    LOCAL s IS ROUND(MOD(seconds, 60)).
    PRINT label + ": " + m + "m " + s + "s   " AT (0, 14).
}

// ── Delta-V remaining estimate ──
FUNCTION calc_dv {
    LOCAL eng_list IS LIST().
    LIST ENGINES IN eng_list.
    LOCAL total_thrust IS 0.
    LOCAL weighted_isp IS 0.
    FOR e IN eng_list {
        IF e:IGNITION AND NOT e:FLAMEOUT {
            SET total_thrust TO total_thrust + e:AVAILABLETHRUST.
            SET weighted_isp TO weighted_isp + e:AVAILABLETHRUST * e:VACUUMISP.
        }
    }
    IF total_thrust = 0 {
        // Engine might be off — check possible thrust
        FOR e IN eng_list {
            SET total_thrust TO total_thrust + e:POSSIBLETHRUST.
            SET weighted_isp TO weighted_isp + e:POSSIBLETHRUST * e:VACUUMISP.
        }
    }
    IF total_thrust = 0 RETURN 0.

    LOCAL avg_isp IS weighted_isp / total_thrust.
    LOCAL g IS 9.80665.
    LOCAL dry_mass IS SHIP:DRYMASS.
    LOCAL wet_mass IS SHIP:MASS.

    IF wet_mass <= dry_mass RETURN 0.

    RETURN avg_isp * g * LN(wet_mass / dry_mass).
}

// ── Wait with countdown ──
FUNCTION gui_countdown {
    PARAMETER seconds.
    PARAMETER label IS "T-minus".

    FROM { LOCAL t IS seconds. } UNTIL t <= 0 STEP { SET t TO t - 1. } DO {
        PRINT label + " " + t + "s   " AT (0, 15).
        WAIT 1.
    }
}
