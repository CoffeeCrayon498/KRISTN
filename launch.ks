// ============================================================
// KRISTN AUTOPILOT — launch.ks
// Mk-34 Workhorse — Spaceplane SSTO Launch to Orbit
// Mk33 airframe, 4x KR-2200L engines, winged ascent
// ============================================================
// PROFILE: Runway takeoff → climb → gravity turn → closed-cycle
//          push to apoapsis → coast → circularize
// ============================================================
@LAZYGLOBAL OFF.
RUNONCEPATH("0:/lib_common.ks").

CLEARSCREEN.
PRINT "╔════════════════════════════════════════════════╗".
PRINT "║       LAUNCH — Mk-34 Workhorse SSTO           ║".
PRINT "╚════════════════════════════════════════════════╝".
PRINT " ".

// ── CONFIGURATION ───────────────────────────────────
LOCAL TARGET_ORBIT IS 100000.       // 100km target orbit
LOCAL TAKEOFF_SPEED IS 100.         // m/s — rotate speed
LOCAL CLIMB_PITCH IS 20.            // Initial climb pitch (deg)
LOCAL TURN_START_ALT IS 1000.       // Begin pitching over
LOCAL TURN_END_ALT IS 60000.        // End of gravity turn
LOCAL MAX_AOA IS 5.                 // AoA limiter (degrees)
LOCAL MAX_Q_AOA IS 3.              // Tighter AoA during max-Q
LOCAL COAST_SECONDS IS 8.           // Predictive cutoff lead time
LOCAL CIRC_MARGIN IS 500.           // Circularize if apo within margin
LOCAL AUTO_STAGE IS FALSE.          // Mk-34 is single stage

// ── PHASE 0: PRE-LAUNCH ────────────────────────────
PRINT "Phase 0: Pre-launch checks...".
BRAKES ON.
SAS OFF.
RCS OFF.
LOCK THROTTLE TO 0.

// Verify engines
LOCAL eng_count IS ks_active_engine_count().
PRINT " Engines available: " + eng_count.
IF eng_count < 4 {
    PRINT " [!] WARNING: Expected 4 engines, found " + eng_count.
    PRINT "     Proceeding anyway...".
}

PRINT " Mass: " + ROUND(SHIP:MASS, 1) + "t".
PRINT " Target orbit: " + ROUND(TARGET_ORBIT/1000) + "km".
PRINT " ".

// Countdown
FROM { LOCAL t IS 5. } UNTIL t <= 0 STEP { SET t TO t - 1. } DO {
    PRINT " T-" + t + "... " AT(0, 10).
    WAIT 1.
}

// ── PHASE 1: TAKEOFF ROLL ──────────────────────────
PRINT "Phase 1: Takeoff roll                    " AT(0, 10).
ks_log("LAUNCH: Takeoff roll initiated").

BRAKES OFF.
ks_engines_on().
LOCK THROTTLE TO 1.
LOCK STEERING TO HEADING(90, 0).   // Runway heading, flat

// Wait for rotate speed
UNTIL SHIP:AIRSPEED >= TAKEOFF_SPEED {
    PRINT " Speed: " + ROUND(SHIP:AIRSPEED) + " m/s   " AT(0, 12).
    WAIT 0.1.
}

// ── PHASE 2: ROTATE + INITIAL CLIMB ────────────────
PRINT "Phase 2: Rotate — pitch " + CLIMB_PITCH + "°               " AT(0, 10).
ks_log("LAUNCH: Rotate at " + ROUND(SHIP:AIRSPEED) + " m/s").

LOCK STEERING TO HEADING(90, CLIMB_PITCH).
GEAR OFF.

// Climb until turn start altitude
UNTIL ALTITUDE >= TURN_START_ALT {
    PRINT " Alt: " + ROUND(ALTITUDE) + "m  VS: " + ROUND(SHIP:VERTICALSPEED) + " m/s   " AT(0, 12).
    WAIT 0.1.
}

// ── PHASE 3: GRAVITY TURN ──────────────────────────
PRINT "Phase 3: Gravity turn                    " AT(0, 10).
ks_log("LAUNCH: Gravity turn start at " + ROUND(ALTITUDE) + "m").

LOCAL pitch IS CLIMB_PITCH.

UNTIL SHIP:APOAPSIS >= TARGET_ORBIT - 5000 {
    // Smooth pitch schedule based on altitude
    LOCAL turn_pct IS MIN(1, MAX(0, (ALTITUDE - TURN_START_ALT) / (TURN_END_ALT - TURN_START_ALT))).
    SET pitch TO CLIMB_PITCH * (1 - turn_pct).
    
    // AoA limiter — clamp steering to stay near prograde
    LOCAL current_aoa IS ks_aoa().
    LOCAL aoa_limit IS MAX_AOA.
    IF ALTITUDE < 30000 AND SHIP:Q > 0.1 {
        SET aoa_limit TO MAX_Q_AOA.
    }
    
    // If AoA exceeding limit, lerp toward prograde
    IF current_aoa > aoa_limit {
        LOCK STEERING TO SHIP:SRFPROGRADE.
    } ELSE {
        LOCK STEERING TO HEADING(90, MAX(0, pitch)).
    }

    // Throttle management — ease off as apoapsis approaches target
    LOCAL apo_error IS TARGET_ORBIT - SHIP:APOAPSIS.
    IF apo_error < 20000 {
        LOCAL thr IS MAX(0.1, MIN(1, apo_error / 20000)).
        LOCK THROTTLE TO thr.
    } ELSE {
        LOCK THROTTLE TO 1.
    }

    // Telemetry
    PRINT " Alt: " + ROUND(ALTITUDE/1000, 1) + "km  Apo: " + ROUND(SHIP:APOAPSIS/1000, 1) + "km      " AT(0, 12).
    PRINT " Pitch: " + ROUND(pitch, 1) + "°  AoA: " + ROUND(current_aoa, 1) + "°  TWR: " + ROUND(ks_twr(), 2) + "      " AT(0, 13).
    PRINT " Turn: " + ROUND(turn_pct * 100) + "%  Throttle: " + ROUND(THROTTLE * 100) + "%      " AT(0, 14).

    WAIT 0.05.
}

// ── PHASE 4: COAST TO APOAPSIS ─────────────────────
PRINT "Phase 4: Coast to apoapsis               " AT(0, 10).
LOCK THROTTLE TO 0.
LOCK STEERING TO SHIP:PROGRADE.
ks_log("LAUNCH: Apoapsis reached — " + ROUND(SHIP:APOAPSIS/1000, 1) + "km, coasting").

// Fine-tune: if apo is undershooting, tiny burns
UNTIL ETA:APOAPSIS < 30 AND ALTITUDE > 70000 {
    IF SHIP:APOAPSIS < TARGET_ORBIT - 2000 AND ALTITUDE > 50000 {
        LOCK THROTTLE TO 0.05.
    } ELSE {
        LOCK THROTTLE TO 0.
    }
    PRINT " ETA Apo: " + ROUND(ETA:APOAPSIS) + "s  Apo: " + ROUND(SHIP:APOAPSIS/1000,1) + "km   " AT(0, 12).
    PRINT " Alt: " + ROUND(ALTITUDE/1000,1) + "km  Peri: " + ROUND(SHIP:PERIAPSIS/1000,1) + "km   " AT(0, 13).
    WAIT 0.5.
}

// ── PHASE 5: CIRCULARIZATION ───────────────────────
PRINT "Phase 5: Circularization burn             " AT(0, 10).
ks_log("LAUNCH: Circularization burn").

RCS ON.
LOCK STEERING TO SHIP:PROGRADE.
WAIT 2.   // Let steering settle

// Calculate circ dv and burn time
LOCAL dv IS ks_circ_dv().
LOCAL bt IS ks_burn_time(dv).

PRINT " Circ ΔV: " + ROUND(dv, 1) + " m/s   Burn: " + ROUND(bt, 1) + "s   " AT(0, 12).

// Wait until half-burn-time before apoapsis
LOCAL start_time IS ETA:APOAPSIS - bt/2.
IF start_time > 0 {
    PRINT " Waiting " + ROUND(start_time) + "s to start burn...   " AT(0, 13).
    WAIT start_time.
}

// Burn!
LOCAL v0 IS SHIP:VELOCITY:ORBIT:MAG.
LOCAL target_v IS v0 + dv.

LOCK THROTTLE TO 1.
UNTIL SHIP:VELOCITY:ORBIT:MAG >= target_v - 5 OR SHIP:PERIAPSIS >= TARGET_ORBIT - CIRC_MARGIN {
    // Throttle down as we approach target
    LOCAL remaining IS target_v - SHIP:VELOCITY:ORBIT:MAG.
    IF remaining < 20 {
        LOCK THROTTLE TO MAX(0.02, remaining / 20).
    }
    PRINT " ΔV remaining: " + ROUND(target_v - SHIP:VELOCITY:ORBIT:MAG, 1) + " m/s     " AT(0, 13).
    PRINT " Periapsis: " + ROUND(SHIP:PERIAPSIS/1000, 1) + "km                   " AT(0, 14).
    WAIT 0.05.
}

LOCK THROTTLE TO 0.
RCS OFF.
UNLOCK STEERING.
UNLOCK THROTTLE.

// ── ORBIT ACHIEVED ─────────────────────────────────
PRINT " ".
PRINT "╔════════════════════════════════════════════════╗".
PRINT "║            ORBIT ACHIEVED                      ║".
PRINT "╚════════════════════════════════════════════════╝".
PRINT " Apoapsis:  " + ROUND(SHIP:APOAPSIS/1000, 1) + " km".
PRINT " Periapsis: " + ROUND(SHIP:PERIAPSIS/1000, 1) + " km".
PRINT " Inclination: " + ROUND(SHIP:ORBIT:INCLINATION, 2) + "°".
ks_log("LAUNCH: Orbit achieved — " + ROUND(SHIP:APOAPSIS/1000,1) + "x" + ROUND(SHIP:PERIAPSIS/1000,1) + "km").
