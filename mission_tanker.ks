// ============================================================
// KRISTN AUTOPILOT — mission_tanker.ks
// Full automated tanker run:
//   Launch → Orbit → Rendezvous → Dock → Transfer → Undock
//   → Deorbit → Runway Landing
// ============================================================
@LAZYGLOBAL OFF.
RUNONCEPATH("0:/lib_common.ks").

CLEARSCREEN.
PRINT "╔════════════════════════════════════════════════╗".
PRINT "║     FULL TANKER RUN — AUTOMATED MISSION        ║".
PRINT "║     Mk-34 Workhorse → Kerbin Station           ║".
PRINT "╚════════════════════════════════════════════════╝".
PRINT " ".

IF NOT HASTARGET {
    PRINT " [!] No target set!".
    PRINT "     Set target to Kerbin Station before running.".
    PRINT "     Aborting mission.".
    WAIT 5.
    RETURN.
}

PRINT " Target: " + TARGET:NAME.
PRINT " ".
PRINT " Mission plan:".
PRINT "   1. Launch to " + ROUND(TARGET:ORBIT:APOAPSIS/1000) + "km orbit".
PRINT "   2. Phase + rendezvous with " + TARGET:NAME.
PRINT "   3. Dock".
PRINT "   4. Transfer LH2 cargo".
PRINT "   5. Undock".
PRINT "   6. Deorbit + land at KSC".
PRINT " ".
PRINT " Starting in 10 seconds... (press any key to abort)".

LOCAL abort IS FALSE.
FROM { LOCAL t IS 10. } UNTIL t <= 0 STEP { SET t TO t - 1. } DO {
    PRINT " T-" + t + "...   " AT(0, 14).
    IF TERMINAL:INPUT:HASCHAR {
        SET abort TO TRUE.
        BREAK.
    }
    WAIT 1.
}

IF abort {
    PRINT " Mission aborted by user.".
    RETURN.
}

ks_log("MISSION: Full tanker run started, target=" + TARGET:NAME).

// ═══════════════════════════════════════════════════════
// STEP 1: LAUNCH TO ORBIT
// ═══════════════════════════════════════════════════════
PRINT " ".
PRINT "═══ STEP 1: LAUNCH TO ORBIT ═══════════════════".
ks_log("MISSION: Step 1 — Launch").
RUNPATH("0:/launch.ks").
WAIT 5.

// Verify orbit
IF SHIP:PERIAPSIS < 70000 {
    PRINT " [!] WARNING: Orbit may not be stable (PE < 70km).".
    PRINT "     PE = " + ROUND(SHIP:PERIAPSIS/1000, 1) + "km".
    ks_log("MISSION: WARNING — low periapsis " + ROUND(SHIP:PERIAPSIS/1000,1) + "km").
}

// ═══════════════════════════════════════════════════════
// STEP 2: PHASE TO TARGET + RENDEZVOUS
// ═══════════════════════════════════════════════════════
PRINT " ".
PRINT "═══ STEP 2: RENDEZVOUS + DOCK ════════════════".
ks_log("MISSION: Step 2 — Rendezvous").

// Create Hohmann transfer node to match target orbit
// The rendezvous script handles this
RUNPATH("0:/rendezvous.ks").
WAIT 5.

// ═══════════════════════════════════════════════════════
// STEP 3: FUEL TRANSFER
// ═══════════════════════════════════════════════════════
PRINT " ".
PRINT "═══ STEP 3: FUEL TRANSFER ═══════════════════".
ks_log("MISSION: Step 3 — Fuel transfer").
RUNPATH("0:/fuel_transfer.ks").
WAIT 5.

// ═══════════════════════════════════════════════════════
// STEP 4: UNDOCK
// ═══════════════════════════════════════════════════════
PRINT " ".
PRINT "═══ STEP 4: UNDOCK ═══════════════════════════".
ks_log("MISSION: Step 4 — Undock").

// Find docked port and undock
LOCAL undocked IS FALSE.
LOCAL all_ports IS SHIP:DOCKINGPORTS.
FOR p IN all_ports {
    IF p:STATE:CONTAINS("Docked") {
        p:UNDOCK.
        SET undocked TO TRUE.
        PRINT " Undocked from port: " + p:NAME.
        BREAK.
    }
}

IF NOT undocked {
    PRINT " [!] Could not find docked port to undock.".
    PRINT "     Attempting to continue anyway...".
}

// Back away from station
RCS ON.
SET SHIP:CONTROL:FORE TO -0.5.
WAIT 5.
SET SHIP:CONTROL:FORE TO 0.
SET SHIP:CONTROL:NEUTRALIZE TO TRUE.
RCS OFF.

PRINT " Backed away from station. Separation: " + ROUND(TARGET:DISTANCE) + "m".
WAIT 5.

// Small separation burn
LOCK STEERING TO SHIP:RETROGRADE.
WAIT 3.
ks_engines_on().
LOCK THROTTLE TO 0.1.
WAIT 3.
LOCK THROTTLE TO 0.
ks_engines_off().

PRINT " Separation burn complete.".
WAIT 10.

// ═══════════════════════════════════════════════════════
// STEP 5: DEORBIT + LAND
// ═══════════════════════════════════════════════════════
PRINT " ".
PRINT "═══ STEP 5: DEORBIT + LANDING ═══════════════".
ks_log("MISSION: Step 5 — Deorbit + landing").
RUNPATH("0:/deorbit.ks").

// ═══════════════════════════════════════════════════════
// MISSION COMPLETE
// ═══════════════════════════════════════════════════════
PRINT " ".
PRINT "╔════════════════════════════════════════════════╗".
PRINT "║      TANKER MISSION COMPLETE                   ║".
PRINT "║      Mk-34 Workhorse — Ready for next run      ║".
PRINT "╚════════════════════════════════════════════════╝".
ks_log("MISSION: Tanker run complete!").
