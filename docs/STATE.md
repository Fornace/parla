# Where Parla stands

Written 18 October 2026 on the machine that built it.

## Built and verified

| Thing | Command | Result |
| --- | --- | --- |
| macOS build | `xcodebuild -scheme Parla -destination 'platform=macOS' build` | BUILD SUCCEEDED, no warnings, Swift 6 language mode |
| iOS build | `xcodebuild -scheme Parla -destination 'generic/platform=iOS Simulator' build` | BUILD SUCCEEDED, widget extension embedded |
| App runs | launched the macOS app, installed and launched on the iOS 27 simulator | home screen renders, gate explains a missing model |
| App Group | automatic signing with `-allowProvisioningUpdates` | capability registered, profile contains `group.app.fornace.parla` |
| Archive | `xcodebuild -scheme Parla -destination 'generic/platform=iOS' archive -allowProvisioningUpdates` | ARCHIVE SUCCEEDED |
| Signing | `codesign -dv` on the archived app | `Apple Development: francesco Frapporti (L7RDY429WX)`, team 2V6YSU4HFB |
| Export | `xcodebuild -exportArchive -exportOptionsPlist build/exportOptions.plist` | EXPORT SUCCEEDED, `build/export/Parla.ipa` |
| Debrief contract | compiled the real `@Generable` types and built their schemas | `DebriefDraft` and `DebriefNoteDraft` schemas construct |
| Prompts | `Tutor.instructions(...)`, `DebriefEngine.instructions(...)` | 1346 and 948 characters, scene and gentleness rules present |

## Not verified here, and why

### The on-device model never answered on this Mac

```text
SystemLanguageModel.default.availability  ->  unavailable(modelNotReady)
SystemLanguageModel.default.contextSize   ->  0
LanguageModelSession(...).respond(...)    ->  "The model is not available. Try again later."
```

System Settings shows the reason: `Apple Intelligence requires that Mac and Siri
are set to the same language. Currently, your Mac is set to English (Italy) and
Siri is set to Italian (Italy).` There is no English (Italy) option in Siri's
language list, so enabling Apple Intelligence here means changing the Mac's
system language, which is the owner's decision.

The iOS simulator is no better: it reports `.available`, then every generation
fails at the safety model:

```text
Error Domain=FoundationModels.LanguageModelError Code=-1
  com.apple.SensitiveContentAnalysisML error 15
  ModelManagerServices.ModelManagerError 1001
```

Consequence: the conversation screen, the debrief and the saved-debrief history
have never been rendered with real model output on this machine. Everything that
does not need the model was exercised: the audio engine starts and installs the
transcriber, the gate blocks the CTA, the store opens, the widget extension
compiles and ships inside the app.

To capture them later, on a Mac or iPhone with Apple Intelligence running:

```sh
xcodebuild -project Parla.xcodeproj -scheme Parla -destination 'platform=macOS' build
open ~/Library/Developer/Xcode/DerivedData/Parla-*/Build/Products/Debug/Parla.app
# start a room, speak for a minute, close it, screenshot the debrief
```

### The App Store Connect record does not exist yet

`xcodebuild` can talk to App Store Connect with the account Xcode already holds,
which is how it fetched profiles and how it explained the last failure:

```text
error: exportArchive Error Downloading App Information
  App record with bundle identifier "app.fornace.parla" not found on App Store
  Connect. Create an app record on App Store Connect, or distribute the app from
  Xcode, and then try again.
```

`asc` has no credentials:

```text
Error: apps: missing authentication. Run 'asc auth login' or create
/Users/ffrappo/.asc/config.json
asc web auth status -> {"authenticated":false,"passwordStored":false}
```

The App Store Connect API key named in
`~/.agent_credentials/apple/appstore-connect.env` (key id K6R4NZ46Z5, issuer
69a6de75-aa34-47e3-e053-5b8c7c11a4d1) points at
`~/.agent_credentials/apple/AuthKey_K6R4NZ46Z5.p8`, which is not on this Mac.
Safari is not signed in to App Store Connect either: it sits on
`appstoreconnect.apple.com/login?...&authResult=FAILED` with the Apple ID
prefilled and a password field, and typing that password is out of bounds.

So the app record and the upload are blocked on credentials, exactly as the task
allowed for. `scripts/ship.sh --upload` does the whole chain in one command once
either of these is true:

- the `.p8` is dropped at the path above (upload half works with the API key),
- or `asc web auth login` has been completed once (app record creation needs a
  web session, because App Store Connect has no create-app endpoint).

One more path that was tried: driving Xcode's Organizer "Distribute App" wizard,
which can create the record itself. This Mac is shared with other agents and the
frontmost window kept changing under the automation, so the clicks landed on
another app's windows. It is one GUI action away for whoever owns the machine.
