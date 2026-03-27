// ══════════════════════════════════════════════════════════
// KRISTN - WORKHORSE BOOT SCRIPT v2
// boot.ks — Main menu, mission launcher, auto flight recorder
// Ship: WORKHORSE Heavy Lift Tanker (32 parts, ~290t)
// Parameters tuned from flight F244 data analysis
// ══════════════════════════════════════════════════════════
@LAZYGLOBAL OFF.

CLEARSCREEN.
PRINT "╔══════════════════════════════════════╗".
PRINT "║   KRISTN WORKHORSE FLIGHT COMPUTER  ║".
PRINT "║   Kerbal Reusable Interstellar       ║".
PRINT "║   Space Transportation Network       ║".
PRINT "╚══════════════════════════════════════╝".
PRINT " ".

// ── Ship Parameters (tuned from F244 flight data) ──
// F244 lessons:
//   - Ship TWR starts at 1.32 and climbs to 5.8 as fuel burns
//   - Turn was too late, AoA hit 45° (should stay under 5°)
//   - Apoapsis overshot to 612km (throttle never cut)
//   - No circ burn happened
GLOBAL SHIP_NAME IS "WORKHORSE".
GLOBAL TARGET_ORBIT IS 100000.       // 100 km LKO
GLOBAL TARGET_INCL IS 0.            // Equatorial
GLOBAL TURN_START_ALT IS 100.       // Start turn early (was 250, ship is slow off pad at 1.32 TWR)
GLOBAL TURN_END_ALT IS 55000.       // End turn at 55km (gives more room for gradual turn)
GLOBAL MAX_TWR IS 1.8.              // Cap TWR during ascent (ship climbs to 5.8 uncapped)
GLOBAL MAX_AOA IS 5.                // Never exceed 5° AoA (F244 hit 45°!)
GLOBAL AUTO_STAGE IS FALSE.         // Single stage
GLOBAL LANDING_DV_RESERVE IS 350.   // m/s for deorbit + propulsive landing

// ── Wait for physics ──
WAIT UNTIL SHIP:UNPACKED.
WAIT 1.

// ── Start flight recorder (always on) ──
RUNONCEPATH("0:/flight_recorder.ks").
PRINT "Flight recorder: ACTIVE".
PRINT "Flight ID: " + flight_id.
PRINT "Log: " + recorder_logfile.
PRINT " ".

PRINT "Ship: " + SHIP:NAME.
PRINT "Mass: " + ROUND(SHIP:MASS, 1) + " t".
PRINT "Parts: " + SHIP:PARTS:LENGTH.
PRINT " ".

// ── Mission Menu ──
LOCAL done IS FALSE.
UNTIL done {
    PRINT "═══ MISSION SELECT ═══".
    PRINT "1: Full Tanker Run (launch>dock>transfer>deorbit>land)".
    PRINT "2: Launch to Orbit only".
    PRINT "3: Rendezvous & Dock with target".
    PRINT "4: Fuel Transfer (while docked)".
    PRINT "5: Deorbit & Land".
    PRINT "6: Execute next maneuver node".
    PRINT "7: Manual flight (recorder only)".
    PRINT "0: Exit".
    PRINT " ".

    LOCAL choice IS "".
    UNTIL choice <> "" {
        IF TERMINAL:INPUT:HASCHAR {
            SET choice TO TERMINAL:INPUT:GETCHAR().
        }
        WAIT 0.
    }

    IF choice = "1" {
        set_flight_label("TANKER_RUN").
        PRINT ">> [" + flight_id + "] Starting Full Tanker Run...".
        RUNPATH("0:/mission_tanker.ks").
        SET done TO TRUE.
    } ELSE IF choice = "2" {
        set_flight_label("LAUNCH_ONLY").
        PRINT ">> [" + flight_id + "] Starting Launch Sequence...".
        RUNPATH("0:/launch.ks").
        SET done TO TRUE.
    } ELSE IF choice = "3" {
        set_flight_label("RENDEZVOUS").
        PRINT ">> [" + flight_id + "] Starting Rendezvous...".
        RUNPATH("0:/rendezvous.ks").
        SET done TO TRUE.
    } ELSE IF choice = "4" {
        set_flight_label("FUEL_TRANSFER").
        PRINT ">> [" + flight_id + "] Starting Fuel Transfer...".
        RUNPATH("0:/fuel_transfer.ks").
        SET done TO TRUE.
    } ELSE IF choice = "5" {
        set_flight_label("DEORBIT_LAND").
        PRINT ">> [" + flight_id + "] Starting Deorbit...".
        RUNPATH("0:/deorbit.ks").
        SET done TO TRUE.
    } ELSE IF choice = "6" {
        set_flight_label("NODE_EXEC").
        PRINT ">> [" + flight_id + "] Executing Maneuver Node...".
        RUNPATH("0:/node_executor.ks").
        SET done TO TRUE.
    } ELSE IF choice = "7" {
        set_flight_label("MANUAL").
        PRINT ">> [" + flight_id + "] Manual flight - recorder running.".
        PRINT "Fly manually. Recorder will log everything.".
        PRINT "Type SET recorder_active TO FALSE. to stop recording.".
        SET done TO TRUE.
    } ELSE IF choice = "0" {
        SET recorder_active TO FALSE.
        PRINT ">> Recorder stopped. Samples: " + recorder_samples.
        PRINT ">> Exiting. Safe travels.".
        SET done TO TRUE.
    } ELSE {
        PRINT "Invalid selection.".
    }
}
