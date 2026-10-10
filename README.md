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

## Prototype 0.5 — 256³ sphere + radial voxel trees

**Planet:** the unchanged 16-stud-diameter sphere uses 256³ / 128³ / 64³ logical voxel LODs. Black-to-white Perlin noise colors the surface, never displacing it.

**Optimization:** the sphere's occupancy is now computed analytically, with meshing of only surface-intersecting chunks. There are no 16.8 million interior voxel objects or buffers. The renderer still uses greedy triangle meshes where supported and solid-cuboid Parts as a safety-capped fallback.

**Tree experiment:** four small seeded voxel trees are placed around the sphere at different angles. Trunks and branches follow radial growth; their constituent cubes remain fully axis-aligned with no rotation. The tree voxels are 2x finer than the planet's voxels at the same LOD: 0.03515625 / 0.0703125 / 0.140625 studs.

No full vegetation gameplay, ecology, player characters, or persistence yet. This is a visual proof-of-concept. The built-in orbital camera and F3 stats continue to work; press R to reroll the seed, 1/2/3 to test LOD, and 0 for automatic detail.

See the generation technical notes in docs/PLANET_GENERATION.md. Studio rendering and device performance require a live test.

Tree fidelity note: test trees must render at exactly twice the voxel resolution of the *displayed* planet. Previous versions could silently drop individual trees to a coarser tier when their 2,200-Part budget was hit, and F3 misleadingly showed the requested cell size. This is corrected: the per-tree Parts budget is 10,000; if it is still exceeded, the whole planet/tree pair changes LOD together to keep the ratio. F3 now reports the actual generated tree voxel size and ratio.
