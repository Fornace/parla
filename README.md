# Parla

A language practice app for iPhone and Mac that holds a spoken conversation with
an on-device model, in a scene you choose, and then tells you gently what to
change.

The pain it removes: you can read and understand a language and still freeze
when you have to speak it. Tutors cost money and a diary slot; drill apps make
you tap word tiles. And being corrected mid-sentence is what stops people
speaking at all. Parla gives you a patient conversation partner at 11pm that
never interrupts, and keeps every correction until after you hang up.

## The loop

1. **Pick a room.** A café before closing, a flat viewing, a delayed train, a
   first day at the studio, dinner with the in-laws. Each room has a character,
   a goal and a level.
2. **Talk.** The tutor opens the scene in your target language, you answer out
   loud, it keeps the conversation going. Hands free: it waits for you to stop
   speaking.
3. **Read the debrief.** One warm sentence about how it went, two or three
   things that landed (quoted from your own words), up to three small changes
   with the sentence a native speaker would have said, and two or three phrases
   worth carrying into tomorrow.
4. **Come back.** Sessions, corrections and phrases are kept on device. Two
   widgets show the streak and the last phrase.

## Everything happens on the device

- Conversation and debrief: the system language model through
  **Foundation Models** (`LanguageModelSession`, structured output with
  `@Generable` for the debrief).
- Speech to text: **SpeechAnalyzer** with `SpeechTranscriber`, streaming, with
  volatile results and a silence endpoint.
- Text to speech: **AVSpeechSynthesizer**, best installed voice for the language.
- Storage: **SwiftData**. Widget data: an App Group snapshot.
- Shortcuts, Siri and the widgets: **App Intents**.

No account, no server, no audio leaving the device. Microphone audio is
transcribed locally and never uploaded.

## Requirements

- iOS 26 or later, macOS 26 or later.
- Apple Intelligence turned on, with the on-device model downloaded. The app
  explains what is missing instead of failing silently:
  `deviceNotEligible`, `appleIntelligenceNotEnabled` and `modelNotReady` each
  get their own screen.
- Speaking: microphone and speech recognition permission.

## Build

The Xcode project is generated, so `project.yml` is the source of truth.

```sh
xcodegen generate
xcodebuild -project Parla.xcodeproj -scheme Parla -destination 'platform=macOS' build
xcodebuild -project Parla.xcodeproj -scheme Parla -destination 'generic/platform=iOS Simulator' build
```

Screenshots and app icon art live in `artifacts/images/`; the icon set is
compiled into `Parla/Resources/Assets.xcassets`.

## Ship

```sh
scripts/ship.sh            # archive and export a distribution IPA
scripts/ship.sh --upload   # create the app record if needed, then upload
```

See `docs/STATE.md` for exactly how far publishing got on this machine and what
is missing, and `listing/` for the App Store copy.

## Layout

```
Parla/
  App/        entry point, routing, deep links
  Engine/     tutor prompt and session, debrief generation, speech in, speech out
  Model/      SwiftData records, preferences
  Views/      home, conversation, debrief, history, phrases, settings
  Design/     palette, type, components
Shared/       catalog, records, app group snapshot, App Intents (app + widget)
ParlaWidget/  streak and phrase widgets
scripts/      ship.sh
listing/      App Store metadata and captures
```

## Design

Warm paper, one terracotta accent, flat colour only, hairline rules instead of
shadows, and a serif for the words that matter (room titles, the tutor's own
speech, the corrected sentences). The conversation happens on a dark stage so
the room you are in disappears; the debrief returns to paper.
