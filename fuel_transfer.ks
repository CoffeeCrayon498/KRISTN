// ══════════════════════════════════════════════════════════
// KRISTN - FUEL TRANSFER SCRIPT
// fuel_transfer.ks — Automated fuel transfer while docked
// Transfers LH2 and Ox cargo from WORKHORSE to station
// ══════════════════════════════════════════════════════════
@LAZYGLOBAL OFF.
RUNONCEPATH("0:/gui_lib.ks").

CLEARSCREEN.
gui_telemetry("FUEL TRANSFER").

// ── Check if docked ──
LOCAL my_ports IS SHIP:DOCKINGPORTS.
LOCAL is_docked IS FALSE.
FOR p IN my_ports {
    IF p:STATE:CONTAINS("Docked") OR p:STATE:CONTAINS("PreAttached") {
        SET is_docked TO TRUE.
    }
}

IF NOT is_docked {
    PRINT "ERROR: Not docked! Dock with station first.".
    WAIT 3.
    RETURN.
}

gui_status("Docked - preparing fuel transfer...").

// ── Identify cargo resources to transfer ──
// WORKHORSE cargo: LqdHydrogen and Oxidizer in cargo tanks
// We transfer these to the station

// Get resource lists
LOCAL lh2_transfer IS TRANSFERALL("LqdHydrogen", SHIP, TARGET).
LOCAL ox_transfer IS TRANSFERALL("Oxidizer", SHIP, TARGET).

// ── Display pre-transfer state ──
LOCAL ship_lh2 IS 0.
LOCAL ship_ox IS 0.
FOR r IN SHIP:RESOURCES {
    IF r:NAME = "LqdHydrogen" { SET ship_lh2 TO r:AMOUNT. }
    IF r:NAME = "Oxidizer" { SET ship_ox TO r:AMOUNT. }
}

PRINT " " AT (0, 11).
PRINT "── Pre-Transfer ──" AT (0, 12).
PRINT "Ship LH2:  " + ROUND(ship_lh2, 0) AT (0, 13).
PRINT "Ship Ox:   " + ROUND(ship_ox, 0) AT (0, 14).

// ══════════════════════════════════════
// TRANSFER LH2
// ══════════════════════════════════════
gui_status("Transferring Liquid Hydrogen...").
SET lh2_transfer:ACTIVE TO TRUE.

UNTIL lh2_transfer:STATUS = "Finished" OR lh2_transfer:STATUS = "Failed" {
    LOCAL current_lh2 IS 0.
    FOR r IN SHIP:RESOURCES {
        IF r:NAME = "LqdHydrogen" { SET current_lh2 TO r:AMOUNT. }
    }
    LOCAL pct IS ROUND((1 - current_lh2 / MAX(ship_lh2, 1)) * 100).
    PRINT "LH2 transfer: " + pct + "%   " AT (0, 15).

    IF current_lh2 < 1 {
        SET lh2_transfer:ACTIVE TO FALSE.
    }
    WAIT 0.1.
}
SET lh2_transfer:ACTIVE TO FALSE.
PRINT "LH2 transfer: COMPLETE" AT (0, 15).

// ══════════════════════════════════════
// TRANSFER OXIDIZER (cargo portion only)
// ══════════════════════════════════════
// Note: We need to keep our own propulsion Ox!
// The cargo Ox is in the MediumTank and Adapter (~3,397 units)
// Our propulsion Ox is in the Large+Small tanks (~23,760 units)
// Since fuel priority keeps them separate, we transfer what we can

gui_status("Transferring Oxidizer...").

// We want to transfer only cargo ox, but TRANSFERALL moves everything
// So we transfer a specific amount
LOCAL cargo_ox_amount IS 3397.  // Approximate cargo Ox

LOCAL ox_partial IS TRANSFER("Oxidizer", SHIP, TARGET, cargo_ox_amount).
SET ox_partial:ACTIVE TO TRUE.

UNTIL ox_partial:STATUS = "Finished" OR ox_partial:STATUS = "Failed" {
    PRINT "Ox transfer: " + ox_partial:STATUS + "   " AT (0, 16).
    WAIT 0.1.
}
SET ox_partial:ACTIVE TO FALSE.
PRINT "Ox transfer: COMPLETE" AT (0, 16).

// ══════════════════════════════════════
// POST-TRANSFER SUMMARY
// ══════════════════════════════════════
gui_status("Transfer complete!").

LOCAL final_lh2 IS 0.
LOCAL final_ox IS 0.
LOCAL final_lf IS 0.
FOR r IN SHIP:RESOURCES {
    IF r:NAME = "LqdHydrogen" { SET final_lh2 TO r:AMOUNT. }
    IF r:NAME = "Oxidizer" { SET final_ox TO r:AMOUNT. }
    IF r:NAME = "LiquidFuel" { SET final_lf TO r:AMOUNT. }
}

PRINT " " AT (0, 17).
PRINT "── Post-Transfer ──" AT (0, 18).
PRINT "Ship LH2:  " + ROUND(final_lh2, 0) + " (cargo delivered)" AT (0, 19).
PRINT "Ship Ox:   " + ROUND(final_ox, 0) + " (propulsion retained)" AT (0, 20).
PRINT "Ship LF:   " + ROUND(final_lf, 0) + " (propulsion retained)" AT (0, 21).
PRINT "dV remaining: ~" + ROUND(calc_dv()) + " m/s" AT (0, 22).
PRINT " " AT (0, 23).
PRINT "Fuel transfer complete. Ready to undock." AT (0, 24).
