<img src="HomeBase/logo.png" style="float:right; height:150px" />

#  Home Base

 A C# WinForms MDI dashboard application that hosts multiple WebView2 browser panels in a configurable layout with persistent session management, voice input, and <mark>injected scripts and styles</mark> to customize existing 3rd party web pages like todoist, google, etc.

 To be used like [Skylight](https://myskylight.com), [DAKBoard](https://dakboard.com/), [MagicMirror<sup>2</sup>](https://magicmirror.builders/), [MangoDisplay](https://mangodisplay.com/), etc

<img src="screenshot.png" alt="screenshot" width="700">

## Features

✅ **Good ol' MDI =)** - Built-in drag, resize, minimize, maximize, and close functionality for all panels<br/>
✅ **YAML-Based Layout** - Flexible panel configuration using `hgroup` (horizontal flex) and `vgroup` (vertical equal division)<br/>
✅ **Web Speech API Voice Input** - Voice-to-text powered by browser's native SpeechRecognition API<br/>
✅ **Injected Scripts/Styles** - Panel-specific JS and CSS files loaded automatically based on panel title<br/>
✅ **Panel Activation Awareness** - Scripts can check if a panel is active to prevent interference from backgrounded panels<br/>
✅ **URL Tracking & Dimensions** - Panel titles automatically update with current page URL and inner client dimensions<br/>
✅ **Toolbar Buttons** - Restart, Borderless, Un-Maximize, Voice, Keyboard (OSK) buttons with auto-sizing<br/>

## Requirements

- Windows with .Net 8+ sdk loaded

## Usage

### Run the Application

```cmd
!runme.cmd
```

### Keyboard Shortcuts & Toolbar Buttons

| Action | Button | Shortcut | Effect |
|--------|--------|----------|--------|
| **Restart** | Toolbar | F5 | Recreates all panels, preserves logins |
| **Borderless** | Toolbar | F6 | Toggles window border (maximize space) |
| **Un-Maximize** | Toolbar | — | Restores any maximized child to normal size |
| **Voice** | Toolbar | Ctrl+Shift+V | Starts Web Speech API listening on active panel |
| **Keyboard** | Toolbar | — | Launches Windows On-Screen Keyboard (osk.exe) |

### Mouse Actions

- **Double-click title** - Copy current URL to clipboard

## Configuration

Edit `config.yml` to define your dashboard layout:

```yaml

# start-x: 4500           # Window left edge position
# start-y: 300            # Window top edge position

width: 2560             # Dashboard outer width
height: 1440            # Dashboard outer height

vgroup:
  - title: Our Groceries
    url: https://www.example.com/groceries
    width: 330          # Optional: fixed inner client width in pixels
  
  - hgroup:             # Horizontal flex row
    - title: Google Calendar
      url: https://calendar.google.com
    
    - title: Google Photos
      url: https://photos.google.com
    
    - title: Google Tasks
      url: https://tasks.google.com
```

### Layout Types

- **`hgroup`** - Horizontal flex layout (children share width; panels with `width` property get fixed pixels, remainder flex equally)
- **`vgroup`** - Vertical equal division (children split remaining height equally)
- **`panel` (implicit)** - Single WebView2 panel when neither group type is specified

### Panel Properties

- `title` - Display name shown in the MDI child window title bar (also used for auto-discovery)
- `url` - Initial URL to navigate to
- `width` - Optional: fixed inner client width in pixels (for `hgroup` children; omit for flex width)

### Window Positioning

- `start-x` - Left edge position in screen coordinates (useful for multi-monitor setups)
- `start-y` - Top edge position in screen coordinates

### Layout Calculation & Sizing

The layout engine:

1. Parses `config.yml` to extract window position, outer dimensions, and layout structure
2. Measures the MDI container's `ClientSize` (accounting for title bar and borders)
3. Recursively computes panel rectangles:
   - `hgroup`: Panels with `width` property get fixed pixels; remainder split flex panels equally
   - `vgroup`: All children split height equally
4. Creates MDI child forms positioned at calculated coordinates
5. Validates that all panels fit without scrollbars (rule: Width OK, Height OK)

**Example calculation:**
- Container: 2560 × 1440
- Config width: 2560, height: 1440 → outer bounds
- Panel chrome overhead: ~22 pixels per panel side
- First panel: `width: 330` → 330px inner client width, ~374px outer
- Remaining panels: flex to fill remaining horizontal space


## Project Folder Structure

```
HomeBase/
├── HomeBase.Forms/
│   ├── Program.cs                # Main application with MDI container, layout engine, voice button, toolbar
│   └── HomeBase.Forms.csproj
├── config.yml                    # Layout, panel configuration, and window positioning
├── scripts/                      # and styles
│   ├── voice-input.js            # Web Speech API wrapper (auto-injected to all panels)
│   ├── our-groceries.js          # matched to config.yml panel title
│   ├── our-groceries.css         # ditto
└── !runme.cmd                    # Launch script with dotnet watch
```

### Auto-Discovery of Scripts and Styles

The application automatically discovers and injects JavaScript and CSS files based on panel titles:
(matches by replacing spaces with hyphens and converting to all lowercase)

**Example panel title:** `Our Groceries`  
**Auto-discovered files:**
- `scripts/our-groceries.js` (if present)
- `scripts/our-groceries.css` (if present)

### Voice Input in Panel Scripts

All panels have access to the `startVoiceInput()` and `stopVoiceInput()` function. Example usage:

```javascript
// scripts/our-groceries.js
setInterval(() => {
  const inputField = document.querySelector('input[placeholder="Add item"]');
  if (inputField && document.hidden === false) {
    inputField.addEventListener('focus', () => {
      window.startVoiceInput();
    });
  }
}, 1000);
```

Only the active (focused) panel receives the current voice input. This seemed the best intuitive approach to directing where voice typing happens.

### Panel Title Format

Titles show current URL and inner client dimensions:

```
Our Groceries — www.example.com/groceries (330 × 640)
```

### Hot-Reload Disabled

WinForms metadata handlers are incompatible with .NET hot-reload, so the application runs with `--no-hot-reload`.

### File Watchers

The application automatically reloads when these files change:

- `config.yml` - Triggers full layout recalculation and panel recreation
- `scripts/**/*.js` - Panel-specific scripts re-injected (or auto-discovered for new files)
- `scripts/**/*.css` - Panel styles refreshed

Meant to facilitate convenient deployment of updates from a dev PC to the running panel PC over fileshare.

### Dependencies

- **Microsoft.Web.WebView2.WinForms** - WebView2 control and environment management
- **YamlDotNet** - YAML configuration parsing

## License

MIT

## Anticipated Hardware Pairing

### 12gen Alder Lake N200 based mini PC = $250
- 16GB RAM
- supposed to handle 10-15 webview panels easily

[<img src="MOREFINE-n200-pc.png" alt="monitor" width="400px" />](https://www.amazon.com/gp/product/B0DHXWWWVY)

### 27 inch (same as Skylight Max), 2560 x 1440, 10-point capacitive touch screen = $300 

[<img width="400px" src="https://github.com/user-attachments/assets/a3f4a265-0569-43ca-ad02-6004e8a07426" />](https://www.amazon.com/Pisichen-Touchscreen-2560x1440-10-Point-Computer/dp/B0DKXKL7V7)

### 24 inch, 2560x1440, 10-point capacitive touch screen = $210
[<img src="Pisichen24-monitor.png" alt="monitor" width="400px" />](https://www.amazon.com/gp/product/B0FNM2DSJR)
