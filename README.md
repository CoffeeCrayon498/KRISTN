# KRISTN
KRISTN (Kerbal Reusable Interstellar Space Transportation Network) — Full kOS autopilot suite for KSP with automated launch, orbital rendezvous, docking, fuel transfer, deorbit &amp; landing. Includes a live Python/WebSocket mission control dashboard with telemetry gauges, charts, and Kerbin ground track map.

KRISTN PROJECT BRIEFING — Continuation Summary
================================================

PROJECT: KRISTN (Kerbal Reusable Interstellar Space Transportation Network)
A reusable transport network for KSP with full kOS autopilot automation.

PHASE 1 STATUS: Kerbin-Mun Corridor (in progress)
- Design doc complete (KRISTN_Design_Doc.docx with logo)
- Working launch script (v2 restored — gets to orbit reliably)
- Mission Control dashboard with live telemetry + Kerbin map (kristn_server.py)
- Flight recorder running in background on every flight

THE SHIP: WORKHORSE Heavy Lift Tanker
- 32 parts, ~290t wet, Mammoth engine (stock 3.75m)
- Surface TWR ~1.3, climbs to ~5+ as fuel burns
- LF/Ox propulsion tanks + LH2/Ox cargo tanks (fuel priority separated)
- 8x NFA RCS blisters (LF/Ox type, no monoprop needed)
- 4x landing legs (scaled 2x), 4x delta fins, docking port on top
- Probe core, kOS processor, battery bank, 2x reaction wheels
- Single stage, AUTO_STAGE = FALSE

SCRIPTS WRITTEN (all in Ships/Script/):
- boot.ks — menu + auto-starts flight recorder
- gui_lib.ks — telemetry display functions
- launch.ks — v2 restored, three-phase gravity turn (45° at 15km), AoA limiter (3°), predictive throttle cutoff, circularization. THIS IS THE WORKING VERSION.
- node_executor.ks — precision maneuver node burner
- rendezvous.ks — approach + docking autopilot
- fuel_transfer.ks — automated cargo dump to station
- deorbit.ks — v2, direct retrograde burn (no node), propulsive landing
- mission_tanker.ks — full tanker run orchestrator
- flight_recorder.ks — background telemetry logger, auto-labels flights

DASHBOARD: kristn_server.py
- Python WebSocket server that watches kOS log folder
- Serves NASA-style dark theme dashboard at localhost:8088
- Live gauges, charts (alt/apo, TWR/throttle/AoA), Kerbin ground track map
- Requires: pip install websockets
- Run: python kristn_server.py "C:\path\to\Ships\Script\logs"

WHAT WORKS:
- Launch to ~100km orbit (v2 launch script)
- Flight recording with auto-labeling
- Dashboard with live telemetry

WHAT NEEDS WORK:
- Deorbit + propulsive landing (deorbit.ks v2 untested — engine wasn't firing in v1)
- KSC runway precision landing (planned but not built yet)
- Rendezvous/docking (written but untested with this ship)
- Fuel transfer (written but untested)
- Full tanker run end-to-end automation
- Kerbin Station assembly
- Pathfinder Nuclear Shuttle (not built yet)
- Mun Station (not built yet)

KNOWN ISSUES:
- Launch script works intermittently — may be kOS caching old scripts, or physics lag causing missed throttle cutoffs. Consider adding a safety trigger.
- kOS RETURN statement can't be used outside functions (caused errors before)
- Flight recorder CSV has no header row (user modified the recorder)
- Dashboard auto-refresh needs the Python server (browser can't re-read local files)

KEY LESSONS LEARNED:
- TWR 1.3-1.8 is the sweet spot for Kerbin ascent
- AoA must stay under 3-5° or you get plasma/drag at low altitude
- Throttle cutoff code must NOT have MIN/MAX floors that prevent reaching zero
- The gravity turn that works: 90°→45° by 15km, 45°→15° by 35km, 15°→0° by 60km
- Predictive cutoff with coast_seconds=5 works if the throttle can actually reach zero

MODLIST: Full Near Future + Far Future + Kerbal Atomics + CryoTanks + Procedural Parts + Station Parts Redux + KPBS + Persistent Thrust + Trajectories + SCANsat + kOS + MechJeb + TweakScale + Sigma Dimensions (stock 1x scale) + Promised Worlds (Debdeb/Tuun interstellar systems) + many visual mods

FUTURE PHASES:
- Phase 2: Duna corridor (nuclear/fusion propulsion)
- Phase 3: Interstellar (Far Future Tech, Debdeb/Tuun systems)
- ISRU mining possible later if tanker runs become unsustainable
