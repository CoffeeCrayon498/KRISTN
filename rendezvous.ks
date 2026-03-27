// ============================================================
// KRISTN AUTOPILOT — rendezvous.ks
// Approach + docking autopilot for Mk-34 Workhorse
// Assumes target is already set and in similar orbit
// ============================================================
@LAZYGLOBAL OFF.
RUNONCEPATH("0:/lib_common.ks").

CLEARSCREEN.
PRINT "╔════════════════════════════════════════════════╗".
PRINT "║      RENDEZVOUS + DOCKING AUTOPILOT            ║".
PRINT "╚════════════════════════════════════════════════╝".
PRINT " ".

IF NOT HASTARGET {
    PRINT " [!] No target set. Select a target vessel first.".
    WAIT 3.
    RETURN.
}

PRINT " Target: " + TARGET:NAME.
PRINT " Distance: " + ROUND(TARGET:DISTANCE/1000, 1) + " km".
PRINT " ".

// ── CONFIGURATION ───────────────────────────────────
LOCAL CLOSE_APPROACH_DIST IS 200.  // meters — switch to docking mode
LOCAL DOCK_APPROACH_SPEED IS 1.    // m/s final approach
LOCAL KILL_DIST IS 50.             // meters — switch to creep
LOCAL CREEP_SPEED IS 0.3.          // m/s — final docking
LOCAL DOCK_CAPTURE_DIST IS 5.      // meters — let magnets grab

// ── PHASE 1: HOHMANN TRANSFER (if >10km away) ──────
LOCAL dist IS TARGET:DISTANCE.
IF dist > 10000 {
    PRINT "Phase 1: Hohmann transfer to target orbit...".
    ks_log("RDV: Hohmann transfer, dist=" + ROUND(dist/1000,1) + "km").

    // Match target orbit altitude first
    LOCAL target_alt IS TARGET:ORBIT:SEMIMAJORAXIS - BODY:RADIUS.
    LOCAL dv_pair IS ks_hohmann_dv(target_alt).

    // Create burn node at next appropriate point
    LOCAL node_time IS TIME:SECONDS + 60.
    LOCAL nd IS NODE(node_time, 0, 0, dv_pair[0]).
    ADD nd.
    PRINT " Transfer ΔV: " + ROUND(dv_pair[0], 1) + " m/s".
    RUNPATH("0:/node_executor.ks").

    // Wait for arrival near target orbit, then circularize
    WAIT 5.
    IF HASNODE { RUNPATH("0:/node_executor.ks"). }
}

// ── PHASE 2: CLOSE APPROACH ────────────────────────
PRINT " ".
PRINT "Phase 2: Close approach                     " AT(0, 12).
ks_log("RDV: Close approach phase").

RCS ON.
SAS OFF.

// Kill relative velocity first
LOCK STEERING TO (-1) * TARGET:VELOCITY:ORBIT + SHIP:VELOCITY:ORBIT.
WAIT 2.

// Point at target and thrust gently
UNTIL TARGET:DISTANCE < CLOSE_APPROACH_DIST {
    LOCAL rel_vel IS (TARGET:VELOCITY:ORBIT - SHIP:VELOCITY:ORBIT):MAG.
    LOCAL desired_speed IS MIN(20, TARGET:DISTANCE / 20). // Slow as we approach

    // Point retrograde-relative if going too fast, else at target
    IF rel_vel > desired_speed + 2 {
        // Kill excess velocity
        LOCAL rel_v_vec IS TARGET:VELOCITY:ORBIT - SHIP:VELOCITY:ORBIT.
        LOCK STEERING TO (-1) * rel_v_vec.
        LOCK THROTTLE TO MIN(0.3, (rel_vel - desired_speed) / 10).
    } ELSE IF rel_vel < desired_speed - 1 {
        // Speed up toward target
        LOCAL target_dir IS TARGET:POSITION - SHIP:POSITION.
        LOCK STEERING TO target_dir.
        IF VANG(SHIP:FACING:FOREVECTOR, target_dir:NORMALIZED) < 10 {
            LOCK THROTTLE TO MIN(0.2, (desired_speed - rel_vel) / 10).
        } ELSE {
            LOCK THROTTLE TO 0.
        }
    } ELSE {
        LOCK THROTTLE TO 0.
    }

    PRINT " Dist: " + ROUND(TARGET:DISTANCE) + "m  RelV: " + ROUND(rel_vel,1) + " m/s  Target: " + ROUND(desired_speed,1) + "   " AT(0, 14).
    WAIT 0.1.
}

LOCK THROTTLE TO 0.

// ── PHASE 3: DOCKING ───────────────────────────────
PRINT " ".
PRINT "Phase 3: Docking approach                   " AT(0, 12).
ks_log("RDV: Docking phase at " + ROUND(TARGET:DISTANCE) + "m").

// Find our docking port (Mk33 nose cone port)
LOCAL my_port IS FALSE.
LOCAL all_ports IS SHIP:DOCKINGPORTS.
IF all_ports:LENGTH > 0 {
    SET my_port TO all_ports[0].
    PRINT " Using port: " + my_port:NAME.
}

// Find target docking port
LOCAL target_port IS FALSE.
LOCAL tgt_ports IS TARGET:DOCKINGPORTS.
IF tgt_ports:LENGTH > 0 {
    SET target_port TO tgt_ports[0].
    PRINT " Target port: " + target_port:NAME.
}

// Docking approach using RCS translation
UNTIL TARGET:DISTANCE < DOCK_CAPTURE_DIST {
    LOCAL rel_vel IS (TARGET:VELOCITY:ORBIT - SHIP:VELOCITY:ORBIT):MAG.

    // Aim at target's position (or port if available)
    LOCAL aim_pos IS TARGET:POSITION.
    IF target_port <> FALSE AND target_port:ISTYPE("DockingPort") {
        SET aim_pos TO target_port:NODEPOSITION.
    }

    // Point at target port (opposite of its facing for proper alignment)
    IF target_port <> FALSE AND target_port:ISTYPE("DockingPort") {
        LOCK STEERING TO LOOKDIRUP(-target_port:PORTFACING:FOREVECTOR, SHIP:UP:FOREVECTOR).
    } ELSE {
        LOCK STEERING TO aim_pos.
    }

    // Gentle approach speed — proportional to distance
    LOCAL spd IS DOCK_APPROACH_SPEED.
    IF TARGET:DISTANCE < KILL_DIST {
        SET spd TO CREEP_SPEED.
    }

    // RCS translate toward target
    LOCAL err IS aim_pos:NORMALIZED.
    SET SHIP:CONTROL:FORE TO err:Z * 0.3.
    SET SHIP:CONTROL:STARBOARD TO err:X * 0.3.
    SET SHIP:CONTROL:TOP TO err:Y * 0.3.

    // Speed control — brake if too fast
    IF rel_vel > spd + 0.5 {
        SET SHIP:CONTROL:FORE TO -0.2.
    }

    PRINT " Dist: " + ROUND(TARGET:DISTANCE, 1) + "m  Speed: " + ROUND(rel_vel, 2) + " m/s   " AT(0, 14).
    WAIT 0.1.
}

// Kill all inputs
SET SHIP:CONTROL:FORE TO 0.
SET SHIP:CONTROL:STARBOARD TO 0.
SET SHIP:CONTROL:TOP TO 0.
SET SHIP:CONTROL:NEUTRALIZE TO TRUE.
LOCK THROTTLE TO 0.
UNLOCK STEERING.
UNLOCK THROTTLE.
RCS OFF.

PRINT " ".
PRINT "╔════════════════════════════════════════════════╗".
PRINT "║          DOCKING COMPLETE                      ║".
PRINT "╚════════════════════════════════════════════════╝".
ks_log("RDV: Docking complete with " + TARGET:NAME).
