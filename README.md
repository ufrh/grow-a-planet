# Grow a Planet

A Roblox procedural microvoxel planet simulator by **Public Access**.

## One-place setup

- Roblox place: **102865473124541**
- Experience (universe): **10770120558**
- GitHub branch: **main**
- One Rojo project: grow-a-planet.project.json
- Rojo port: **34878**, chosen to avoid the RUCKUS development ports

No Central, Game Server, or testing place. Workspace and Lighting are deliberately unmapped, so the Studio scene (empty void and twinkling stars) is preserved.

## Windows development launchers

1. Clone the repo and open the Grow a Planet place in Roblox Studio.
2. Install Rojo if needed (rokit install, based on rokit.toml).
3. Double-click **START_GROW_A_PLANET.bat**. It validates the project, fast-forwards the current Git branch when safe, starts a single Rojo server, and starts background Git sync.
4. Connect the standard Rojo Studio integration to **http://localhost:34878**.
5. Use **PUSH_GROW_A_PLANET.bat** to commit and push changes to the current branch.
6. Use **STOP_GROW_A_PLANET.bat** to stop only this project's recorded Rojo and live-sync processes.

Background Git sync only fast-forwards when the working tree is clean and there are no unpushed local commits. The launchers never reset or switch branches. Logs and process IDs live in ignored logs/.

**Git push and Rojo sync do not publish the Roblox place.** Publish from Roblox Studio separately.

The separate FORGE Studio designer plugin and its build project are removed. The normal Rojo Studio integration used for syncing files is external tooling and is still needed. The FORGE runtime UI API remains available.

## Framework

- FORGE 4.4.1: runtime, networking, UI runtime, and integrated data system, ported from ufrh/Ruckus.
- Standalone VAULT: retained for compatibility, but not started by default.

Do not bind the same player datastore with both APIs. Game-specific services, controllers and player data schemas are not installed yet. FORGE bootstraps still require a Roblox Studio smoke test.

## Prototype 0.2 — microvoxels

The initial planet generator now samples a **128 × 128 × 128** grid (lower detail: 64³ and 32³) in a roomy 18-stud sampling box. The nominal planet is 16 studs across. Its surface stays within **7.65–8.35 studs of the center**, so terrain reads as a gently uneven sphere instead of a jagged asteroid.

- Proper solid voxel volumes. Mesh mode renders the visible, greedily merged outer surfaces; Parts fallback uses full cubic blocks, greedily merged into *solid cuboids*, never thin face plates.
- Mesh mode uses standard **triangles**, not EditableMesh quad beta APIs. Runtime Mesh & Image permissions still determine whether it works on a given client.
- Fallback automatically drops to a coarser resolution if the number of merged solid Parts would exceed the per-planet safety budget (currently 6,500).
- Camera orbit, zoom, seed reroll (R), force LOD (1/2/3), auto LOD (0), diagnostics (F3) all remain.

This is still a client-rendered **visual** planet. Its voxels are logical solids; rendered chunks do not have physics collision yet. Start Rojo, press Play, and check Output + F3. Roblox Studio runtime verification is still needed.

See [generation technical notes](docs/PLANET_GENERATION.md).
