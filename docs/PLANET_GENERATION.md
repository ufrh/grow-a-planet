# Grow a Planet — Procedural Generation Prototype 0.2

## Goal and geological proportions

Earth feels almost smooth at the size of a golf ball. We preserve a visually round planet first and exaggerate its surface relief only enough to register at voxel scale.

- **Nominal diameter:** 16 studs; mean surface radius 8.
- **Hard minimum surface radius:** 7.65 studs (a lowland can dip 0.35 studs below average).
- **Hard maximum surface radius:** 8.35 studs (a peak can rise 0.35 studs above average).
- **Height range:** 0.70 studs total between the lowest and highest potential radii, capped for *every seed*. Noise usually occupies only part of this range; there are no artificial equal-height plateaus.
- **Seed:** 4102026 by default. Three smooth frequencies of 3D noise create modest, coherent, deterministic relief.
- **Sampling volume:** 18 × 18 × 18 studs, *not* 16. The extra margin prevents the outermost voxels from being cut off near terrain peaks. Voxel corners extend slightly beyond the mathematical radius bounds due to their cubic shape.
- **Resolution levels:** 128³ cells (0.140625 studs), 64³ (0.28125 studs), 32³ (0.5625 studs).
- **Surface-only geometry:** occupied interior cells exist briefly as a compact byte mask for sampling and neighborhood tests, but no interior geometry is instantiated.

## Rendering modes

### Preferred: solid voxel surface mesh (EditableMesh)

A full cubic voxel volume is sampled. Only faces of cubes exposed to empty air become geometry. These faces align exactly with the voxel grid corners. Greedy meshing coalesces adjacent coplanar same-color faces into rectangles; each rectangle emits two normal-assigned, vertex-colored **triangles**. This works without the EditableMesh Quads beta. One MeshPart per non-empty 32-cell chunk. Triangles represent the *outer boundary of a solid cube volume*, not thin offset face-plates. Internal faces are omitted because they are invisible.

EditableMesh / MeshPart creation depends on Roblox Mesh & Image API permissions and memory budgets. The renderer automatically chooses a fallback if these operations fail.

### Fallback: actual full solid cubes (merged into cuboids)

The previous Parts renderer spawned narrow surface-facing sheets; their thickness crossed the face plane, creating raised/doubled-looking edges. It is now removed.

In fallback mode we first identify all **exposed solid voxel cells** in a one-cell-thick shell. Neighboring exposed voxels of the same material are greedily merged in three dimensions into rectangular **solid boxes** with exact grid-aligned positions and sizes. A merged box occupies the same volume as its constituent full cube cells, with no sheet overlap or offset at corners. Hidden inner voxels remain absent from the actual Parts geometry.

For stability, we *count* merged boxes before creating Parts. If more than **6,500** would be needed for a planet, fallback automatically chooses the next coarser LOD and regenerates. A restricted client may therefore not display the full 128³ resolution; enabling Mesh & Image APIs is the route to full-quality visuals.

Distance LOD uses an automatically switching near/mid/far resolution with hysteresis, and a low-resolution preview appears first. Mesh generation remains fully client-side and client-local. Physics collision is disabled; seed synchronization, digging, crafting, atmosphere and progression are future systems.

### Files

- src/shared/ReplicatedStorage/GrowAPlanet/Generation/Config.lua — sample box, minimum/maximum surface radii, LOD and budgets.
- src/shared/ReplicatedStorage/GrowAPlanet/Generation/VoxelField.lua — seeded occupancy and exposed-solid-cube detection.
- src/shared/ReplicatedStorage/GrowAPlanet/Generation/GreedyMesher.lua — efficient exterior cube-face meshing.
- src/shared/ReplicatedStorage/GrowAPlanet/Generation/CuboidMesher.lua — exact volume-preserving solid cubic Parts merge.
- src/shared/ReplicatedStorage/GrowAPlanet/Generation/Renderer.lua — triangle MeshParts or solid Part cuboids.
- src/shared/ReplicatedStorage/GrowAPlanet/Generation/SelfTest.lua — outward normals, chunk seams, bounds, voxel volume preservation.
- src/game/StarterPlayerScripts/PlanetPrototype.client.lua — camera, generation, LOD and diagnostics.
- src/game/ServerScriptService/PlanetBootstrap.server.lua — disables default character spawning.

### Camera & development controls

| Control | Action |
| --- | --- |
| Left/right mouse drag | Orbit |
| Touch drag | Orbit |
| Mouse wheel / touch pinch | Zoom |
| R | Random new seed (local preview only) |
| 1, 2, 3 | Force high, medium, low LOD |
| 0 | Automatic distance LOD |
| F3 | Toggle stats overlay |

Stats show seed, active LOD, renderer, chunks, exposed faces or solid cubes/cuboids, surface radius bounds, camera distance and build status. F3 is hidden by default.

### Runtime mesh prerequisites

Roblox requires eligibility and experience opt-in for runtime EditableMesh on published games. Consult Creator Dashboard > Enable Mesh / Image APIs and account verification rules. The client detects creation failures and degrades to coarse Parts. The fallback uses solid cubes and dynamically chooses a safe LOD; full 128³ fidelity may require the mesh path. There is no special plugin dependency.

### Smoke tests in Roblox Studio

1. Pull main, start one Rojo server at localhost:34878, connect to the correct Studio place, then press Play.
2. Check Output for **Solid voxel, chunk seam and terrain bound self-tests passed**.
3. Confirm planet generates at origin, with no avatar or baseplate, and your original stars/lighting remain intact.
4. Rotate the camera completely around the planet; look for missing patches and cracks, especially at chunk boundaries.
5. Scroll close and far: the F3 overlay should show 0.140625, 0.28125, and 0.5625-stud resolution transitions (or coarser fallback when capped). Try forced 1/2/3 and reset with 0.
6. Press R twice; seeds and geometry should change. Same seed and LOD produce deterministic results.
7. Test with Mesh & Image APIs enabled, then disabled (or on a device/account without entitlement). The fallback should produce solid cube/cuboid Parts with flush corners instead of thin overlapping plates.
8. Test on phone: touch drag/pinch, no player spawn, and performance. If needed, tune Config thresholds before expanding scope.

## Known intentional limits

- Render-only surface: no voxel edits, mining, destruction, material crafting, creatures, atmosphere, or traits.
- Collision/query/touch are disabled on generated faces for this visual prototype. Future gameplay should use its own collision approach.
- No server physics or EditableMesh replication. Client-generated visualization uses a shared default seed only.
- GPU/CPU capability and Roblox API entitlement vary; mobile may fall back to coarser geometry.
- No Roblox Studio execution or live device benchmark has been performed during the repository implementation.
