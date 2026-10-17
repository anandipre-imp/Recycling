# Clip Matcher (iPhone)

An iPhone app that looks through the videos in your camera roll, works out what's in each one,
groups the ones that belong together, and — when you type what you want to make
("beach trip reel", "my dog compilation", "YouTube travel vlog") — suggests videos you could
make and cuts them for you.

**Works on every iPhone that runs iOS 17 (iPhone XS / XR and newer).** Video analysis uses Apple's
Vision and Natural Language frameworks, which every one of those phones has — Apple Intelligence
is *not* needed. Titles and hooks come from a built-in template writer (several variants per
theme, filled with the place, month and clip count). On phones that do have Apple Intelligence
(iPhone 15 Pro and newer, iOS 26+, switched on) it polishes that copy; there's a toggle in the
Library tab to turn it off and see exactly what other phones get.

**Your videos never leave the phone.** The only thing sent anywhere is a GPS position to Apple
Maps to get a place name for titles, and that can be switched off.

## What it does

1. **Asks for photo-library access** and lists every video.
2. **Analyzes each video once** (in the background while the app is open) and caches the result:
   - scene/object tags, e.g. `beach 92%`, `dog 88%`, `sunset sunrise 71%` (~1,300 possible tags)
   - a visual fingerprint, so similar-looking videos can be matched
   - number of faces, date, location, and the most interesting moment in the clip
3. **Groups videos that go together** — they look alike, or were shot around the same time and place.
4. **Create tab:** you type what you want; it understands content words ("trip" → beach, airport,
   landmark…), the format ("reel"/"TikTok" → 9:16, "YouTube" → 16:9), ranks matching videos,
   groups them and turns each group into an idea with a title, an opening hook and a clip list.
5. **Make video:** stitches ~2–3 s highlights from each clip into a ~30 s video, cropped to the
   right format, and saves it to Photos.
6. **Library tab:** analysis progress, the most common tags in your videos, and groups found
   automatically.

## Running it on your iPhone

You need a Mac with Xcode 16 or newer (Xcode 26 to get the Apple Intelligence title/hook writer)
and an iPhone on iOS 17+. A free Apple ID is enough to run it on your own phone.

```sh
brew install xcodegen          # one-time
cd GalleryMatcher
xcodegen generate              # creates GalleryMatcher.xcodeproj from project.yml
open GalleryMatcher.xcodeproj
```

In Xcode: select the **GalleryMatcher** target → *Signing & Capabilities* → choose your team,
and change the bundle identifier (e.g. `com.yourname.clipmatcher`). Plug in your iPhone, pick it
as the run destination and press ▶. The first time, approve the developer profile on the phone in
*Settings → General → VPN & Device Management*.

Run the unit tests with ⌘U (they cover query understanding, matching, grouping and clip planning).

Tip: the simulator has almost no videos, so test on your real phone. The first scan of a big
library takes a while (roughly 0.3–1 s per video, longer for videos that must be downloaded from
iCloud); it resumes where it left off.

## How the code is organised

```
GalleryMatcher/
  App/        GalleryMatcherApp (entry point), LibraryModel (app state: scanning, search, export)
  Core/       Pure logic, no iPhone APIs — easy to test and to reuse on a server later
    Models.swift          VideoAnalysis, VideoLabel, ContentFormat
    Themes.swift          content types (travel, food, pets…) and the words that map to them
    QueryMatcher.swift    turns the typed request into terms and ranks videos
    Clusterer.swift       groups videos by look / time / place
    ClipPlanner.swift     picks which seconds of each video to use
    ContentIdeas.swift    turns groups into ideas (title, hook, clips)
    IdeaWriter.swift      title/hook templates — the writer every iPhone uses
  Services/   iPhone-specific pieces
    PhotoLibraryService   Photos access, thumbnails, saving
    VideoAnalyzer         on-device Vision analysis of sampled frames
    AnalysisStore         on-device cache of results
    EmbeddingSimilarity   meaning-based word matching ("puppy" ≈ "dog")
    OnDeviceIdeaGenerator Apple Intelligence polish (only where available; optional)
    PlaceNamer            GPS position -> town name for titles
    CompilationExporter   stitches clips into the final video
  Views/      SwiftUI screens
GalleryMatcherTests/      unit tests for Core
```

Tuning knobs worth playing with once you see real results:
`Clusterer.visualThreshold` (how alike videos must look), `Clusterer.eventWindow`/`eventRadiusMeters`,
`QueryMatcher.minimumScore`, `VideoAnalyzer.framesPerVideo`, and the word lists in `Themes.swift`.

## Road to publishing

Things to add before an App Store release, roughly in order:

- **Smarter AI ideas on every phone:** Apple Intelligence only exists on recent Pro/16-series
  phones. To give every user LLM-quality ideas, plug a cloud model (e.g. Claude) in behind
  `ContentIdeaGenerator`, sending only the text tags, never the videos, through your own small
  backend so the API key isn't in the app. Make it opt-in and say so in the privacy policy.
- **Audio understanding:** Apple's SoundAnalysis framework can tag music, laughter, speech, crowds —
  useful for picking highlight moments and for queries like "funny moments".
- **Better editing:** music with beat-synced cuts, transitions, on-screen hook text, letting the
  user reorder/remove clips before export.
- **Background scanning:** `BGProcessingTask` so large libraries finish analyzing overnight while
  charging; move the cache from a JSON file to SwiftData/SQLite once libraries get big.
- **Photos & Live Photos** as sources, not just videos.
- **App Store basics:** privacy policy and "nutrition label" (data not collected), app icon,
  onboarding polish, handling *Limited* photo access, and a paid Apple Developer account ($99/yr).
