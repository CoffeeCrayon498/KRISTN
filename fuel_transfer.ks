// ============================================================
// KRISTN AUTOPILOT — fuel_transfer.ks
// Automated cargo dump — transfers LqdHydrogen + Oxidizer
// from Workhorse cargo bays to docked station
// ============================================================
@LAZYGLOBAL OFF.
RUNONCEPATH("0:/lib_common.ks").

CLEARSCREEN.
PRINT "╔════════════════════════════════════════════════╗".
PRINT "║        FUEL TRANSFER — CARGO DUMP              ║".
PRINT "╚════════════════════════════════════════════════╝".
PRINT " ".

// ── VERIFY DOCKED STATE ─────────────────────────────
LOCAL docked IS FALSE.
LOCAL all_ports IS SHIP:DOCKINGPORTS.
FOR p IN all_ports {
    IF p:STATE:CONTAINS("Docked") OR p:STATE:CONTAINS("PreAttached") {
        SET docked TO TRUE.
        BREAK.
    }
}

IF NOT docked {
    PRINT " [!] Not docked to any vessel.".
    PRINT "     Dock first, then run fuel transfer.".
    WAIT 3.
    RETURN.
}

PRINT " [✓] Docked state confirmed.".
PRINT " ".

// ── IDENTIFY RESOURCES ──────────────────────────────
// The Mk-34 carries LqdHydrogen + Oxidizer in 3x fuel modules
// We transfer everything except what's in the main propulsion tanks

LOCAL cargo_resources IS LIST("LqdHydrogen", "Oxidizer").
PRINT " Cargo resources to transfer:".
FOR res_name IN cargo_resources {
    IF SHIP:RESOURCES:CONTAINS(res_name) {
        LOCAL r IS SHIP:RESOURCES[res_name].  
        PRINT "   " + res_name + ": " + ROUND(r:AMOUNT, 1) + " / " + ROUND(r:CAPACITY, 1).
    }
}

PRINT " ".
PRINT " Starting transfer... (press ACTION GROUP 0 to abort)".
PRINT " ".
ks_log("FUEL: Transfer started").

// ── TRANSFER LOOP ───────────────────────────────────
// kOS can use TRANSFERALL to move resources between parts
// We'll find all fuel module parts and transfer from them

LOCAL fuel_parts IS LIST().
FOR p IN SHIP:PARTS {
    // The wbiMk33FuelModule parts carry the LH2 cargo
    IF p:NAME:CONTAINS("FuelModule") OR p:NAME:CONTAINS("LargeTank") {
        fuel_parts:ADD(p).
    }
}

PRINT " Found " + fuel_parts:LENGTH + " cargo tank parts.".

LOCAL transfer_active IS TRUE.
LOCAL total_transferred_lh2 IS 0.
LOCAL total_transferred_ox IS 0.

// Get connected parts that aren't ours (station parts)
// kOS TRANSFERALL transfers to any connected part with capacity
FOR res_name IN cargo_resources {
    IF NOT transfer_active BREAK.

    PRINT " ".
    PRINT " Transferring " + res_name + "...".

    // Use the TRANSFER built-in
    // Transfer from our fuel module parts to "all" (connected vessel gets it)
    FOR fp IN fuel_parts {
        IF NOT transfer_active BREAK.

        LOCAL res_list IS fp:RESOURCES.
        FOR r IN res_list {
            IF r:NAME = res_name AND r:AMOUNT > 0.1 {
                LOCAL start_amt IS r:AMOUNT.
                // Create a resource transfer
                LOCAL xfer IS TRANSFER(res_name, fp, SHIP, r:AMOUNT).
                SET xfer:ACTIVE TO TRUE.

                // Monitor transfer
                LOCAL timeout IS TIME:SECONDS + 120.
                UNTIL NOT xfer:ACTIVE OR TIME:SECONDS > timeout {
                    PRINT " " + res_name + " in " + fp:NAME + ": " + ROUND(r:AMOUNT, 1) + "   " AT(0, 18).
                    IF AG10 {
                        SET xfer:ACTIVE TO FALSE.
                        SET transfer_active TO FALSE.
                        PRINT " [!] Transfer aborted by user.".
                        BREAK.
                    }
                    WAIT 0.2.
                }

                LOCAL amt_moved IS start_amt - r:AMOUNT.
                IF res_name = "LqdHydrogen" {
                    SET total_transferred_lh2 TO total_transferred_lh2 + amt_moved.
                } ELSE {
                    SET total_transferred_ox TO total_transferred_ox + amt_moved.
                }
            }
        }
    }
}

// ── SUMMARY ─────────────────────────────────────────
PRINT " ".
PRINT "╔════════════════════════════════════════════════╗".
PRINT "║        TRANSFER COMPLETE                       ║".
PRINT "╚════════════════════════════════════════════════╝".
PRINT " LqdHydrogen transferred: " + ROUND(total_transferred_lh2, 1).
PRINT " Oxidizer transferred:    " + ROUND(total_transferred_ox, 1).
ks_log("FUEL: Transfer complete — LH2=" + ROUND(total_transferred_lh2,1) + " Ox=" + ROUND(total_transferred_ox,1)).
