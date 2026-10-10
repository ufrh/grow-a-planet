# Grow a Planet — framework port

FORGE 4.4.1 came from ufrh/Ruckus (combat-rewrite); standalone VAULT came from the RUCKUS reference code.

Retained: shared FORGE API, runtime, networking, UI runtime, integrated data engine, standalone VAULT, server/client bootstraps. Standalone VAULT is optional: never open a player store with both persistence APIs.

Removed: the FORGE Studio designer plugin, its separate Rojo project, and plugin-only documentation. The FORGE runtime UI library is NOT the designer plugin and remains intact. RUCKUS gameplay, profile schema, and match-specific bootstraps were never imported.

## Development

One place: 102865473124541
Experience/universe: 10770120558
Rojo: grow-a-planet.project.json on localhost:34878
Windows launchers: START_GROW_A_PLANET.bat, STOP_GROW_A_PLANET.bat, PUSH_GROW_A_PLANET.bat.

Use START to start one Rojo server and background fast-forward Git sync, STOP to close only this project's recorded processes, and PUSH to commit/push the current branch. The scripts do not publish to Roblox. Workspace and Lighting are deliberately not Rojo-mapped so the Studio starfield is preserved.

## Verification

- Connect Rojo from Studio and verify FORGE and VAULT are mounted.
- Check both FORGE bootstraps run without warnings.
- Check the Studio starfield remains unchanged.
- Confirm Rojo and live Git sync stop cleanly.
- Define Grow a Planet-specific player data schemas before using persistence.

The port has not been runtime-tested in Roblox Studio.
