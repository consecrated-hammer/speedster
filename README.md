# Speedster

A lightweight WoW Classic Anniversary addon that auto-generates a class-based movement speed macro and supports quick keybinding.

## Development Workflow

1. Edit addon code in `Interface/AddOns/Speedster` during playtesting.
2. Sync changes into this repo folder.
3. Commit changes.
4. Build zip for release.
5. Tag release and push.

## Local Commands

### Sync from game AddOns folder
```powershell
Copy-Item -Path "D:\stuff\games\battlenet\World of Warcraft\_anniversary_\Interface\AddOns\Speedster\*" -Destination ".\" -Recurse -Force
```

### Build release zip
```powershell
powershell -ExecutionPolicy Bypass -File "D:\stuff\games\MyAddons\Update-SpeedsterZip.ps1" -UseVersionFromToc
```

## Slash Commands

- `/speedster`
- `/speedsterbind [KEY]`
- `/speedstermacro`
