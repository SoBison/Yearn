# Yearn

A retro game emulator for iOS, powered by libretro.

## Features

- **Multi-platform support**: NES, SNES, Game Boy, GBA, N64, Nintendo DS, Sega Genesis, PlayStation
- **Modern UI**: Built with SwiftUI for iOS 17+
- **Modular architecture**: Clean separation between UI, core emulation, and platform adapters
- **Open source cores**: Core emulation code is open source (GPL v3)

## Architecture

```
Yearn/
├── Yearn/              # Main iOS App (UI Layer)
├── YearnCore/          # Core Framework (Open Source)
│   ├── Emulator/       # Emulation management
│   ├── Audio/          # Audio output (AVAudioEngine)
│   ├── Video/          # Video rendering (Metal)
│   ├── Input/          # Input handling (GameController)
│   ├── SaveState/      # Save state management
│   └── Libretro/       # Libretro bridge
├── YearnAdapters/      # Platform Adapters (Open Source)
│   ├── NES/            # FCEUmm
│   ├── SNES/           # Snes9x
│   ├── GBC/            # Gambatte
│   ├── GBA/            # mGBA
│   ├── N64/            # Mupen64Plus
│   ├── NDS/            # melonDS
│   ├── Genesis/        # Genesis Plus GX
│   └── PS1/            # Beetle PSX
└── Cores/              # Libretro core binaries
```

## Requirements

- iOS 17.0+
- Xcode 15.0+
- Swift 5.9+

## Building

1. Clone the repository:
```bash
git clone https://github.com/yourusername/Yearn.git
cd Yearn
```

2. Open the project in Xcode:
```bash
open Yearn.xcodeproj
```

3. Build and run on your device or simulator.

## Adding Libretro Cores

Yearn uses libretro cores for emulation. To add cores:

1. Download or compile the libretro core for iOS (arm64)
2. Place the `.dylib` file in the `Cores/` directory
3. The app will automatically detect and use available cores

### Recommended Cores

| System | Core | Source |
|--------|------|--------|
| NES | FCEUmm | https://github.com/libretro/libretro-fceumm |
| SNES | Snes9x | https://github.com/libretro/snes9x |
| GBC | Gambatte | https://github.com/libretro/gambatte-libretro |
| GBA | mGBA | https://github.com/libretro/mgba |
| N64 | Mupen64Plus | https://github.com/libretro/mupen64plus-libretro-nx |
| NDS | melonDS | https://github.com/libretro/melonDS |
| Genesis | Genesis Plus GX | https://github.com/libretro/Genesis-Plus-GX |
| PS1 | Beetle PSX | https://github.com/libretro/beetle-psx-libretro |

## License

- **Yearn App (UI)**: Proprietary
- **YearnCore**: GPL v3
- **YearnAdapters**: GPL v3

The core emulation code is open source to comply with the licenses of the underlying libretro cores.

## Acknowledgments

- [libretro](https://www.libretro.com/) - Unified emulator API
- All the amazing emulator developers whose work makes this possible

## Disclaimer

Yearn does not include any game ROMs. Users must provide their own legally obtained game files.

