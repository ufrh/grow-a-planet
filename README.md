# Grow a Planet

A Roblox procedural microvoxel planet simulator by **Public Access**.

## Tooling

- **FORGE 4.4.1** — ported from `ufrh/Ruckus` (branch `combat-rewrite`), including server/client runtime, UI libraries, matchmaking engine, and optional developer tools.
- **VAULT** — standalone server-side data framework, ported from the RUCKUS reference package.
- **FORGE Studio** — source for the Studio UI designer plugin; build separately with `forge-studio.project.json`.
- **Rojo** — `grow-a-planet.project.json` maps the project to one Roblox place.

> The standalone VAULT package and FORGE's integrated data engine are two alternative persistence APIs. Do **not** open a Player datastore through both at once. Grow a Planet will use the integrated FORGE data layer by default; the standalone VAULT module is provided for compatibility and standalone usage.

## Development

1. Install Rojo (see `rokit.toml`).
2. Open your new Grow a Planet place in Roblox Studio.
3. From the repository root, run `rojo serve grow-a-planet.project.json` and connect the Rojo plugin.
4. The project mounts `ReplicatedStorage.FORGE`, `ServerScriptService.FORGE`, `ServerScriptService.VAULT`, and FORGE's client boot script.
5. No game-specific Player data schema is installed yet; add one under `src/game/ServerScriptService/Data/Stores/` once the game's data model is defined.

## Prototype 0.1

Planned: deterministic hollow microvoxel terrain, 0.25-stud voxel scale at 16-stud diameter, exposed-face chunk meshing, and a custom distance-based level-of-detail chooser. No traits, economy, or vegetation.

## Scope of this port

The runtime source is preserved from RUCKUS. Game-specific services, match systems, combat, RUCKUS profile schemas and existing gameplay are deliberately excluded. The server/client startup scripts have been adapted for this new project. Roblox Studio testing is still required before declaring the runtime validated.
