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

## Prototype 0.1

**Implemented:** one deterministic seed-based 16-stud procedural planet, with 0.25-stud high-resolution cells (64 across), surface-only greedy-meshed exposed quads, chunked EditableMesh rendering, and custom distance-driven 0.25 / 0.5 / 1-stud LOD. A lower-resolution Parts fallback activates if Mesh & Image APIs are unavailable.

A scriptable orbit camera and minimal F3 debugging overlay ship with it. An automatic Studio geometry self-test checks outward face winding and chunk seams. Gameplay data, traits, economy, vegetation, and persistence remain intentionally out of scope.

**Start:** run START_GROW_A_PLANET.bat, connect Rojo, press Play. The starfield stays in Lighting/Workspace and default character spawning is disabled. Use mouse drag or touch drag to orbit and scroll/pinch to zoom. Press R to reroll the seed, 1/2/3 to force LOD, 0 for automatic LOD, and F3 for stats.

See [the generation notes](docs/PLANET_GENERATION.md) for architecture, API eligibility, limitations and smoke-test steps.
