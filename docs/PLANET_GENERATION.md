# Grow a Planet — Procedural Generation Prototype 0.1

## What it does

Press Play in the existing space/starfield place and one 16-stud planet appears at the world origin. Default Roblox character spawning is disabled for this viewer prototype. Nothing is added to or removed from the authored Workspace or Lighting scene.

- **Deterministic surface:** seed 4102026 by default. A three-frequency seeded 3D noise displacement perturbs a sphere radius of 8 studs.
- **True cubic voxels:** 64 cells across at 0.25 studs, with alternate 32-across (0.5) and 16-across (1) resolution levels.
- **Hollow visuals:** occupancy is a temporary 1-byte-per-cell sampling mask, not 262,144 Parts. Only faces adjacent to empty space become quads. No interior cube geometry.
- **Greedy meshing:** neighboring coplanar faces with the same palette color merge into rectangles. Masks check across chunk edges to avoid internal seam faces.
- **Chunking:** 16 cells on each axis per chunk, and one EditableMesh MeshPart per non-empty surface chunk. Flat normal and vertex color attributes preserve the blocky geological look.
- **LOD:** client orbit-camera distance selects 0.25 studs nearby, 0.5 at midrange, 1 at long range, with hysteresis and cancellation of obsolete builds. An initial low-res preview avoids a blank scene during the high-detail pass.
- **Safe fallback:** if EditableMesh cannot be created or converted to a MeshPart, the client switches to 1-stud greedy rectangular Parts, capped at 3000 quads rather than generating tens of thousands of physical voxel Parts.
- **Client visuals:** all players derive the same initial planet from the same shared seed; generated EditableMeshes are not server replicated. Gameplay-authoritative planets, collision, editing, persistence and multiplayer seed distribution are future work.

### Files

- src/shared/ReplicatedStorage/GrowAPlanet/Generation/Config.lua — seed, palette and LOD controls
- src/shared/ReplicatedStorage/GrowAPlanet/Generation/VoxelField.lua — deterministic occupancy/material sampling
- src/shared/ReplicatedStorage/GrowAPlanet/Generation/GreedyMesher.lua — visible greedy face extraction
- src/shared/ReplicatedStorage/GrowAPlanet/Generation/Renderer.lua — chunk MeshParts / fallback Parts
- src/shared/ReplicatedStorage/GrowAPlanet/Generation/SelfTest.lua — Studio-only geometric assertions
- src/game/StarterPlayerScripts/PlanetPrototype.client.lua — camera, generation lifecycle and debugging
- src/game/ServerScriptService/PlanetBootstrap.server.lua — disables avatar auto-spawning

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

Stats show seed, active LOD, renderer, number of chunks/quads, camera distance, and build status. F3 is hidden by default.

### Runtime mesh prerequisites

Roblox requires eligibility and experience opt-in for runtime EditableMesh on published games. Consult Creator Dashboard > Enable Mesh / Image APIs and account verification rules. The client detects creation failures and degrades to coarse Parts. The fallback does *not* deliver the full 0.25-stud visual fidelity. There is no special plugin dependency.

### Smoke tests in Roblox Studio

1. Pull main, start one Rojo server at localhost:34878, connect to the correct Studio place, then press Play.
2. Check Output for **Greedy voxel geometry self-test passed** (single voxel outward normals + two voxels crossing a chunk boundary).
3. Confirm planet generates at origin, with no avatar or baseplate, and your original stars/lighting remain intact.
4. Rotate the camera completely around the planet; look for missing patches and cracks, especially at chunk boundaries.
5. Scroll close and far: the F3 overlay should show 0.25, 0.5, and 1-stud resolution transitions. Try forced 1/2/3 and reset with 0.
6. Press R twice; seeds and geometry should change. Same seed and LOD produce deterministic results.
7. Test with Mesh & Image APIs enabled, then disabled (or on a device/account without entitlement). The fallback should produce a coarse planet instead of an empty screen.
8. Test on phone: touch drag/pinch, no player spawn, and performance. If needed, tune Config thresholds before expanding scope.

## Known intentional limits

- Render-only surface: no voxel edits, mining, destruction, material crafting, creatures, atmosphere, or traits.
- Collision/query/touch are disabled on generated faces for this visual prototype. Future gameplay should use its own collision approach.
- No server physics or EditableMesh replication. Client-generated visualization uses a shared default seed only.
- GPU/CPU capability and Roblox API entitlement vary; mobile may fall back to coarser geometry.
- No Roblox Studio execution or live device benchmark has been performed during the repository implementation.
