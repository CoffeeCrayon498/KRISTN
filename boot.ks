// ============================================================
// KRISTN AUTOPILOT — boot.ks
// Mk-34 Workhorse — Mk33 Spaceplane SSTO
// Boot menu + flight recorder auto-start
// ============================================================
@LAZYGLOBAL OFF.

CLEARSCREEN.
SET TERMINAL:WIDTH TO 50.
SET TERMINAL:HEIGHT TO 35.

PRINT "╔════════════════════════════════════════════════╗".
PRINT "║   KRISTN — Mk-34 Workhorse Autopilot Suite    ║".
PRINT "║   Kerbal Reusable Interstellar Space Transport ║".
PRINT "╚════════════════════════════════════════════════╝".
PRINT " ".
PRINT " Ship: " + SHIP:NAME.
PRINT " Mass: " + ROUND(SHIP:MASS, 1) + "t".
PRINT " Status: " + SHIP:STATUS.
PRINT " ".

// Auto-start flight recorder in background
LOCAL recorderRunning IS FALSE.
IF EXISTS("0:/flight_recorder.ks") {
    RUN "0:/flight_recorder.ks".
    SET recorderRunning TO TRUE.
    PRINT " [✓] Flight recorder started.".
} ELSE {
    PRINT " [!] flight_recorder.ks not found — skipping.".
}

PRINT " ".
PRINT " ── MISSION PROGRAMS ──────────────────────────".
PRINT " ".
PRINT "  1 ─ Launch to Orbit".
PRINT "  2 ─ Execute Maneuver Node".
PRINT "  3 ─ Rendezvous + Docking".
PRINT "  4 ─ Fuel Transfer (dump cargo)".
PRINT "  5 ─ Deorbit + Runway Landing".
PRINT "  6 ─ Full Tanker Run (auto)".
PRINT " ".
PRINT "  7 ─ GUI Telemetry Display".
PRINT "  8 ─ Ship Status Check".
PRINT "  0 ─ Exit kOS".
PRINT " ".
PRINT " ─────────────────────────────────────────────".

LOCAL choice IS 0.
LOCAL running IS TRUE.

UNTIL NOT running {
    PRINT "Select program > " AT(0, 30).
    SET choice TO TERMINAL:INPUT:GETCHAR().
    PRINT choice AT (18, 30).

    IF choice = "1" {
        RUNPATH("0:/launch.ks").
    } ELSE IF choice = "2" {
        RUNPATH("0:/node_executor.ks").
    } ELSE IF choice = "3" {
        RUNPATH("0:/rendezvous.ks").
    } ELSE IF choice = "4" {
        RUNPATH("0:/fuel_transfer.ks").
    } ELSE IF choice = "5" {
        RUNPATH("0:/deorbit.ks").
    } ELSE IF choice = "6" {
        RUNPATH("0:/mission_tanker.ks").
    } ELSE IF choice = "7" {
        RUNPATH("0:/gui_lib.ks").
    } ELSE IF choice = "8" {
        RUNPATH("0:/ship_status.ks").
    } ELSE IF choice = "0" {
        SET running TO FALSE.
        PRINT " ".
        PRINT "kOS shutting down. Safe travels, Kerbal.".
    }
}
