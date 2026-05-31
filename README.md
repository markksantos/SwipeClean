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

### Core
- **Swipe to clean** — physical, Tinder-style card swiping with rotation, momentum, and haptic feedback
- **Pinch-to-zoom** — zoom into photos on the card for a closer look before deciding
- **Video support** — play button and duration badge on video cards with auto-play option
- **Batch deletion** — nothing is deleted until you confirm. Review everything in a grid before committing
- **Permanent delete option** — choose between Recently Deleted (30-day recovery) or permanent deletion

### Smart Features
- **Smart Cleanup** — AI-powered mode using Vision framework (sharpness, saliency, face detection) to surface low-quality photos first
- **Similar Photos** — groups near-duplicate photos taken within seconds of each other, side-by-side comparison with quality scores
- **Auto Clean Rules** — toggle preset rules like "screenshots older than 6 months" or "videos over 100MB" to auto-flag matching photos
- **Bulk Select Mode** — grid view with tap-to-select for fast batch deletion, accessible via context menu on any album

### Browse & Organize
- **Smart Albums** — All Photos, Screenshots, Videos, Selfies, Live Photos, Favorites, Recents, On This Day, Random, Duplicates
- **Monthly albums** — auto-detected months with photos, each browsable as a separate album
- **User albums** — browse and clean any user-created photo album
- **Storage Breakdown** — visual dashboard with ring chart showing storage usage by category

### Supercut
- **Supercut generator** — create montage videos from any time period with music and AI-scored photo selection
- **Music integration** — Apple Music, local files, or free tracks from Pixabay
- **Beat matching** — transitions sync to the beat of your selected music

### Quality of Life
- **Share Before Delete** — share button on every card so you can send a photo before swiping it away
- **Undo History** — full history panel of every swipe decision with random-access undo on any item
- **Cleanup Reminders** — configurable local notifications (weekly, biweekly, monthly)
- **Streak & Gamification** — daily streaks, 12 milestones, achievements view with progress tracking
- **Session & lifetime stats** — photos reviewed, kept, deleted, storage freed, longest streak
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
| Photo Library (Full Access) | Read photos for swiping, delete photos marked for removal |
| Notifications (optional) | Cleanup reminder notifications |
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
| Notifications | UserNotifications (UNUserNotificationCenter) |
| Persistence | UserDefaults, AppStorage |

## Project Structure

```
Sources/SwipeClean/
├── App/
│   └── SwipeCleanApp.swift              # App entry point, environment setup
├── Core/
│   ├── AlbumProvider.swift              # Album discovery & asset fetching
│   ├── CleanupRuleEngine.swift          # Auto-clean rule matching engine
│   ├── DeleteManager.swift              # Deletion queue & execution
│   ├── PermissionManager.swift          # Photo library authorization
│   ├── PhotoLoader.swift                # Photo loading with sliding window
│   ├── Protocols.swift                  # Shared protocols (testability seams)
│   ├── ReminderManager.swift            # Local notification scheduling
│   ├── SessionTracker.swift             # Session & lifetime statistics
│   ├── SimilarPhotoFinder.swift         # Near-duplicate photo grouping
│   └── StreakManager.swift              # Daily streak tracking
├── Models/
│   ├── AlbumSource.swift                # Album source enum (15+ sources)
│   ├── AlbumSourceGrouper.swift         # Groups sources into home sections
│   ├── CleanupRule.swift                # Auto-clean rule definitions
│   ├── Milestone.swift                  # Gamification milestones & tracker
│   ├── OnboardingPage.swift             # Onboarding page model
│   ├── PhotoItem.swift                  # Photo data model
│   ├── SettingsTypes.swift              # Settings enums & keys
│   └── StorageFormatter.swift           # Byte formatting helper
├── Resources/
│   └── Assets.xcassets/                 # App icon + colors
├── Views/
│   ├── Home/
│   │   ├── AchievementsView.swift       # Milestone grid with progress
│   │   ├── AlbumCard.swift              # Album card component
│   │   ├── AutoCleanView.swift          # Rule-based auto-clean UI
│   │   ├── HomeView.swift               # Main home screen
│   │   ├── ReviewGridView.swift         # Pre-delete review grid
│   │   ├── StatsCard.swift              # Lifetime stats display
│   │   └── StorageBreakdownView.swift   # Storage usage dashboard
│   ├── Onboarding/
│   │   └── OnboardingView.swift         # 3-page animated onboarding
│   ├── Swipe/
│   │   ├── BulkSelectView.swift         # Grid multi-select mode
│   │   ├── CardStack.swift              # Card stack container
│   │   ├── CardStackLayout.swift        # Pure layout math (tested)
│   │   ├── ComparisonView.swift         # Side-by-side similar photos
│   │   ├── DeletionReviewView.swift     # Final deletion confirmation
│   │   ├── HistoryPanelView.swift       # Undo history sheet
│   │   ├── PhotoDetailOverlay.swift     # Zoom / video / Live Photo viewer
│   │   ├── SessionCompleteLogic.swift   # Session summary logic (tested)
│   │   ├── SessionCompleteView.swift    # Session summary screen
│   │   ├── SwipeCardView.swift          # Individual swipe card
│   │   ├── SwipeFormatters.swift        # File-size / duration formatting
│   │   ├── SwipeGestureCalculator.swift # Pure swipe-physics math (tested)
│   │   ├── SwipeHistory.swift           # Swipe decision tracking
│   │   └── SwipeView.swift              # Main swipe interface
│   ├── Settings/
│   │   └── SettingsView.swift           # App settings
│   └── ShareSheet.swift                 # UIActivityViewController wrapper
└── Supercut/
    ├── MusicPicker.swift                # Music selection (Apple Music / Files / Pixabay)
    ├── PhotoAnalyzer.swift              # Vision-based quality scoring
    ├── SupercutComposer.swift           # AVFoundation video montage generation
    ├── SupercutPreviewView.swift        # Preview / save / share the result
    ├── SupercutProgressView.swift       # Generation progress ring
    └── SupercutSettingsView.swift       # Cut speed / length / music + Generate
```

## Configuration

The only optional external dependency is the **Pixabay** free-music library used
by the Supercut "Free Library" tab. It is wired through a gitignored xcconfig so
no key ever lands in source control:

```bash
cp Secrets.example.xcconfig Secrets.xcconfig
# then set PIXABAY_API_KEY=<your key> in Secrets.xcconfig
```

Get a free key at <https://pixabay.com/api/docs/>. If no key is configured, the
Free Library tab degrades gracefully and users can still pick music from Apple
Music or the Files app — the rest of the app is fully functional without it.

## License

MIT License © 2026 Mark Santos

<div align="center">

Built with ❤️ by [NoSleepLab](https://github.com/markksantos)

</div>
