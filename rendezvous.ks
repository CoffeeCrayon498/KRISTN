// ══════════════════════════════════════════════════════════
// KRISTN - RENDEZVOUS & DOCKING SCRIPT
// rendezvous.ks — Approach, close-in, and automated docking
// For: WORKHORSE docking at Kerbin Station (Gateway)
// ══════════════════════════════════════════════════════════
@LAZYGLOBAL OFF.
RUNONCEPATH("0:/gui_lib.ks").

// ── Check for target ──
IF NOT HASTARGET {
    PRINT "ERROR: No target selected.".
    PRINT "Select Gateway station as target, then re-run.".
    WAIT 3.
    RETURN.
}

LOCAL tgt IS TARGET.
gui_status("Target: " + tgt:NAME).

// ══════════════════════════════════════
// PHASE 1: HOHMANN TRANSFER TO TARGET
// ══════════════════════════════════════

// Only do transfer if we're far away
LOCAL dist IS (tgt:POSITION - SHIP:POSITION):MAG.
IF dist > 10000 {
    gui_status("Planning transfer to target...").

    // Calculate phase angle and create transfer node
    // Simple Hohmann: match orbits first
    LOCAL target_alt IS tgt:ALTITUDE.
    LOCAL ship_alt IS ALTITUDE.

    // Transfer dV (simplified Hohmann)
    LOCAL r1 IS BODY:RADIUS + ship_alt.
    LOCAL r2 IS BODY:RADIUS + target_alt.
    LOCAL transfer_sma IS (r1 + r2) / 2.
    LOCAL dv1 IS SQRT(BODY:MU / r1) * (SQRT(2 * r2 / (r1 + r2)) - 1).

    // Find optimal transfer time (when target is at right phase angle)
    LOCAL transfer_time IS CONSTANT:PI * SQRT(transfer_sma^3 / BODY:MU).
    LOCAL target_angular_v IS SQRT(BODY:MU / r2^3).
    LOCAL ship_angular_v IS SQRT(BODY:MU / r1^3).

    LOCAL phase_angle IS (target_angular_v - ship_angular_v) * transfer_time.
    LOCAL current_phase IS VANG(tgt:POSITION - BODY:POSITION, SHIP:POSITION - BODY:POSITION).

    // Create node at next opportunity
    // For same-altitude orbits (both at ~100km), use close approach timing
    IF ABS(target_alt - ship_alt) < 5000 {
        // Already close in altitude, plan a phasing orbit instead
        gui_status("Similar orbits - planning phasing...").

        // Calculate relative position
        LOCAL rel_vel IS tgt:VELOCITY:ORBIT - SHIP:VELOCITY:ORBIT.
        LOCAL closing IS VDOT(rel_vel, (tgt:POSITION - SHIP:POSITION):NORMALIZED).

        // Simple approach: small prograde/retrograde burns to close distance
        // This is handled in Phase 2
    } ELSE {
        LOCAL transfer_node IS NODE(TIME:SECONDS + 60, 0, 0, dv1).
        ADD transfer_node.
        gui_status("Transfer node created: " + ROUND(dv1, 1) + " m/s").
        PRINT "Execute node_executor.ks to perform transfer.".
        PRINT "Then re-run rendezvous.ks for close approach.".
        WAIT 5.
        RETURN.
    }
}

// ══════════════════════════════════════
// PHASE 2: CLOSE APPROACH (~10 km to 200m)
// ══════════════════════════════════════
gui_status("Close approach phase...").
SAS OFF.
RCS ON.

LOCAL approach_done IS FALSE.
UNTIL approach_done {
    LOCAL rel_pos IS tgt:POSITION - SHIP:POSITION.
    LOCAL dist IS rel_pos:MAG.
    LOCAL rel_vel IS tgt:VELOCITY:ORBIT - SHIP:VELOCITY:ORBIT.
    LOCAL closing_speed IS -VDOT(rel_vel, rel_pos:NORMALIZED).

    gui_telemetry("APPROACH").
    PRINT "Distance: " + ROUND(dist) + " m   " AT (0, 11).
    PRINT "Closing:  " + ROUND(closing_speed, 1) + " m/s   " AT (0, 12).

    // Target approach speed based on distance
    LOCAL target_speed IS 0.
    IF dist > 5000 { SET target_speed TO 50. }
    ELSE IF dist > 1000 { SET target_speed TO 20. }
    ELSE IF dist > 500 { SET target_speed TO 10. }
    ELSE IF dist > 200 { SET target_speed TO 5. }
    ELSE { SET target_speed TO 1. }

    // Steer toward target
    LOCAL approach_dir IS rel_pos:NORMALIZED.
    LOCK STEERING TO LOOKDIRUP(approach_dir, SHIP:UP:FOREVECTOR).

    // Speed control
    LOCAL speed_error IS target_speed - closing_speed.
    IF ABS(speed_error) > 0.5 {
        IF speed_error > 0 {
            // Need to speed up toward target
            LOCK THROTTLE TO MIN(0.2, speed_error / 20).
        } ELSE {
            // Need to slow down — point retrograde relative to target
            LOCK STEERING TO LOOKDIRUP(-rel_vel:NORMALIZED, SHIP:UP:FOREVECTOR).
            LOCK THROTTLE TO MIN(0.2, ABS(speed_error) / 20).
        }
    } ELSE {
        LOCK THROTTLE TO 0.
    }

    IF dist < 200 AND ABS(closing_speed) < 2 {
        SET approach_done TO TRUE.
    }

    WAIT 0.
}

LOCK THROTTLE TO 0.
gui_status("Close approach complete - 200m hold").

// ══════════════════════════════════════
// PHASE 3: KILL RELATIVE VELOCITY
// ══════════════════════════════════════
gui_status("Killing relative velocity...").

LOCAL kill_done IS FALSE.
UNTIL kill_done {
    LOCAL rel_vel IS tgt:VELOCITY:ORBIT - SHIP:VELOCITY:ORBIT.
    LOCAL rel_speed IS rel_vel:MAG.

    IF rel_speed < 0.2 {
        SET kill_done TO TRUE.
    } ELSE {
        LOCK STEERING TO LOOKDIRUP(-rel_vel:NORMALIZED, SHIP:UP:FOREVECTOR).
        WAIT UNTIL VANG(SHIP:FACING:FOREVECTOR, -rel_vel:NORMALIZED) < 5.
        LOCK THROTTLE TO MIN(0.05, rel_speed / 10).
    }
    WAIT 0.
}
LOCK THROTTLE TO 0.
gui_status("Relative velocity zeroed.").

// ══════════════════════════════════════
// PHASE 4: DOCKING APPROACH
// ══════════════════════════════════════
gui_status("Docking approach...").

// Find docking ports
LOCAL my_port IS SHIP:DOCKINGPORTS[0].
LOCAL tgt_ports IS tgt:DOCKINGPORTS.

IF tgt_ports:LENGTH = 0 {
    PRINT "ERROR: No docking ports found on target!".
    UNLOCK STEERING.
    UNLOCK THROTTLE.
    RETURN.
}

// Find the closest target docking port
LOCAL tgt_port IS tgt_ports[0].
LOCAL closest_dist IS (tgt_ports[0]:NODEPOSITION - my_port:NODEPOSITION):MAG.
FOR p IN tgt_ports {
    LOCAL d IS (p:NODEPOSITION - my_port:NODEPOSITION):MAG.
    IF d < closest_dist {
        SET tgt_port TO p.
        SET closest_dist TO d.
    }
}

gui_status("Docking with: " + tgt_port:NAME).

// ── Docking alignment and approach loop ──
LOCAL docking_done IS FALSE.
UNTIL docking_done {
    // Vector from our port to target port
    LOCAL port_vec IS tgt_port:NODEPOSITION - my_port:NODEPOSITION.
    LOCAL port_dist IS port_vec:MAG.

    // Target port facing direction (we need to approach opposite to it)
    LOCAL approach_dir IS -tgt_port:PORTFACING:FOREVECTOR.

    // Desired position: offset along approach vector
    LOCAL offset_dist IS MIN(port_dist, 50).
    LOCAL desired_pos IS tgt_port:NODEPOSITION + approach_dir * offset_dist.
    LOCAL correction IS desired_pos - my_port:NODEPOSITION.

    gui_telemetry("DOCKING").
    PRINT "Port dist: " + ROUND(port_dist, 1) + " m   " AT (0, 11).

    // Align our port facing opposite to target port facing
    LOCAL desired_facing IS -tgt_port:PORTFACING:FOREVECTOR.
    LOCK STEERING TO LOOKDIRUP(desired_facing, SHIP:UP:FOREVECTOR).

    // Use RCS for translation
    LOCAL lateral_error IS VXCL(approach_dir, port_vec).
    LOCAL approach_speed IS VDOT(port_vec:NORMALIZED, tgt:VELOCITY:ORBIT - SHIP:VELOCITY:ORBIT).

    // Final approach
    IF port_dist < 50 AND lateral_error:MAG < 2 {
        // Aligned, creep in
        LOCAL desired_speed IS MAX(0.3, port_dist / 50).
        SET SHIP:CONTROL:FORE TO (desired_speed - approach_speed) * 0.5.
    } ELSE IF lateral_error:MAG > 1 {
        // Fix lateral offset with RCS
        SET SHIP:CONTROL:STARBOARD TO VDOT(lateral_error, SHIP:FACING:STARVECTOR) * 0.2.
        SET SHIP:CONTROL:TOP TO VDOT(lateral_error, SHIP:FACING:TOPVECTOR) * 0.2.
    }

    // Check if docked
    IF my_port:STATE:CONTAINS("Docked") OR my_port:STATE:CONTAINS("PreAttached") {
        SET docking_done TO TRUE.
    }

    // Timeout safety
    IF port_dist < 1 {
        WAIT 2.
        IF my_port:STATE:CONTAINS("Docked") OR my_port:STATE:CONTAINS("PreAttached") {
            SET docking_done TO TRUE.
        }
    }

    WAIT 0.
}

// ── Cleanup ──
SET SHIP:CONTROL:NEUTRALIZE TO TRUE.
LOCK THROTTLE TO 0.
UNLOCK STEERING.
RCS OFF.
SAS ON.

CLEARSCREEN.
gui_telemetry("DOCKED").
gui_status("Successfully docked with " + tgt:NAME).
PRINT "Docking complete!" AT (0, 13).
