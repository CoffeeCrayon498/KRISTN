// ══════════════════════════════════════════════════════════
// KRISTN - TANKER MISSION ORCHESTRATOR
// mission_tanker.ks — Full tanker run: launch → dock → transfer → deorbit → land
// For: WORKHORSE Heavy Lift Tanker
// ══════════════════════════════════════════════════════════
@LAZYGLOBAL OFF.
RUNONCEPATH("0:/gui_lib.ks").

CLEARSCREEN.
PRINT "╔══════════════════════════════════════╗".
PRINT "║    KRISTN TANKER RUN - AUTOMATED    ║".
PRINT "╚══════════════════════════════════════╝".
PRINT " ".

// ── Pre-flight checks ──
IF NOT HASTARGET {
    PRINT "ERROR: No target selected!".
    PRINT "Select Gateway (Kerbin Station) as target.".
    PRINT "Then re-run this script.".
    WAIT 5.
    RETURN.
}

PRINT "Target: " + TARGET:NAME.
PRINT "Ship:   " + SHIP:NAME.
PRINT "Mass:   " + ROUND(SHIP:MASS, 1) + " t".
PRINT "dV:     ~" + ROUND(calc_dv()) + " m/s".
PRINT " ".

// ── Confirm ──
PRINT "Starting full tanker run in 5 seconds...".
PRINT "(Switch to another program from boot menu to cancel)".
gui_countdown(5, "Mission start in").

// ══════════════════════════════════════
// STEP 1: LAUNCH TO ORBIT
// ══════════════════════════════════════
PRINT " ".
PRINT "═══ STEP 1/5: LAUNCH TO ORBIT ═══".
RUNPATH("0:/launch.ks").
WAIT 3.

// Verify orbit
IF PERIAPSIS < 70000 {
    PRINT "WARNING: Orbit may not be stable.".
    PRINT "Peri: " + ROUND(PERIAPSIS) + " m".
    PRINT "Attempting to continue...".
}

// ══════════════════════════════════════
// STEP 2: RENDEZVOUS & DOCK
// ══════════════════════════════════════
CLEARSCREEN.
PRINT "═══ STEP 2/5: RENDEZVOUS & DOCK ═══".
RUNPATH("0:/rendezvous.ks").
WAIT 3.

// Verify docking
LOCAL docked IS FALSE.
FOR p IN SHIP:DOCKINGPORTS {
    IF p:STATE:CONTAINS("Docked") {
        SET docked TO TRUE.
    }
}

IF NOT docked {
    PRINT "WARNING: Docking may not have completed.".
    PRINT "Check manually and run fuel_transfer.ks separately.".
    WAIT 10.
    RETURN.
}

// ══════════════════════════════════════
// STEP 3: FUEL TRANSFER
// ══════════════════════════════════════
CLEARSCREEN.
PRINT "═══ STEP 3/5: FUEL TRANSFER ═══".
RUNPATH("0:/fuel_transfer.ks").
WAIT 5.

// ══════════════════════════════════════
// STEP 4: DEORBIT & LAND
// ══════════════════════════════════════
CLEARSCREEN.
PRINT "═══ STEP 4/5: DEORBIT & LANDING ═══".
RUNPATH("0:/deorbit.ks").
WAIT 3.

// ══════════════════════════════════════
// STEP 5: MISSION COMPLETE
// ══════════════════════════════════════
CLEARSCREEN.
PRINT "╔══════════════════════════════════════╗".
PRINT "║    TANKER RUN COMPLETE!              ║".
PRINT "╚══════════════════════════════════════╝".
PRINT " ".
PRINT "Location: " + ROUND(SHIP:GEOPOSITION:LAT, 2) + " lat".
PRINT "          " + ROUND(SHIP:GEOPOSITION:LNG, 2) + " lng".
PRINT "dV remaining: ~" + ROUND(calc_dv()) + " m/s".
PRINT " ".
PRINT "Recover vessel and prepare for next run.".
