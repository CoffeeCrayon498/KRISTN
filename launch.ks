// ══════════════════════════════════════════════════════════
// KRISTN - LAUNCH SCRIPT v2
// launch.ks — Gravity turn ascent + auto-circularization
// Tuned from flight F244 data analysis:
//   - Turn was too late (stayed at 90° until ~1km)
//   - AoA spiked to 45° (massive drag losses)
//   - Kept burning past target apo (612km instead of 100km)
//   - No circularization burn occurred
//   - Used 98% of fuel for a terrible orbit
// ══════════════════════════════════════════════════════════
@LAZYGLOBAL OFF.
RUNONCEPATH("0:/gui_lib.ks").

// ── Parameters (from boot.ks globals or defaults) ──
LOCAL tgt_apo IS 100000.
IF DEFINED TARGET_ORBIT { SET tgt_apo TO TARGET_ORBIT. }

LOCAL turn_start IS 100.
IF DEFINED TURN_START_ALT { SET turn_start TO TURN_START_ALT. }

LOCAL turn_end IS 55000.
IF DEFINED TURN_END_ALT { SET turn_end TO TURN_END_ALT. }

LOCAL max_twr IS 1.8.
IF DEFINED MAX_TWR { SET max_twr TO MAX_TWR. }

LOCAL max_aoa IS 5.
IF DEFINED MAX_AOA { SET max_aoa TO MAX_AOA. }

// ── Local constants ──
LOCAL g0 IS 9.80665.
LOCAL target_heading IS 90.   // Due east for equatorial

// ── State tracking ──
LOCAL current_pitch_target IS 90.
LOCAL last_good_pitch IS 90.

// ══════════════════════════════════════
// GRAVITY TURN FUNCTION
// ══════════════════════════════════════
// Attempt 1 had a cosine curve that turned too sharply in mid-atmo.
// This version uses a square-root curve: turns gently at first (where
// the atmosphere is thick and AoA matters most), then more aggressively
// higher up where drag is negligible.

FUNCTION calc_target_pitch {
    IF ALTITUDE < turn_start { RETURN 90. }
    IF ALTITUDE > turn_end { RETURN 0. }

    LOCAL progress IS (ALTITUDE - turn_start) / (turn_end - turn_start).

    // Square-root profile: gentle early, steeper late
    // At progress 0.1 (low atmo): pitch ~71° (gentle 19° turn)
    // At progress 0.25: pitch ~55°
    // At progress 0.5: pitch ~26°
    // At progress 0.75: pitch ~7°
    LOCAL pitch IS 90 * (1 - SQRT(progress)).

    RETURN MAX(0, MIN(90, pitch)).
}

// ══════════════════════════════════════
// AoA LIMITER
// ══════════════════════════════════════
// Flight F244 had AoA up to 45°. This function ensures we never
// command a pitch that puts us more than max_aoa degrees away from
// our surface velocity vector. If the ship can't follow the turn
// fast enough, we slow the turn down.

FUNCTION calc_safe_pitch {
    LOCAL target IS calc_target_pitch().

    // Below 1km or very slow, just use target pitch directly
    IF ALTITUDE < 1000 OR SHIP:VELOCITY:SURFACE:MAG < 50 {
        SET last_good_pitch TO target.
        RETURN target.
    }

    // Calculate current prograde pitch (angle of velocity above horizon)
    LOCAL vel IS SHIP:VELOCITY:SURFACE.
    LOCAL prograde_pitch IS 90 - VANG(SHIP:UP:FOREVECTOR, vel).

    // Don't command more than max_aoa away from prograde
    LOCAL min_allowed IS prograde_pitch - max_aoa.
    LOCAL max_allowed IS prograde_pitch + max_aoa.

    LOCAL safe_pitch IS MAX(min_allowed, MIN(max_allowed, target)).

    // Also don't pitch down more than 3° per second (smooth transitions)
    IF safe_pitch < last_good_pitch - 1.5 {
        SET safe_pitch TO last_good_pitch - 1.5.
    }

    SET last_good_pitch TO safe_pitch.
    RETURN MAX(0, safe_pitch).
}

// ══════════════════════════════════════
// TWR-LIMITED THROTTLE
// ══════════════════════════════════════
// Flight F244 showed TWR climbing from 1.4 to 5.8 as fuel burned off.
// Above ~2.0 TWR in atmosphere you're wasting fuel on drag.
// This limiter keeps effective TWR capped.

FUNCTION calc_throttle {
    IF SHIP:AVAILABLETHRUST <= 0 { RETURN 1. }

    LOCAL local_g IS BODY:MU / (BODY:RADIUS + ALTITUDE)^2.
    LOCAL current_max_twr IS SHIP:AVAILABLETHRUST / (SHIP:MASS * local_g).

    LOCAL throttle_for_twr IS 1.0.
    IF current_max_twr > max_twr {
        SET throttle_for_twr TO max_twr / current_max_twr.
    }

    RETURN throttle_for_twr.
}

// ══════════════════════════════════════
// PHASE 1: PRE-LAUNCH
// ══════════════════════════════════════
CLEARSCREEN.
gui_telemetry("PRE-LAUNCH").
gui_status("Systems check...").

SAS OFF.
RCS OFF.
LIGHTS ON.

LOCK STEERING TO HEADING(target_heading, 90).
WAIT 1.

gui_countdown(5, "Launch in").

// ══════════════════════════════════════
// PHASE 2: LIFTOFF
// ══════════════════════════════════════
gui_status("IGNITION").
LOCK THROTTLE TO 1.0.

IF SHIP:AVAILABLETHRUST < 10 {
    STAGE.
    WAIT 0.5.
}

WAIT UNTIL SHIP:AVAILABLETHRUST > (SHIP:MASS * g0).
gui_status("LIFTOFF").

// Vertical climb until turn_start altitude
WAIT UNTIL ALTITUDE > turn_start.

// ══════════════════════════════════════
// PHASE 3: GRAVITY TURN
// ══════════════════════════════════════
gui_status("Gravity turn initiated").

// Kick: small initial pitch-over to get the turn started
// Without this, the ship goes perfectly vertical and never starts turning
LOCK STEERING TO HEADING(target_heading, 85).
WAIT 3.

// Now follow the gravity turn profile with AoA limiting
LOCK STEERING TO HEADING(target_heading, calc_safe_pitch()).
LOCK THROTTLE TO calc_throttle().

// ── Ascent loop ──
LOCAL apo_reached IS FALSE.
UNTIL apo_reached {
    gui_telemetry("ASCENT").

    // Show extra data
    LOCAL vel IS SHIP:VELOCITY:SURFACE.
    LOCAL prograde_pitch IS 90 - VANG(SHIP:UP:FOREVECTOR, vel).
    LOCAL current_aoa IS VANG(SHIP:FACING:FOREVECTOR, vel).
    PRINT "Tgt pitch: " + ROUND(calc_target_pitch(), 1) + "°   " AT (0, 11).
    PRINT "Pro pitch: " + ROUND(prograde_pitch, 1) + "°   " AT (0, 12).
    PRINT "AoA:       " + ROUND(current_aoa, 1) + "°   " AT (0, 13).

    // ── CRITICAL FIX: Throttle management near target apoapsis ──
    // Flight F244 kept burning to 612km because throttle never cut.
    // Three zones:
    //   1. Below 80% of target: full calculated throttle
    //   2. 80-95% of target: ramp throttle down
    //   3. 95%+ of target: minimum throttle, then cut

    LOCAL apo_pct IS APOAPSIS / tgt_apo.

    IF apo_pct >= 0.98 {
        // Very close — cut to zero and exit
        LOCK THROTTLE TO 0.
        SET apo_reached TO TRUE.
    } ELSE IF apo_pct >= 0.90 {
        // Close — low throttle for fine control
        LOCAL ramp IS (apo_pct - 0.90) / 0.08.  // 0 at 90%, 1 at 98%
        LOCAL reduced IS calc_throttle() * (1 - ramp * 0.9).  // Down to 10%
        LOCK THROTTLE TO MAX(0.03, reduced).
    } ELSE IF apo_pct >= 0.80 {
        // Approaching — start reducing
        LOCAL ramp IS (apo_pct - 0.80) / 0.10.
        LOCAL reduced IS calc_throttle() * (1 - ramp * 0.3).  // Down to 70%
        LOCK THROTTLE TO reduced.
    }
    // Below 80%: calc_throttle() handles it (already locked above)

    WAIT 0.
}

// Final fine-tune: if we undershot slightly, tiny bursts
IF APOAPSIS < tgt_apo * 0.99 {
    gui_status("Fine-tuning apoapsis...").
    LOCK STEERING TO HEADING(target_heading, MAX(0, calc_safe_pitch())).
    LOCK THROTTLE TO 0.03.
    WAIT UNTIL APOAPSIS >= tgt_apo.
    LOCK THROTTLE TO 0.
}

gui_status("Apoapsis: " + ROUND(APOAPSIS/1000, 1) + " km - ENGINES CUT").

// ══════════════════════════════════════
// PHASE 4: COAST TO APOAPSIS
// ══════════════════════════════════════
gui_status("Coasting to apoapsis...").
LOCK STEERING TO PROGRADE.

// Let ship settle on prograde
WAIT 5.

// Warp to near apoapsis
IF ETA:APOAPSIS > 60 {
    gui_status("Warping to apoapsis...").
    KUNIVERSE:TIMEWARP:WARPTO(TIME:SECONDS + ETA:APOAPSIS - 40).
    WAIT UNTIL ETA:APOAPSIS < 45.
    KUNIVERSE:TIMEWARP:CANCELWARP().
    WAIT UNTIL SHIP:UNPACKED.
    WAIT 2.
}

// Hold prograde and wait
LOCK STEERING TO PROGRADE.
WAIT UNTIL ETA:APOAPSIS < 25 OR VERTICALSPEED < -5.

// ══════════════════════════════════════
// PHASE 5: CIRCULARIZATION
// ══════════════════════════════════════
gui_status("Calculating circularization burn...").

// Circular velocity at apoapsis
LOCAL r_apo IS BODY:RADIUS + APOAPSIS.
LOCAL v_circular IS SQRT(BODY:MU / r_apo).

// Current velocity at apoapsis (vis-viva)
LOCAL r_peri IS BODY:RADIUS + PERIAPSIS.
LOCAL sma IS (r_apo + r_peri) / 2.
LOCAL v_at_apo IS SQRT(BODY:MU * (2/r_apo - 1/sma)).

LOCAL dv_circ IS v_circular - v_at_apo.

gui_status("Circ burn: " + ROUND(dv_circ, 1) + " m/s").

// Create maneuver node
LOCAL circ_node IS NODE(TIME:SECONDS + ETA:APOAPSIS, 0, 0, dv_circ).
ADD circ_node.
WAIT 0.1.

// Calculate burn time
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
LOCAL avg_isp IS weighted_isp / MAX(total_thrust, 0.001).
LOCAL exhaust_v IS avg_isp * g0.
LOCAL mass_ratio IS CONSTANT:E ^ (dv_circ / exhaust_v).
LOCAL fuel_mass IS SHIP:MASS * (1 - 1/mass_ratio).
LOCAL flow_rate IS total_thrust / exhaust_v.
LOCAL burn_time IS fuel_mass / MAX(flow_rate, 0.001).
LOCAL half_burn IS burn_time / 2.

PRINT "Burn time: " + ROUND(burn_time, 1) + "s" AT (0, 12).

// Point at node
LOCK STEERING TO circ_node:BURNVECTOR.
gui_status("Aligning for circ burn...").
WAIT UNTIL VANG(SHIP:FACING:FOREVECTOR, circ_node:BURNVECTOR) < 2.

// Wait for burn start (half burn time before node)
gui_status("Waiting for burn window...").
WAIT UNTIL ETA:APOAPSIS <= half_burn + 1.

// ── CIRCULARIZATION BURN ──
gui_status("CIRC BURN").

// Use TWR-limited throttle during circ burn too
// At this point mass is lower so TWR could be high
LOCAL circ_max_twr IS 2.5.
LOCK THROTTLE TO 1.0.

LOCAL done_burn IS FALSE.
LOCAL initial_dv IS circ_node:DELTAV.

UNTIL done_burn {
    gui_telemetry("CIRC BURN").

    LOCAL remaining_dv IS circ_node:DELTAV:MAG.
    PRINT "Remaining: " + ROUND(remaining_dv, 1) + " m/s   " AT (0, 11).

    // TWR limiter for circ burn
    LOCAL local_g IS BODY:MU / (BODY:RADIUS + ALTITUDE)^2.
    LOCAL current_max_twr IS SHIP:AVAILABLETHRUST / (SHIP:MASS * local_g).
    LOCAL twr_throttle IS 1.0.
    IF current_max_twr > circ_max_twr {
        SET twr_throttle TO circ_max_twr / current_max_twr.
    }

    // Precision throttle-down near end
    IF remaining_dv < 20 {
        LOCK THROTTLE TO MAX(0.02, MIN(twr_throttle, remaining_dv / 20)).
    } ELSE {
        LOCK THROTTLE TO twr_throttle.
    }

    // Track steering to burn vector (it shifts as we burn)
    LOCK STEERING TO circ_node:BURNVECTOR.

    // Completion
    IF remaining_dv < 0.15 {
        SET done_burn TO TRUE.
    }
    IF VDOT(initial_dv, circ_node:DELTAV) < 0 {
        SET done_burn TO TRUE.
    }

    WAIT 0.
}

LOCK THROTTLE TO 0.
REMOVE circ_node.

// ══════════════════════════════════════
// PHASE 6: ORBIT ACHIEVED
// ══════════════════════════════════════
UNLOCK STEERING.
UNLOCK THROTTLE.
SAS ON.

CLEARSCREEN.
gui_telemetry("ORBIT ACHIEVED").
gui_status("WORKHORSE in LKO").
PRINT " " AT (0, 12).
PRINT "Apoapsis:  " + ROUND(APOAPSIS/1000, 1) + " km" AT (0, 13).
PRINT "Periapsis: " + ROUND(PERIAPSIS/1000, 1) + " km" AT (0, 14).
PRINT "Incl:      " + ROUND(ORBIT:INCLINATION, 2) + "°" AT (0, 15).
PRINT "dV left:   ~" + ROUND(calc_dv()) + " m/s" AT (0, 16).
PRINT " " AT (0, 17).

// Quick health check
LOCAL orbit_quality IS "GOOD".
IF ABS(APOAPSIS - PERIAPSIS) > 10000 {
    SET orbit_quality TO "ELLIPTIC - may need correction".
}
IF APOAPSIS > 120000 OR APOAPSIS < 80000 {
    SET orbit_quality TO "OFF-TARGET - check parameters".
}
PRINT "Orbit quality: " + orbit_quality AT (0, 18).
PRINT " " AT (0, 19).
PRINT "Launch complete." AT (0, 20).
