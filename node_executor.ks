// ============================================================
// KRISTN AUTOPILOT — node_executor.ks
// Precision maneuver node burner
// ============================================================
@LAZYGLOBAL OFF.
RUNONCEPATH("0:/lib_common.ks").

CLEARSCREEN.
PRINT "╔════════════════════════════════════════════════╗".
PRINT "║        MANEUVER NODE EXECUTOR                  ║".
PRINT "╚════════════════════════════════════════════════╝".

IF NOT HASNODE {
    PRINT " ".
    PRINT " [!] No maneuver node set. Create one first.".
    PRINT "     Returning to menu...".
    WAIT 3.
    RETURN.  // SAFE: we are inside RUNPATH context
}

LOCAL nd IS NEXTNODE.
LOCAL dv IS nd:DELTAV:MAG.
LOCAL bt IS ks_burn_time(dv).
LOCAL half_bt IS bt / 2.

PRINT " ".
PRINT " Node ΔV: " + ROUND(dv, 1) + " m/s".
PRINT " Est. burn time: " + ROUND(bt, 1) + " s".
PRINT " Time to node: " + ROUND(nd:ETA) + " s".
PRINT " ".

// Warp to burn start
LOCAL burn_start_eta IS nd:ETA - half_bt - 30. // 30s early for settling
IF burn_start_eta > 60 {
    PRINT " Warping to burn window...".
    WARPTO(TIME:SECONDS + burn_start_eta).
}

// Point at maneuver
RCS ON.
SAS OFF.
LOCK STEERING TO nd:DELTAV.
PRINT " Aligning to burn vector...".

// Wait for alignment (within 1 degree)
LOCAL align_timeout IS TIME:SECONDS + 60.
UNTIL VANG(SHIP:FACING:FOREVECTOR, nd:DELTAV) < 1 OR TIME:SECONDS > align_timeout {
    PRINT " Alignment error: " + ROUND(VANG(SHIP:FACING:FOREVECTOR, nd:DELTAV), 1) + "°   " AT(0, 12).
    WAIT 0.1.
}

// Wait for precise burn start (half burn time before node)
PRINT " Waiting for burn start...                   " AT(0, 12).
UNTIL nd:ETA <= half_bt {
    PRINT " T-burn: " + ROUND(nd:ETA - half_bt, 1) + "s   " AT(0, 13).
    WAIT 0.1.
}

// ── EXECUTE BURN ────────────────────────────────────
PRINT " BURNING                                     " AT(0, 12).
ks_log("NODE: Executing node burn, ΔV=" + ROUND(dv,1)).

LOCAL dv0 IS nd:DELTAV.
LOCK THROTTLE TO 1.

UNTIL FALSE {
    // Check if we've overshot (burn vector flipped >90° from original)
    IF VDOT(dv0, nd:DELTAV) <= 0 {
        PRINT " Node complete (vector flip detected).   " AT(0, 13).
        BREAK.
    }
    // Check remaining dv
    IF nd:DELTAV:MAG < 0.1 {
        PRINT " Node complete (ΔV < 0.1 m/s).          " AT(0, 13).
        BREAK.
    }

    // Throttle proportional to remaining dv
    LOCAL remaining IS nd:DELTAV:MAG.
    IF remaining < 10 {
        LOCK THROTTLE TO MAX(0.01, remaining / 10).
    }

    // Re-point at remaining dv vector
    LOCK STEERING TO nd:DELTAV.

    PRINT " ΔV remaining: " + ROUND(nd:DELTAV:MAG, 2) + " m/s   Thr: " + ROUND(THROTTLE*100) + "%   " AT(0, 14).
    WAIT 0.05.
}

LOCK THROTTLE TO 0.
UNLOCK STEERING.
UNLOCK THROTTLE.
RCS OFF.
REMOVE NEXTNODE.

PRINT " ".
PRINT " ── Node execution complete ──".
PRINT " Apoapsis:  " + ROUND(SHIP:APOAPSIS/1000, 1) + " km".
PRINT " Periapsis: " + ROUND(SHIP:PERIAPSIS/1000, 1) + " km".
ks_log("NODE: Complete — orbit " + ROUND(SHIP:APOAPSIS/1000,1) + "x" + ROUND(SHIP:PERIAPSIS/1000,1) + "km").
