# Mission Control

A C# WinForms MDI dashboard application that hosts multiple WebView2 browser panels in a configurable layout with persistent session management and built-in navigation features.

## Features

✅ **True MDI** - Built-in drag, resize, minimize, maximize, and close functionality for all panels  
✅ **Persistent WebView2 Environment** - Logins and sessions preserved across F5 refreshes  
✅ **Popup Auth Handling** - Authentication popups open within the same WebView2 to preserve session cookies  
✅ **YAML-Based Layout** - Flexible panel configuration using `hgroup` (horizontal flex) and `vgroup` (vertical equal division)  
✅ **URL Tracking** - Panel titles automatically update with current page URL  
✅ **Clipboard Logging** - Double-click panel title to copy URL to clipboard with console timestamp  
✅ **F5 Refresh** - Recreates all child windows while preserving the shared WebView2 environment  
✅ **Script Injection** - Optional JavaScript execution on page load via YAML config  
✅ **Dark Theme** - Modern dark UI with styled MDI child windows

## Requirements

- Windows 10/11
- .NET 10.0 Preview (or .NET 8+)
- Microsoft Edge WebView2 Runtime

## Project Structure

```
MissionControl/
├── MissionControl.Forms/
│   ├── Program.cs                 # Main application with MDI container
│   └── MissionControl.Forms.csproj
├── config.yml                     # Layout and panel configuration
├── !runme.cmd                     # Launch script with dotnet watch
└── README.md
```

## Configuration

Edit `config.yml` to define your dashboard layout:

```yaml
width: 2560
height: 1440
hgroup:
  - name: left-col
    width: 1280
    vgroup:
      - name: google-calendar
        title: Calendar
        url: https://calendar.google.com
      - name: google-photos
        title: Photos
        url: https://photos.google.com
  - name: right-col
    width: 1280
    vgroup:
      - name: gmail
        title: Mail
        url: https://mail.google.com
        script: scripts/gmail.js  # Optional script injection
```

### Layout Types

- **`hgroup`** - Horizontal flex layout (children share width based on `width` property)
- **`vgroup`** - Vertical equal division (children split height equally)
- **`panel`** - Single WebView2 panel (implicit when neither group type is specified)

### Panel Properties

- `name` - Internal identifier for the panel
- `title` - Display name shown in the MDI child window title bar
- `url` - Initial URL to navigate to
- `width` - Fixed width in pixels (only for `hgroup` children; omit for flex)
- `script` - Optional path to JavaScript file for injection on page load

## Usage

### Run the Application

```cmd
!runme.cmd
```

Or manually:

```cmd
dotnet watch run --no-hot-reload --project MissionControl.Forms/MissionControl.Forms.csproj
```

### Keyboard Shortcuts

- **F5** - Full refresh (recreates all panels while preserving logins)

### Mouse Actions

- **Drag title bar** - Move MDI child window
- **Drag edges/corners** - Resize MDI child window
- **Double-click title** - Copy current URL to clipboard
- **Minimize/Maximize/Close** - Standard MDI window buttons

## Technical Details

### Persistent WebView2 Sessions

The application uses a shared `CoreWebView2Environment` instance that persists across F5 refreshes. The user data folder is stored at `.WebView2Data/` in the project root, ensuring:

- Login sessions remain active between refreshes
- Cookies and cached data are preserved
- Authentication state is maintained

### Popup Authentication

Authentication flows that open popup windows (e.g., OAuth) are handled via the `NewWindowRequested` event, which redirects the popup URL to the same WebView2 instance. This prevents session loss that would occur if popups opened in separate browser windows.

### Layout Calculation

The layout engine recursively processes the YAML configuration:

1. Measures the MDI container's `ClientSize` (automatically accounts for chrome)
2. Computes panel rectangles based on `hgroup`/`vgroup` nesting and `width` values
3. Creates MDI child forms positioned at calculated coordinates

### Hot-Reload Disabled

WinForms metadata handlers are incompatible with .NET hot-reload, so the application runs with `--no-hot-reload` to avoid runtime errors.

## Development

### Build

```cmd
dotnet build MissionControl.Forms/MissionControl.Forms.csproj
```

### Watch Mode (Auto-rebuild)

```cmd
dotnet watch run --no-hot-reload --project MissionControl.Forms/MissionControl.Forms.csproj
```

### Dependencies

- **Microsoft.Web.WebView2.WinForms** - WebView2 control
- **YamlDotNet** - YAML parsing

## Known Limitations

- Fixed window size (2560×1440 by default, configurable via `config.yml`)
- No scrollbars (panels sized to fit exactly within MDI container)
- Script injection runs on every navigation (cannot be toggled per-page)

## License

MIT
