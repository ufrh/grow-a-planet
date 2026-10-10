# Grow a Planet — Prototype 0.5 (256³ sphere + radial voxel tree preview)

## Planet geometry

The sphere remains 16 studs across, radius exactly 8. Its black-to-white projected Perlin noise is exclusively a color height map. There is no shape displacement.

All cells occupy a world-aligned grid within the existing 18-stud sampling volume:

| Detail tier | Logical planet grid | Planet cell width | Tree cell width |
| --- | --- | --- | --- |
| Near (1) | 256³ | 0.0703125 studs | 0.03515625 studs |
| Mid (2) | 128³ | 0.140625 studs | 0.0703125 studs |
| Far (3) | 64³ | 0.28125 studs | 0.140625 studs |

256³ is 16,777,216 possible logical grid cells, but no interior voxel Parts or dense occupancy buffers are allocated. Occupancy is analytically calculated by checking squared distance from the sphere center. The greedy mesher skips chunks that cannot intersect the sphere surface, then emits only exposed voxel faces. The existing Parts fallback computes a thin shell, greedily merges exposed cells into solid cuboids, and caps Part counts.

## Tree visualization experiment

Four small trees grow radially outward from different positions, including diagonal orientations. Each tree has a brown trunk, branching woody limbs, and a compact green leafy canopy. All trees use the same seed as the planet; pressing R changes tree shape and color pattern.

No voxel is rotated. TreeGenerator computes a radial up vector from planet center and a perpendicular local frame. It samples trunk cylinders, branch segments and leaf blobs in that mathematical frame, then fills a WORLD-AXIS-ALIGNED cubic voxel lattice wherever those solids intersect cells. The tree grid has 2x finer cells than the planet at the same detail tier.

Each tree uses a stable 2.8125-stud local grid bounding box with 80³ / 40³ / 20³ cells across the distance LOD tiers. The fine tree grid snaps onto the original planetary grid so its cube edges remain aligned. Its root begins slightly inside the mathematical planetary radius, masking gaps around stepped surface voxels.

Only exposed faces of occupied tree voxels become triangles in the preferred renderer. The fallback groups tree surface voxels into full solid cuboid Parts, with a per-tree budget of 2,200; a single tree may drop to a coarser tier or be skipped if it cannot render within that budget. The planet always remains visible.

This is a visual proof of concept. There is no growth simulation, ecology, multiplayer seed synchronization, resource generation, tree picking, avatars, or player movement. Trees are rebuilt with the planet when distance LOD or seed changes.

## Source modules

- Generation/Config.lua — planet and tree resolutions, colors and safety budgets
- Generation/VoxelField.lua — analytic sphere occupancy, projected black-white noise and fallback surface shell
- Generation/TreeGenerator.lua — radial tree volume sampling onto unrotated world voxel cells
- Generation/GreedyMesher.lua — exposed-face merging with chunk-surface pruning
- Generation/CuboidMesher.lua — solid box merging for planet and trees
- Generation/Renderer.lua — triangle EditableMesh or full cuboid Parts; independent tree palette
- Generation/SelfTest.lua — sphere, geometry seams, LOD ratios and tree preview invariants
- src/game/StarterPlayerScripts/PlanetPrototype.client.lua — test tree lifecycle, camera, LOD and F3 diagnostics

## Studio test

1. Pull main, start START_GROW_A_PLANET.bat and connect the normal Rojo plugin to localhost:34878. Press Play.
2. Check the Studio Output for: [Grow a Planet] 256^3 sphere / 2x tree voxel grid geometry tests passed.
3. You should see the same round black/white planet, now with four small brown-and-green trees at different positions around it. Rotate all the way around to inspect diagonal and upside-down growth.
4. Press F3 to check the planet and tree voxel sizes, number of trees, mode and LOD. Press 1/2/3 to switch detail levels and 0 to restore automatic selection.
5. Press R. Tree details and grayscale pattern change with the seed; the sphere silhouette never changes.
6. Benchmark on real target devices. LOD reduces distant detail but does not eliminate near-field generation cost or device-specific EditableMesh memory limits.
7. Runtime EditableMesh depends on experience/account Mesh & Image API entitlement. Parts fallback is safety-capped and can show a coarser resolution.

Workspace and Lighting are intentionally unmapped, preserving the existing starfield. This repository update cannot be considered visually verified until run in Studio.

## Actual tree resolution (fidelity correction)

The tree ratio is guaranteed relative to the rendered planet tier, not just in Config.lua. A previous fallback could silently retry a tree alone at a lower LOD after exceeding 2,200 Parts; the old F3 readout displayed the desired ratio even when this happened. The per-tree budget is now 10,000 merged solid cuboid Parts. If that is exceeded, the whole planet and its trees move to the next coarser LOD *together*. No successful tree silently uses the wrong voxel width. The F3 overlay and Output log report the **actual** successfully generated tree width and measured ratio, or `none` if a tree fails entirely. Rendering still requires a real Studio smoke test.
