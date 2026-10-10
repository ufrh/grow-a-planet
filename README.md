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

## Prototype 0.3 — spherical grayscale microvoxels

The planet uses the existing **128 × 128 × 128** cubic sampling grid, 64³/32³ distance LOD, and 18-stud sampling box. The visible planet is a clean **16-stud-diameter sphere** (fixed radius 8). No noise is applied to shape or height.

Instead, three seeded 3D noise layers are projected along the normalized spherical directions to paint a subtle **white-to-gray** voxel pattern on its surface. Rerolling a seed changes only the color pattern, not the silhouette.

The previous efficient exterior triangle mesh, real solid-cube/cuboid Parts fallback, safety budget, chunking, camera and controls remain unchanged. Rendering and FPS still require Roblox Studio verification.

See [generation technical notes](docs/PLANET_GENERATION.md).
