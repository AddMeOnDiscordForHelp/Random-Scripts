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
- **Auto Tricks** - jump/spin cycle with Random / Spin / Backflip / Frontflip / 180 modes.
- **Auto Pizza Delivery** - teleports to the delivery NPC, starts an order, teleports to the customer, and polls `FoodDelivery.Deliver` until paid. Tracks deliveries + pizza cash.
- **Police ESP** - red highlight + POLICE tag.
- **Police Push** - launches police cars away, disables touch/collision, blocks `PoliceHit`.
- **Speed Boost / Uncap** - walk speed + ride velocity.
- **CFrame Fly** - camera-relative CFrame vfly.
- **Desync** - CameraModule / FirstPersonCamera sees a rotated root.
- **Auto Claim** - daily / quest / achievement.

### Notes
- Pizza delivery: server accepts after the trip time (~30s). Keep tricks / fly / wheelie off while farming.
- `FARM` tab has a "Teleport to delivery NPC" button and live delivery status.

## Tools

- `DumperAll.lua` - full instance/remote/script/bytecode dump.
- `DumperDecomp.lua` - bytecode + decompiler probe.

## Legacy (not maintained)

`Pulsar.One.Fust.*`, `Pulsar.One.*`, `ACEmu.lua`, `fallen_UD.lua`, `Dumper.lua`, `DumperFull.lua`.
