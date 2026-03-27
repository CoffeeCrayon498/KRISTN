// ══════════════════════════════════════════════════════════
// KRISTN - MANEUVER NODE EXECUTOR
// node_executor.ks — Precision node burner
// Supports: Persistent Thrust for long burns
// ══════════════════════════════════════════════════════════
@LAZYGLOBAL OFF.
RUNONCEPATH("0:/gui_lib.ks").

LOCAL g0 IS 9.80665.

// ── Check for a node ──
IF NOT HASNODE {
    gui_status("ERROR: No maneuver node found.").
    PRINT "Create a node first, then run this script.".
    WAIT 3.
    RETURN.
}

LOCAL nd IS NEXTNODE.
LOCAL dv_needed IS nd:DELTAV:MAG.

gui_telemetry("NODE EXECUTOR").
gui_status("Node dV: " + ROUND(dv_needed, 1) + " m/s").

// ── Calculate burn time ──
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
    // Engine not active, try to find max available
    FOR e IN eng_list {
        SET total_thrust TO total_thrust + e:POSSIBLETHRUST.
        SET weighted_isp TO weighted_isp + e:POSSIBLETHRUST * e:VACUUMISP.
    }
}
LOCAL avg_isp IS weighted_isp / MAX(total_thrust, 0.001).
LOCAL exhaust_v IS avg_isp * g0.
LOCAL mass_ratio IS CONSTANT:E ^ (dv_needed / exhaust_v).
LOCAL fuel_mass IS SHIP:MASS * (1 - 1/mass_ratio).
LOCAL flow_rate IS total_thrust / exhaust_v.
LOCAL burn_time IS fuel_mass / MAX(flow_rate, 0.001).
LOCAL half_burn IS burn_time / 2.

gui_status("Burn time: " + ROUND(burn_time, 1) + "s").
PRINT "Half-burn: " + ROUND(half_burn, 1) + "s" AT (0, 12).

// ── Orient to burn vector ──
SAS OFF.
LOCK STEERING TO nd:BURNVECTOR.
gui_status("Orienting to burn vector...").

LOCAL orient_timeout IS TIME:SECONDS + 60.
WAIT UNTIL VANG(SHIP:FACING:FOREVECTOR, nd:BURNVECTOR) < 1.5 OR TIME:SECONDS > orient_timeout.
gui_status("Aligned.").

// ── Warp to burn start ──
LOCAL burn_start_ut IS TIME:SECONDS + nd:ETA - half_burn.
IF nd:ETA > half_burn + 60 {
    gui_status("Warping to burn start...").
    KUNIVERSE:TIMEWARP:WARPTO(burn_start_ut - 15).
    WAIT UNTIL nd:ETA <= half_burn + 20.
    KUNIVERSE:TIMEWARP:CANCELWARP().
    WAIT UNTIL SHIP:UNPACKED.
    WAIT 2.
    // Re-align after warp
    LOCK STEERING TO nd:BURNVECTOR.
    WAIT UNTIL VANG(SHIP:FACING:FOREVECTOR, nd:BURNVECTOR) < 2.
}

// ── Wait for burn start ──
gui_status("Waiting for burn start...").
WAIT UNTIL nd:ETA <= half_burn + 0.5.

// ── EXECUTE BURN ──
gui_status("BURNING").
LOCK THROTTLE TO 1.0.

// Track the initial burn vector to detect completion
LOCAL initial_dv IS nd:DELTAV.
LOCAL done_burn IS FALSE.

UNTIL done_burn {
    gui_telemetry("NODE BURN").

    LOCAL remaining_dv IS nd:DELTAV:MAG.

    // Show remaining dV
    PRINT "Remaining: " + ROUND(remaining_dv, 1) + " m/s   " AT (0, 11).

    // Throttle down for precision as we approach completion
    IF remaining_dv < 30 {
        LOCK THROTTLE TO MAX(0.02, remaining_dv / 30).
    }

    // Completion checks
    IF remaining_dv < 0.15 {
        SET done_burn TO TRUE.
    }

    // Check if we've passed the node (burn vector flipped)
    IF VDOT(initial_dv, nd:DELTAV) < 0 {
        SET done_burn TO TRUE.
    }

    WAIT 0.
}

LOCK THROTTLE TO 0.
UNLOCK STEERING.

// ── Cleanup ──
REMOVE nd.
SAS ON.

gui_telemetry("NODE COMPLETE").
LOCAL final_apo IS ROUND(APOAPSIS).
LOCAL final_peri IS ROUND(PERIAPSIS).
gui_status("Done. Apo: " + final_apo + " Peri: " + final_peri).
PRINT "Node execution complete." AT (0, 13).
