# iMusic

<div align="center">

<img src="iMusic/Assets.xcassets/AppIcon.appiconset/icon-180.png" width="120" height="120" alt="iMusic App Icon" style="border-radius: 26px; box-shadow: 0 8px 24px rgba(0,0,0,0.3);" />

### A Native Music Player for iOS 12 & iPhone 6
**The Authentic Apple Music Experience Powered by YouTube Music**

[![Build IPA & DEB](https://github.com/sanjibxdas/iMusic/actions/workflows/build.yml/badge.svg)](https://github.com/sanjibxdas/iMusic/actions/workflows/build.yml)
[![iOS Target](https://img.shields.io/badge/iOS-12.0%20--%2012.5.8-FA243C.svg?style=flat-square&logo=apple)](https://en.wikipedia.org/wiki/IOS_12)
[![Device](https://img.shields.io/badge/Device-iPhone%206%20(A8%20/%20arm64)-000000.svg?style=flat-square&logo=apple)](https://en.wikipedia.org/wiki/IPhone_6)
[![Architecture](https://img.shields.io/badge/Arch-arm64-blue.svg?style=flat-square)](https://en.wikipedia.org/wiki/ARM_architecture_family)
[![License](https://img.shields.io/badge/License-MIT-green.svg?style=flat-square)](LICENSE)

</div>

---

## Overview

**iMusic** is a lightweight, high-performance native iOS music player engineered specifically for legacy devices such as the **iPhone 6 running iOS 12.5.8**.

While modern streaming applications require iOS 15, 16, or later, iMusic brings the contemporary YouTube Music streaming catalog into the classic, iconic **Apple Music iOS 12 interface** — built in pure Swift 5 and UIKit without modern framework bloat.

---

## Navigation & Page Structure

### 1. Home
- **Recent**: Quick access to your last played songs.
- **Listen Again**: Favorites and frequently replayed music.
- **Quick Picks**: Dynamic recommendations based on your listening history.
- **Featured Playlists for You**: Curated high-rotation playlists.
- **Fresh Finds & Old Favorites**: Discover trending releases alongside timeless hits.
- **Hide Shorts Option**: Dedicated toggle in the navigation bar to hide sub-60-second shorts from your library and albums.

### 2. Explore (Moods, Genres, and Categories)
- **Moods & Activities**: Commute, Energize, Feel Good, Focus, Gaming, Party, Romance, Sad, Sleep, Workout.
- **Genres & Regions**: 38+ regional and genre categories including Bengali, Hindi, Punjabi, Tamil, Telugu, Bhojpuri, Desi Hip Hop, Ghazal, Indian Indie, Pop, Rock, K-Pop, J-Pop, Latin, and more.
- Tapping any category opens a dedicated view with curated songs and playlists.

### 3. Library
- **Downloaded Files**: Offline music folder to listen to downloaded songs directly without an internet connection.
- **Local Music**: Fast playback of locally saved songs.
- **Downloaded Playlists**: Manage offline playlists with an option to import playlists from YouTube URLs or JSON backups.
- **Liked Music & Liked Songs**: Complete library of your favorited tracks.
- **Artists You Follow & Recommendations**: Follow your favorite artists.
- **Subscriptions & Podcasts**: Explore podcasts and subscribed releases.
- **Top-Right Account Menu**:
  - **Add YouTube Music Account**: Connect via web sign-in or manual cookie paste to sync liked songs, playlists, and recommendations.
  - **Manage Account**: View connected account details and sign out.
  - **Settings**: Comprehensive audio and download preferences.

### 4. Search
- Live searching across songs, artists, albums, and playlists.
- Filter chips for instant categorization (All, Songs, Albums, Artists, Playlists).
- Trending search suggestions.

---

## Playback & Player Features

- **Instant Playback (No Buffering Delay)**:
  - `automaticallyWaitsToMinimizeStalling = false` and pre-warmed audio buffers start playback within 1-2 seconds (or 0ms for downloaded tracks).
  - Background stream pre-resolving loads the next track before the current one finishes.
- **Responsive Small-Screen Layout (iPhone 6)**:
  - Optimized for 375 × 667 pt displays with non-clipping, proportional constraints.
  - Fully scrollable content view to ensure zero overlap even with large text or accessibility modes.
- **Multi-Source Synced Lyrics**:
  - Line-by-line synchronized scrolling lyrics via LRCLIB with intelligent title cleaning (strips `Official Video`, `feat`, and bracketed tags for 99%+ match rate).
  - YouTube transcript fallback when studio lyrics are not cataloged.
  - Interactive tap-to-seek directly from any lyric line.
- **Working Software Volume Slider**:
  - Live volume slider modulating `AudioPlayer.shared.volume` directly on `AVPlayer`.
- **Offline Download Manager**:
  - Download individual tracks or entire playlists directly to local storage (`.m4a`).
  - Track download states (`.notDownloaded`, `.downloading`, `.downloaded`) with status indicators.
- **Floating Mini-Player**:
  - Frosted translucent dock above the tab bar with progress line, track title, artist, and transport controls.

---

## Settings & Audio Preferences

- **Download Quality**: Standard (128 kbps), High (256 kbps), and Lossless (Hi-Fi).
- **Download over Wi-Fi Only**: Prevents cellular data consumption when enabled.
- **Output Precision**: 16-bit PCM or 32-bit Float.
- **Crossfade**: Configurable transition duration between tracks (Off, 2s, 4s, 6s, 8s, 12s).
- **Export / Import Data**:
  - Export all favorites, playlists, history, and settings to an `iMusic_Backup.json` file.
  - Import previous backups upon updating or reinstalling to restore your library automatically.
- **Play Next on Swipe**: Quick swipe gesture support.
- **App Language**: English, Hindi, Bengali, Spanish, French, German, Japanese.
- **Smart Audio Alignment**: Analyzes audio waveforms and normalizes playback formats.

---

## Installation

Every commit to `main` automatically compiles and packages two production distribution formats via GitHub Actions:
- **`iMusic.ipa`** (for Sideloadly, 3uTools, or Filza with AppSync Unified)
- **`iMusic.deb`** (for Sileo, Zebra, and Cydia package managers)

### Option 1: Sileo / Zebra / Filza (`.deb`) — *Recommended for Jailbroken Devices*
1. Download `iMusic.deb` from the latest [GitHub Actions Workflow Run](https://github.com/sanjibxdas/iMusic/actions).
2. Transfer `iMusic.deb` to your iPhone 6 (via AirDrop, Filza WebDAV/SMB, or SSH into `/var/mobile/Documents/`).
3. Open **Filza**, navigate to `iMusic.deb`, and tap **Install**.
4. Once completed, tap **Respring** (or run `uicache`). **iMusic** will appear on your Home Screen.

### Option 2: Filza with AppSync Unified (`.ipa`)
1. Ensure **AppSync Unified** is installed from `cydia.akemi.ai`.
2. Transfer `iMusic.ipa` to your device and tap **Install** directly inside Filza.

### Option 3: Sideloadly / AltStore / 3uTools (`.ipa`)
1. Connect your iPhone 6 to your computer via USB.
2. Open Sideloadly or 3uTools, select `iMusic.ipa`, and click **Start**.

---

## Building Locally

To build from source on a Mac:
```bash
# Select Xcode 15.4 (last Xcode supporting iOS 12 deployment)
sudo xcode-select -s /Applications/Xcode_15.4.app

# Compile unsigned archive
xcodebuild \
  -project "iMusic.xcodeproj" \
  -scheme "iMusic" \
  -configuration Release \
  -sdk iphoneos \
  -archivePath "build/iMusic.xcarchive" \
  -destination "generic/platform=iOS" \
  ARCHS=arm64 \
  ONLY_ACTIVE_ARCH=NO \
  IPHONEOS_DEPLOYMENT_TARGET=12.0 \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  archive
```

---

## License

This project is licensed under the [MIT License](LICENSE).
