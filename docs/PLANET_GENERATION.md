# Grow a Planet — Procedural Generation Prototype 0.4

## Spherical geometry with projected grayscale noise

This revision keeps the exact previous voxel resolution and rendering architecture and changes only shape sampling and surface colors.

- **Nominal diameter:** 16 studs; radius exactly 8 studs.
- **No displacement:** terrain noise is not used to determine whether a voxel is occupied. Only the mathematical sphere radius determines the solid/empty grid cells. The voxelized silhouette still has its natural tiny block steps.
- **Resolution:** 128³ / 64³ / 32³ grid cells in the existing 18-stud sampling box (0.140625 / 0.28125 / 0.5625 stud cells, unchanged).
- **Color projection:** normalized vector from planet center to each outer voxel cell is sampled with one octave of standard 3D Perlin noise. Imaginary height is normalized with contrast to fill the black-to-white grayscale range, so the coloring wraps around the sphere without a longitude seam.
- **Palette:** 16 steps running from true RGB(0,0,0) black to RGB(255,255,255) white. The Perlin value is interpreted as a projected *virtual* height map affecting only color, never geometry.
- **Efficient computation:** buried voxels don't need noise lookup. The existing greedy face meshes and solid-cuboid fallback still use the same chunks and distance LOD.
- **Seeds:** different seeds produce different gray patterns but the same sphere geometry.

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

- src/shared/ReplicatedStorage/GrowAPlanet/Generation/Config.lua — unchanged grid and LOD, fixed sphere radius, grayscale noise scales and colors.
- src/shared/ReplicatedStorage/GrowAPlanet/Generation/VoxelField.lua — seed-independent spherical occupancy, seeded grayscale on the surface, and exposed-solid-cube detection.
- src/shared/ReplicatedStorage/GrowAPlanet/Generation/GreedyMesher.lua — efficient exterior cube-face meshing.
- src/shared/ReplicatedStorage/GrowAPlanet/Generation/CuboidMesher.lua — exact volume-preserving solid cubic Parts merge.
- src/shared/ReplicatedStorage/GrowAPlanet/Generation/Renderer.lua — triangle MeshParts or solid Part cuboids.
- src/shared/ReplicatedStorage/GrowAPlanet/Generation/SelfTest.lua — outward normals, chunk seams, spherical bounds, grayscale palette, and seed-independent geometry.
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
2. Check Output for **Spherical geometry, grayscale colors and voxel tests passed**.
3. Confirm a high-contrast black-and-white grayscale sphere generates at origin, with no avatar or baseplate, and your original stars/lighting remain intact.
4. Rotate the camera completely around the planet; look for missing patches and cracks, especially at chunk boundaries.
5. Scroll close and far: the F3 overlay should show 0.140625, 0.28125, and 0.5625-stud resolution transitions (or coarser fallback when capped). Try forced 1/2/3 and reset with 0.
6. Press R twice; the gray noise pattern should change but the sphere silhouette should not. Same seed and LOD produce deterministic results.
7. Test with Mesh & Image APIs enabled, then disabled (or on a device/account without entitlement). The fallback should produce solid cube/cuboid Parts with flush corners instead of thin overlapping plates.
8. Test on phone: touch drag/pinch, no player spawn, and performance. If needed, tune Config thresholds before expanding scope.

## Known intentional limits

- Render-only surface: no voxel edits, mining, destruction, material crafting, creatures, atmosphere, or traits.
- Collision/query/touch are disabled on generated faces for this visual prototype. Future gameplay should use its own collision approach.
- No server physics or EditableMesh replication. Client-generated visualization uses a shared default seed only.
- GPU/CPU capability and Roblox API entitlement vary; mobile may fall back to coarser geometry.
- No Roblox Studio execution or live device benchmark has been performed during the repository implementation.
