# FORGE and VAULT port

Source: `ufrh/Ruckus` branch `combat-rewrite`, commit `fb87ae52561013554981a7190b69738348fb8b3f`.

## Included

- `src/shared/ReplicatedStorage/FORGE/` — complete shared API, Kernel, UI, and Engine modules
- `src/shared/ServerScriptService/FORGE/` — server implementation, integrated VAULT/Data, optional developer and matchmaking modules
- `src/shared/StarterPlayerScripts/FORGE/` — client launcher and developer controller
- `src/shared/ServerScriptService/VAULT/` — standalone VAULT package from the RUCKUS reference archive
- `src/plugin/FORGEStudio/` — source of the FORGE Studio UI designer
- `forge-studio.project.json` — separate Rojo project for building the Studio plugin
- `grow-a-planet.project.json` — one-place project with a fresh, unused game service and profile structure

## Deliberately excluded

- RUCKUS-specific Services and gameplay modules
- The RUCKUS datastore `RuckusPlayerData` and its profile schema
- RUCKUS game-specific boots, cross-place configuration, references, and scripts
- Automatic FORGE matchmaking/developer test harness startup

## Important runtime and data notes

FORGE 4.4.1 includes an integrated VAULT-derived persistence engine under `ServerScriptService.FORGE.Engine.Data`. The standalone VAULT module lives alongside it at `ServerScriptService.VAULT` for compatibility, but is *not* automatically started. Do not bind the same player profile store in both.

No player schema is installed yet. Before storing data, define a new Grow a Planet schema using a unique datastore name (e.g. `GrowAPlanetPlayerData`), then add the gameplay Services that use it.

Service and Controller folders start empty, by design; the Rojo project creates them as Folder instances. When implementation begins, map the game-specific source folders into these two roots.

The FORGE Studio plugin includes the RUCKUS style preset from its source repository. It is a plugin preset, **not** RUCKUS runtime gameplay, and can be replaced when Grow a Planet's visual direction is finalized.

## Testing checklist

1. Rojo serves `grow-a-planet.project.json` and connects to the new Studio place.
2. Studio hierarchy contains `ReplicatedStorage.FORGE`, `ServerScriptService.FORGE` and `ServerScriptService.VAULT`.
3. Server/client FORGE bootstrap starts without warnings or infinite yields.
4. Studio plugin builds via `rojo build forge-studio.project.json --output FORGEStudio.rbxmx`.
5. Confirm persistence only after the game-specific data schema is defined and the published place has the required datastore access.

Code was imported and mapped but has **not** been executed in Roblox Studio in this environment.
