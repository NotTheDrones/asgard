# asgard

An addon for [Windower](https://www.windower.net/) and Final Fantasy XI focused on improving dualboxing.

## Features

- **Follow** — Alt automatically follows the main character and re-follows across zone changes
- **Attack** — Alt engages or disengages the same combat target as the main via IPC
- **Buffs** — Add, remove, toggle, or cancel status effects on a target character
- **Mount** — Mount or dismount on a target character, with automatic mount selection
- **Command** — Send arbitrary commands to another Windower instance
- **Window positioning** — Automatically move the game window on startup, configurable per role
- **Eval** — Evaluate Lua expressions in the addon context (useful for development)

## Requirements

- [Send](https://docs.windower.net/addons/send/) addon — required for cross-instance commands
- [WinControl](https://docs.windower.net/plugins/wincontrol/) plugin — required only if window positioning is enabled

## Installation

Place the `asgard` folder in your `Windower/addons/` directory and load it with:

```
//lua load asgard
```

## Configuration

Settings are saved to `data/settings.xml` on first load. Edit that file to configure:

| Setting | Default | Description |
|---|---|---|
| `player.main` | `Main` | Character name of the main player |
| `player.alt` | `Alt` | Character name of the alt player |
| `follow.attemptzone` | `true` | Alt attempts to re-follow after a zone change |
| `timing` | `1.2` | Seconds between repeated actions (e.g. multi-buff) |
| `wincontrol.main.enabled` | `false` | Move the main window on startup |
| `wincontrol.main.x` / `.y` | `0` / `0` | Main window position |
| `wincontrol.alt.enabled` | `false` | Move the alt window on startup |
| `wincontrol.alt.x` / `.y` | `3840` / `0` | Alt window position |

## Commands

All commands are available as `//asgard <command>` or `//asg <command>`.

| Command | Alias | Description |
|---|---|---|
| `command send <target> <cmd>` | `cmd` | Send a command to a target character (`all`, `me`, `main`, `alt`) |
| `attack <on\|off\|toggle> <mob_id>` | `atk` | Engage or disengage from a combat target |
| `buffs <add\|remove\|toggle\|cancel> <target> <buff_names>` | `buf` | Manage status effects on a target |
| `follow <on\|off\|toggle>` | `fol` | Follow or stop following the main character |
| `follow attemptzone <on\|off>` | `fol` | Toggle automatic re-follow after zone changes |
| `mount <on\|off\|toggle> <target> [name]` | `mnt` | Mount or dismount on a target character |
| `eval <lua code>` | `evl` | Evaluate a Lua expression in the addon context |
| `debug` | `dev` | Toggle debug logging on/off |
