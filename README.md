# ProfileSwap

**One profile per device for World of Warcraft: Forever. Switch your whole setup in one click.**

Play on a PC with mouse and keyboard, on a TV with a controller, on a Steam Deck or streamed to a phone? ProfileSwap stores everything that differs between those setups in a *profile*, and switches it all at once: screen, layout, UI scale, controller mode, which addons are on, and which profile your other addons use.

> **Version 1.0.0.** Made for WoW: Forever (interface 16001). Please report bugs in [Issues](https://github.com/zakarulcodes/ProfileSwap/issues).

---

## Contents

- [Features](#features)
- [Install](#install)
- [Quick start](#quick-start)
- [The window](#the-window)
  - [Overview](#overview)
  - [Profiles](#profiles)
  - [The profile editor](#the-profile-editor)
  - [AddOn Sets](#addon-sets)
- [The on-screen picker](#the-on-screen-picker)
- [Auto mode](#auto-mode)
- [Reloads](#reloads)
- [Data broker (Titan Panel and others)](#data-broker)
- [Slash commands](#slash-commands)
- [FAQ and troubleshooting](#faq-and-troubleshooting)
- [Reporting bugs](#reporting-bugs)
- [Credits and license](#credits-and-license)

---

## Features

Each profile can set any of these:

| Setting | What it does |
|---|---|
| **Display** | Monitor, display mode (fullscreen / windowed) and resolution |
| **Edit Mode layout** | Switches to a saved Blizzard Edit Mode layout |
| **UI scale** | Sets the game's UI scale |
| **Controller + Gamepad UI** | Turns Forever's Gamepad UI on or off. Turning it on also turns the controller on; turning it off leaves the controller working |
| **AddOn set** | Enables a named list of addons and disables the rest |
| **Addon profiles** | Switches the profile of other addons: EllesmereUI, Naowh Forever, and any addon using AceDB (BigWigs, Questie, Zygor, ...) |

Plus:

- **Auto mode**: picks the right profile from your screen resolution at login.
- **On-screen picker** you can place anywhere through Edit Mode, or attach to the minimap, chat or any other frame.
- **Smart reload prompts**: only asks for a reload when the addon list really changed, and cancels the prompt if you switch back.
- **Two skins**: Neon (default) and Plain, switchable in the window footer.

## Install

Install from **CurseForge** (search *ProfileSwap*), or by hand:

1. Download the `ProfileSwap-*.zip` from the [latest release](https://github.com/zakarulcodes/ProfileSwap/releases).
2. Extract it into your Forever AddOns folder so you end up with:
   ```
   World of Warcraft\_forever_\Interface\AddOns\ProfileSwap\ProfileSwap.toc
   ```
3. Start the game (or `/reload`) and make sure **ProfileSwap** is ticked in the AddOn list.

> If you also use **Dynamic Profiles**, disable it. Both addons would fight over the same settings.

## Quick start

A typical PC + TV (or Steam Deck) setup:

1. **On the PC**, set things up how you like them (layout, scale, controller off).
2. Type `/pswap`, open **Profiles**, click **New Profile**.
3. Name it `PC`, set **Display** and **Edit Mode layout**, tick **Automatic for this resolution**, then **Save / Update**.
4. **On the TV or Steam Deck** (controller on), set things up the same way. Turn on the Gamepad UI in the game settings if you use it.
5. Create a second profile `TV` with **Controller + Gamepad UI on** ticked and **Automatic for this resolution** ticked.
6. Done. From now on the right profile is applied when you log in, based on the screen you are using. You can always switch by hand with the picker.

## The window

Open it with `/pswap`. Drag it by the title bar; it remembers where you put it. **Esc** closes it.

### Overview

- **Current Status**: mode (Manual / Auto / None), active profile and current resolution.
- **Quick Start**: short reminder of the steps above.
- **Show on-screen profile picker**: shows or hides the picker.
- **Mute chat output**: hides all ProfileSwap chat messages.
- **Pause all automation**: login and Auto mode stop applying profiles. **Activate** still works, which is handy when an addon update breaks something and you want to keep it switched off.

### Profiles

- **Active Profile** shows what is in use now, marked **AUTO** if it is the automatic profile for its resolution.
- **All Profiles** lists the rest, each with:
  - **Activate**: switch to it now (this also switches to Manual mode).
  - **Edit**: open the profile editor.
  - **Delete**: remove it (asks first).

### The profile editor

| Field | Notes |
|---|---|
| **Profile Name** | Required. Used by the picker and `/pswap <name>`. |
| **Resolution hint** | The screen resolution this profile is for, e.g. `3840x2160`. **Use Current** fills in your current one. |
| **Automatic for this resolution** | Auto mode picks this profile whenever the screen has that resolution. Only one profile per resolution. |
| **Edit Mode Layout Name** | Optional. **Pick Layout** lists your saved layouts. Leave empty to not change layouts. |
| **UI Scale** | Slider from 0.65 to 1.15. |
| **Suppress 'layout applied' chat messages** | Hides the game's chat line when the layout switches. |
| **Controller + Gamepad UI on** | Ticked: controller input and Forever's Gamepad UI on. Unticked: Gamepad UI off, the controller keeps working. |
| **Gamepad UI buttons size** | Size of the Gamepad UI's on-screen button wheel, 0.5 to 2. Edit Mode has no size option for it. |
| **AddOn Set** | **Pick Set** chooses one of your sets, **None** leaves addons alone, **Manage Sets** jumps to the AddOn Sets tab. |
| **Display** | **Mode**: Windowed or Fullscreen (Windowed), plus Fullscreen on clients that still have it. **Resolution**: **Default**, a size from the list, or **Custom...** and type it (e.g. `2560x1080`, then Enter). **Monitor** shows when you have more than one. **Capture Current** copies what the game uses now. **None** leaves the display alone. Picking a resolution also fills in the Resolution hint. |
| **Addon Profiles** | One row per supported addon. Pick the profile it should use, or *(don't change)*. |

Buttons: **Save / Update**, **Apply Now** (activates the saved profile), **Clear Form**, **Delete**, **Cancel**.

### AddOn Sets

An AddOn set is a named list of addons. A profile that uses a set turns those addons **on** and all other known addons **off**.

- **New** creates a set, starting from the addons that are enabled right now.
- **Rename** / **Delete** update every profile that uses the set.
- The right side lists your addons **grouped** (an addon and its modules together). Click a group header to collapse it; tick the header box to tick the whole group.
- **Search** filters by name.
- **All** / **None** tick or untick everything.
- **Save Set** stores your changes. Nothing is saved until you click it.

**New AddOns:** addons installed after ProfileSwap last looked are never switched off by surprise. They show in the **New AddOns** box: tick them to add them to the selected set (then **Save Set**), or **Dismiss** them. A dismissed addon counts as known, so sets that leave it out will switch it off.

ProfileSwap itself is always kept on.

## The on-screen picker

A small bar showing the active profile, for example `Auto: TV`.

- **Left-click**: menu of *Auto (by resolution)* and all profiles.
- **Right-click**: open the Profiles tab.
- **Middle-click**: reload the UI.
- A red **\*** means a reload is waiting. Hover for the list of addons that will change.
- Shows **(Paused)** while automation is paused.

**Moving it:** open Blizzard **Edit Mode** (Esc > Edit Mode), click the ProfileSwap bar and use its settings panel:

- **Width / Height**
- **Anchor To**: Free (drag), Minimap, Chat Frame, or a custom frame
- **Anchor Side**, **Match Width**, **Offset X / Y** (when anchored)
- **Pick Anchor Frame**: hover any frame on screen and left-click to attach the picker to it (right-click or Esc cancels)
- **Clear Custom Anchor**

Dragging the bar in Edit Mode always sets it back to a free position.

## Auto mode

In Auto mode ProfileSwap looks at your screen resolution and applies the profile marked **Automatic** for it:

- 4 seconds after login or `/reload`
- when the resolution changes during play (for example moving the game to another screen)

Choosing a profile by hand switches to **Manual** mode. Choose *Auto (by resolution)* in the picker or type `/pswap auto` to go back.

> Tip: if a profile captures a **Display** with a different resolution than its own **Resolution hint**, Auto mode will pick a different profile next login. Keep them matching.

## Reloads

Some changes only take effect after a UI reload: switching AddOn sets, turning the Gamepad UI on or off, and switching other addons' profiles. When a profile switch changes any of these, a **Reload Required** popup appears with **Later** and **Reload UI**, and lists what changed (for example `Gamepad UI` or `AddOns: 3 to enable, 1 to disable`).

ProfileSwap compares against the addons that were on at your last reload, so if you switch to TV and then back to PC before reloading, the reload is no longer needed and the prompt disappears.

## Game Options menu

**Esc > Options > AddOns > ProfileSwap** lists **Auto (by resolution)** and every profile, each with a **Switch** button, plus **Open ProfileSwap**. Nothing changes until you press a button. Profiles made after login show after a `/reload`. It uses the game's own settings controls, so you can switch profiles with a controller.

## Data broker

If you use Titan Panel, Bazooka, ChocolateBar or another broker display, a **ProfileSwap** entry is available. Left-click to switch, right-click for Profiles, middle-click to reload.

## Slash commands

| Command | Action |
|---|---|
| `/pswap` | Open or close the window |
| `/pswap <profile>` | Switch to a profile by name |
| `/pswap use <profile>` | Same as above |
| `/pswap auto` | Go back to Auto mode |

`/profileswap` works too.

## FAQ and troubleshooting

**Nothing happens at login.**
Check that a profile is ticked as **Automatic** for your current resolution (Overview shows it), and that **Pause all automation** is off.

**The Gamepad UI does not turn on.**
Turn it on once yourself in the game settings, then edit and save the profile that uses it. ProfileSwap remembers the game's own "on" value from that moment.

**An addon is missing from Addon Profiles.**
Only loaded addons appear, and only EllesmereUI, Naowh Forever and AceDB-based addons are supported. Disabled addons do not show until they are enabled and the UI is reloaded.

**My addon profile did not switch.**
The profile you picked may have been renamed or deleted in that addon; chat will say so. Edit the ProfileSwap profile and pick again.

**Switching in combat does nothing.**
Layouts and addon frames are protected in combat. The switch is queued and happens as soon as combat ends.

**The screen flickers when switching.**
That is the game restarting its graphics to apply a captured **Display**. Set Display to **None** in profiles that do not need it.

**I want to start over.**
Delete `WTF\Account\<account>\SavedVariables\ProfileSwap.lua` while the game is closed.

## Reporting bugs

Open an [issue](https://github.com/zakarulcodes/ProfileSwap/issues) with:

1. What you did and what you expected.
2. The error text from BugSack / BugGrabber if there is one.
3. Your WoW: Forever version (shown in the window footer).

## Credits and license

ProfileSwap is written by **zakarulcodes** and released under the [MIT License](LICENSE).

Bundled libraries, included unmodified under their own licenses:

- [LibStub](https://www.wowace.com/projects/libstub) (public domain)
- CallbackHandler-1.0 (Ace3)
- LibDataBroker-1.1
- [LibEditMode](https://github.com/p3lim-wow/LibEditMode) by p3lim (see `Libs/LibEditMode/LICENSE.txt`)

ProfileSwap is inspired by the idea behind *Dynamic Profiles* by TeoDaTank but shares no code with it.
