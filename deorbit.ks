// ============================================================
// KRISTN AUTOPILOT — deorbit.ks
// Mk-34 Workhorse — Deorbit + KSC Runway Landing
// Spaceplane glide approach with powered final
// ============================================================
@LAZYGLOBAL OFF.
RUNONCEPATH("0:/lib_common.ks").

CLEARSCREEN.
PRINT "╔════════════════════════════════════════════════╗".
PRINT "║     DEORBIT + RUNWAY LANDING                   ║".
PRINT "╚════════════════════════════════════════════════╝".
PRINT " ".

// ── CONFIGURATION ───────────────────────────────────
LOCAL RUNWAY IS ks_ksc_runway().         // Runway 09 threshold
LOCAL RUNWAY_ALT IS 70.                  // KSC elevation (m)
LOCAL RUNWAY_HDG IS 90.                  // Runway heading
LOCAL DEORBIT_PERI IS 30000.            // Target periapsis for deorbit
LOCAL GLIDE_START_ALT IS 30000.         // Switch to glide steering
LOCAL APPROACH_ALT IS 5000.             // Begin approach phase
LOCAL FLARE_ALT IS 200.                 // Begin flare
LOCAL TOUCHDOWN_VS IS -2.              // Target sink rate at touchdown (m/s)
LOCAL GEAR_ALT IS 1000.                // Deploy gear altitude

PRINT " Target: KSC Runway 09".
PRINT " Runway position: " + ROUND(RUNWAY:LAT, 3) + "°, " + ROUND(RUNWAY:LNG, 3) + "°".
PRINT " ".

// ── PHASE 1: DEORBIT BURN ──────────────────────────
PRINT "Phase 1: Deorbit burn                      ".
ks_log("DEORBIT: Initiating deorbit burn").

// Point retrograde
RCS ON.
SAS OFF.
LOCK STEERING TO SHIP:RETROGRADE.
WAIT 5.

// Burn retrograde until periapsis drops
ks_engines_on().
LOCK THROTTLE TO 0.5.

UNTIL SHIP:PERIAPSIS <= DEORBIT_PERI {
    PRINT " Periapsis: " + ROUND(SHIP:PERIAPSIS/1000, 1) + "km   Target: " + ROUND(DEORBIT_PERI/1000) + "km   " AT(0, 8).
    WAIT 0.1.
}

LOCK THROTTLE TO 0.
ks_engines_off().
ks_log("DEORBIT: Burn complete, PE=" + ROUND(SHIP:PERIAPSIS/1000,1) + "km").

PRINT " Deorbit burn complete. Periapsis: " + ROUND(SHIP:PERIAPSIS/1000,1) + "km".
PRINT " ".

// ── PHASE 2: REENTRY ───────────────────────────────
PRINT "Phase 2: Atmospheric reentry               ".
LOCK STEERING TO SHIP:SRFRETROGRADE.

// Ride through reentry — hold retrograde for maximum drag
UNTIL ALTITUDE < GLIDE_START_ALT AND SHIP:VERTICALSPEED < 0 {
    LOCAL dist_to_ksc IS ks_geo_dist(SHIP:GEOPOSITION, RUNWAY).
    PRINT " Alt: " + ROUND(ALTITUDE/1000,1) + "km  Speed: " + ROUND(SHIP:AIRSPEED) + " m/s   " AT(0, 8).
    PRINT " Dist to KSC: " + ROUND(dist_to_ksc/1000, 1) + " km   VS: " + ROUND(SHIP:VERTICALSPEED) + "   " AT(0, 9).

    // Switch to ~40° AoA belly-first when in thick atmosphere for drag
    IF ALTITUDE < 50000 AND SHIP:AIRSPEED > 500 {
        LOCK STEERING TO SHIP:SRFRETROGRADE.
    }

    WAIT 0.5.
}

// ── PHASE 3: GLIDE + ENERGY MANAGEMENT ─────────────
PRINT "Phase 3: Glide approach                     " AT(0, 6).
ks_log("DEORBIT: Glide approach phase").

LOCAL approach_mode IS "glide".

UNTIL ALT:RADAR < FLARE_ALT {
    LOCAL dist_to_rwy IS ks_geo_dist(SHIP:GEOPOSITION, RUNWAY).
    LOCAL bearing_to_rwy IS RUNWAY:HEADING.

    // Energy management: compute glide slope
    LOCAL alt_above_rwy IS ALTITUDE - RUNWAY_ALT.
    LOCAL glide_angle IS ARCTAN2(alt_above_rwy, dist_to_rwy).
    LOCAL desired_pitch IS -3.    // Default shallow descent

    IF dist_to_rwy > 50000 {
        // Still far — aim at KSC general area
        SET desired_pitch TO -2.
    } ELSE IF dist_to_rwy > 10000 {
        // Approach — manage energy, steeper if too high
        IF glide_angle > 10 {
            SET desired_pitch TO -8.   // Too high, steepen
        } ELSE IF glide_angle < 3 {
            SET desired_pitch TO 0.    // Too low, shallow out
        } ELSE {
            SET desired_pitch TO -3.
        }
    } ELSE IF dist_to_rwy > 2000 {
        // Short final
        SET approach_mode TO "final".
        SET desired_pitch TO -3.
        IF glide_angle > 8 { SET desired_pitch TO -6. }
        IF glide_angle < 2 { SET desired_pitch TO -1. }
    }

    LOCK STEERING TO HEADING(bearing_to_rwy, desired_pitch).

    // Deploy gear
    IF ALT:RADAR < GEAR_ALT AND GEAR = FALSE {
        GEAR ON.
        PRINT " [✓] Gear deployed.                        " AT(0, 12).
        ks_log("DEORBIT: Gear deployed").
    }

    // Telemetry
    PRINT " Alt(AGL): " + ROUND(ALT:RADAR) + "m  Speed: " + ROUND(SHIP:AIRSPEED) + " m/s      " AT(0, 8).
    PRINT " Dist: " + ROUND(dist_to_rwy/1000,1) + "km  Glide: " + ROUND(glide_angle,1) + "°  Mode: " + approach_mode + "   " AT(0, 9).
    PRINT " Pitch: " + ROUND(desired_pitch,1) + "°  VS: " + ROUND(SHIP:VERTICALSPEED,1) + " m/s          " AT(0, 10).

    WAIT 0.1.
}

// ── PHASE 4: FLARE + TOUCHDOWN ─────────────────────
PRINT "Phase 4: FLARE                             " AT(0, 6).
ks_log("DEORBIT: Flare at " + ROUND(ALT:RADAR) + "m AGL").

// Gradual pitch up to arrest sink rate
UNTIL SHIP:STATUS = "LANDED" OR SHIP:STATUS = "SPLASHED" OR ALT:RADAR < 2 {
    // Flare pitch: proportional to height — more nose-up as we descend
    LOCAL flare_pct IS 1 - (ALT:RADAR / FLARE_ALT).
    LOCAL flare_pitch IS 2 + flare_pct * 6. // 2° to 8° nose up

    // If sinking too fast, pull up harder
    IF SHIP:VERTICALSPEED < -5 {
        SET flare_pitch TO flare_pitch + 3.
    }

    LOCK STEERING TO HEADING(RUNWAY_HDG, flare_pitch).

    PRINT " AGL: " + ROUND(ALT:RADAR, 1) + "m  VS: " + ROUND(SHIP:VERTICALSPEED, 1) + " m/s  Pitch: " + ROUND(flare_pitch,1) + "°   " AT(0, 8).
    WAIT 0.05.
}

// ── PHASE 5: ROLLOUT ───────────────────────────────
PRINT " ".
PRINT "Phase 5: Rollout — braking                 " AT(0, 6).
ks_log("DEORBIT: Touchdown!").

BRAKES ON.
LOCK THROTTLE TO 0.
LOCK STEERING TO HEADING(RUNWAY_HDG, 0).

UNTIL SHIP:GROUNDSPEED < 1 {
    PRINT " Speed: " + ROUND(SHIP:GROUNDSPEED, 1) + " m/s              " AT(0, 8).
    WAIT 0.2.
}

BRAKES ON.
UNLOCK STEERING.
UNLOCK THROTTLE.
SAS ON.

PRINT " ".
PRINT "╔════════════════════════════════════════════════╗".
PRINT "║        LANDING COMPLETE                        ║".
PRINT "╚════════════════════════════════════════════════╝".
LOCAL final_dist IS ks_geo_dist(SHIP:GEOPOSITION, RUNWAY).
PRINT " Distance from runway threshold: " + ROUND(final_dist) + "m".
PRINT " Position: " + ROUND(SHIP:GEOPOSITION:LAT, 4) + "°, " + ROUND(SHIP:GEOPOSITION:LNG, 4) + "°".
ks_log("DEORBIT: Landed at " + ROUND(SHIP:GEOPOSITION:LAT,4) + "," + ROUND(SHIP:GEOPOSITION:LNG,4) + " dist=" + ROUND(final_dist) + "m").
