# ttyd APKG for Asustor NAS

A custom Asustor APKG package for [ttyd](https://github.com/tsl0922/ttyd) — a web-based terminal emulator with native TLS support.

## Features

- **Native TLS**: Uses Asustor NAS certificates for HTTPS
- **PAM Authentication**: System login via `login` command
- **Built-in Web Client**: ttyd's default client with WebGL, Zmodem, Sixel, clipboard support
- **Configurable**: Theme, font size, font family via settings.conf
- **Single Session**: One terminal session per connection

## Project Structure

```
TTYD-Pkg/
├── control/                # APKG control files
│   ├── config.json        # Package metadata
│   ├── start-stop.sh      # Service startup script
│   ├── pre-install.sh     # Pre-installation hooks
│   ├── post-install.sh    # Post-installation hooks
│   ├── pre-uninstall.sh   # Pre-uninstall hooks
│   ├── post-uninstall.sh  # Post-uninstall cleanup
│   ├── description.txt    # App Central description
│   ├── changelog.txt      # Package changelog
│   ├── license.txt        # Combined licenses
│   └── icon.png           # 256x256 icon
├── assets/                 # Project assets
│   ├── terminal_web_icon_256x256.png
│   └── screenshot.png
├── build/                  # Build artifacts (gitignored)
├── build.sh               # Build script
└── README.md             # This file
```

## Building

### Prerequisites

- Linux build machine (Ubuntu recommended)
- `curl`, `unzip`, Python 3
- Asustor APKG SDK (downloaded automatically)

### Build Command

```bash
chmod +x build.sh
./build.sh
```

The build script will:
1. Download Asustor APKG Utilities SDK
2. Download ttyd binary (x86_64, statically linked)
3. Verify SHA256 checksum against official `SHA256SUMS`
4. Create APKG package in `build/output/`

## Installation

1. Copy the `.apk` file to your Asustor NAS
2. Open **App Central** in ADM
3. Click **Manual Install** and select the `.apk` file
4. Access ttyd at `https://your-nas:7681`

## Configuration

### Runtime Settings

Edit `/usr/local/AppCentral/ttyd/etc/settings.conf`:

```ini
[General]
port=7681
max-clients=1
ping-interval=5

[ClientOptions]
theme={"foreground":"#d4d4d4","background":"#1e1e1e"}
fontSize=14
fontFamily=monospace
```

### General Settings

| Key | Description | Default |
|-----|-------------|---------|
| `port` | Listen port | `7681` |
| `max-clients` | Max concurrent clients | `1` |
| `ping-interval` | WebSocket ping interval (sec) | `5` |

### Client Options

Any key in `[ClientOptions]` is passed as `--client-option key=value` to ttyd.

### Hardcoded Settings

The following are set in `control/start-stop.sh`:

| Key | Value |
|-----|-------|
| `ssl` | `true` |
| `ssl-cert` | `/usr/builtin/etc/certificate/ssl.crt` |
| `ssl-key` | `/usr/builtin/etc/certificate/ssl.key` |

### Certificate Renewal

ttyd reads its TLS certificate only at startup, and ADM gives apps no notification when it renews the certificate. While the service is running, a small background watcher checks the certificate files once an hour and restarts ttyd when their contents change. If someone is connected at that moment, the restart is postponed until all sessions have ended (rechecked every minute), but for at most 7 days, after which ttyd is restarted anyway and open sessions are dropped. Activity is logged to `/usr/local/AppCentral/ttyd/var/ttyd.log` with a `[cert-watch]` prefix.

## App Central Categories & Tags

These are set when uploading to [Developer Corner](https://developer.asustor.com/app/upload), not in config.json.

**Category**: Utility

**Tags** (space-separated):
```
terminal web shell SSH remote console ttyd
```

## Asustor SDK Reference

- **SDK Download**: [APKG_Utilities_2.0_0517.zip](https://downloadgb.asustor.com/developer/APKG_Utilities_2.0_0517.zip)
- **Developer Guide**: [App Central Developer Guide for ADM 5.1 (PDF)](https://downloadgb.asustor.com/developer/App_Central_Developer_Guide_5.1.0_20251010.pdf)
- **Upload Guide**: [Upload your Application (PDF)](https://downloadgb.asustor.com/developer/Upload_your_Application.pdf)
- **Developer Corner**: [developer.asustor.com](https://developer.asustor.com/tools)

## Publishing to App Central

1. Register at [developer.asustor.com](https://developer.asustor.com)
2. Login to Developer Corner
3. Go to [Upload App](https://developer.asustor.com/app/upload)
4. Upload `build/output/ttyd_1.0.2_x86-64.apk`
5. Fill in app details (name, description, categories)
6. Upload `assets/terminal_web_icon_256x256.png` as the App Central icon
7. Submit for Asustor review

Once approved, your app appears in App Central for all Asustor users.

## License

MIT License - see [control/license.txt](control/license.txt) for details.

ttyd itself is also MIT licensed - see [ttyd/LICENSE](https://github.com/tsl0922/ttyd/blob/main/LICENSE).

## Credits

- **ttyd**: [tsl0922](https://github.com/tsl0922/ttyd) (original author)
- **Packaging**: Mariano Omar Rodriguez

## Version

Current version: **1.0.2**

- ttyd: v1.7.7-40e79c7
- APKG format: 2.0
- Target: ADM 5.x (x86_64)
