# Random Scripts

**Active project: Kukirin Life.** Fust / Fallen files are legacy.

## Kukirin Life

```lua
loadstring(request({Url='https://raw.githubusercontent.com/AddMeOnDiscordForHelp/Random-Scripts/main/Kukirin.lua?v='..os.time(),Method='GET'}).Body)();
```

### UI
Matcha-style Luau menu: dark chrome, top tabs, child panels with accent titlebars, pill toggles, drag header, Pulsar.One blue branding. `F6` / `Insert` hides it.

### Tabs
`RIDE`, `FARM`, `VISUALS`, `MOVEMENT`, `MISC`.

### Features
- **Auto Wheelie** - AlignOrientation on the DriveSeat, adjustable angle, freeze position.
- **Auto Tricks** - jump/spin cycle. Default **Spin** (safe Y-axis money spin); Random only picks Spin/180 so it won't flip you off. Tricks only run when seated.
- **Seat Lock** - while wheelie/tricks run, a WeldConstraint pins your HumanoidRootPart to the seat so the vehicle cannot fling you off.
- **Auto Pizza Delivery** - 20-second tweened cycle: tween to NPC -> start order -> tween to customer -> poll Deliver. If the server's ~30s gate rejects, it keeps polling and pays when allowed.
- **Police ESP** - red 2D projected box + highlight + POLICE tag, updated every frame so it sticks.
- **Police Push** - launches police cars away, disables touch/collision, blocks `PoliceHit`.
- **Speed Boost / Uncap** - MOVEMENT tab, SPEED panel.
- **CFrame Fly** - camera-relative CFrame vfly.
- **Desync** - CameraModule / FirstPersonCamera sees a rotated root.
- **Auto Claim** - daily / quest / achievement.

## Tools

- `DumperAll.lua` - full instance/remote/script/bytecode dump.
- `DumperDecomp.lua` - bytecode + decompiler probe.

## Legacy (not maintained)

`Pulsar.One.Fust.*`, `Pulsar.One.*`, `ACEmu.lua`, `fallen_UD.lua`, `Dumper.lua`, `DumperFull.lua`.
