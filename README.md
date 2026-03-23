<div align="center">

# 🧹 SwipeClean

**Tinder for your camera roll. Swipe right to keep, left to delete.**

[![Swift](https://img.shields.io/badge/Swift-5.9-orange.svg)](https://swift.org)
[![SwiftUI](https://img.shields.io/badge/UI-SwiftUI-blue.svg)](https://developer.apple.com/swiftui/)
[![iOS](https://img.shields.io/badge/iOS-16.0+-black.svg)](https://developer.apple.com/ios/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

[Features](#features) · [Getting Started](#getting-started) · [Tech Stack](#tech-stack) · [Project Structure](#project-structure)

</div>

---

## Features

- **Swipe to clean** — physical, Tinder-style card swiping with rotation, momentum, and haptic feedback
- **Smart sources** — browse by All Photos, Screenshots, Videos, Selfies, Live Photos, Favorites, Recents, or any user album
- **On This Day** — swipe through photos taken on today's date in previous years
- **Random mode** — shuffle your entire library for serendipitous cleanup
- **By Month** — organized monthly buckets so you can clean one month at a time
- **Supercut generator** — create montage videos from any time period with music and AI-scored photo selection
- **Vision AI scoring** — Apple Vision framework analyzes sharpness, faces, and saliency to pick the best photos for supercuts
- **Music integration** — add music from Apple Music, upload from Files, or pick free tracks from Pixabay
- **Beat matching** — supercut transitions sync to the beat of your selected music
- **Batch deletion** — nothing is deleted until you confirm. Undo anytime. Review before committing
- **Session stats** — track photos reviewed, kept, deleted, and storage freed per session and lifetime
- **Zero dependencies** — pure Swift, SwiftUI, PhotoKit, AVFoundation, and Vision. No third-party packages

## Getting Started

### Prerequisites

- macOS with Xcode 15+
- iOS 16.0+ device or simulator
- Swift 5.9+

### Installation

```bash
git clone https://github.com/markksantos/SwipeClean.git
cd SwipeClean
xcodegen generate
open SwipeClean.xcodeproj
```

### Permissions

SwipeClean requires the following permissions:

| Permission | Purpose |
|---|---|
| Photo Library (Read/Write) | Access and delete photos from your camera roll |
| Apple Music (optional) | Pick songs for supercut soundtracks |

## Tech Stack

| Component | Technology |
|---|---|
| UI Framework | SwiftUI |
| Photo Access | PhotoKit (PHAsset, PHImageManager, PHCachingImageManager) |
| Video Composition | AVFoundation (AVAssetWriter, AVMutableComposition) |
| Image Analysis | Vision (VNDetectFaceRectangles, VNGenerateAttentionBasedSaliency) |
| Music Playback | AVKit, MediaPlayer |
| Haptics | UIImpactFeedbackGenerator |
| Persistence | UserDefaults |
| Project Gen | XcodeGen |

## Project Structure

```
SwipeClean/
├── Sources/SwipeClean/
│   ├── App/
│   │   └── SwipeCleanApp.swift
│   ├── Models/
│   │   ├── PhotoItem.swift
│   │   ├── AlbumSource.swift
│   │   ├── AlbumSourceGrouper.swift
│   │   ├── SettingsTypes.swift
│   │   ├── StorageFormatter.swift
│   │   └── OnboardingPage.swift
│   ├── Core/
│   │   ├── PhotoLoader.swift
│   │   ├── DeleteManager.swift
│   │   ├── PermissionManager.swift
│   │   ├── SessionTracker.swift
│   │   ├── AlbumProvider.swift
│   │   └── Protocols.swift
│   ├── Views/
│   │   ├── Swipe/
│   │   │   ├── SwipeView.swift
│   │   │   ├── SwipeCardView.swift
│   │   │   ├── CardStack.swift
│   │   │   ├── PhotoDetailOverlay.swift
│   │   │   └── SessionCompleteView.swift
│   │   ├── Home/
│   │   │   ├── HomeView.swift
│   │   │   ├── AlbumCard.swift
│   │   │   ├── StatsCard.swift
│   │   │   └── ReviewGridView.swift
│   │   ├── Settings/
│   │   │   └── SettingsView.swift
│   │   └── Onboarding/
│   │       └── OnboardingView.swift
│   └── Supercut/
│       ├── PhotoAnalyzer.swift
│       ├── SupercutComposer.swift
│       ├── MusicPicker.swift
│       ├── SupercutSettingsView.swift
│       ├── SupercutProgressView.swift
│       └── SupercutPreviewView.swift
├── Tests/SwipeCleanTests/
│   ├── CoreTests.swift
│   ├── SwipeTests.swift
│   └── HomeTests.swift
└── project.yml
```

## License

MIT License © 2026 Mark Santos

<div align="center">

Built with ❤️ by [NoSleepLab](https://github.com/markksantos)

</div>
