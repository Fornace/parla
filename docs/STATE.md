# Where Parla stands

Written 18 October 2026 on the machine that built it.
Repository: https://github.com/Fornace/parla

## Built and verified here

| Thing | Command | Result |
| --- | --- | --- |
| macOS build | `xcodebuild -scheme Parla -destination 'platform=macOS' build` | BUILD SUCCEEDED, Swift 6 language mode, no warnings |
| iOS build | `xcodebuild -scheme Parla -destination 'generic/platform=iOS Simulator' build` | BUILD SUCCEEDED, widget extension embedded |
| App runs | launched the macOS app, installed and launched on the iOS 27 simulator | home, settings and gate states render |
| App Group | automatic signing with `-allowProvisioningUpdates` | capability registered; profile carries `group.app.fornace.parla` |
| Archive | `xcodebuild ... archive -allowProvisioningUpdates` | ARCHIVE SUCCEEDED |
| Export | `xcodebuild -exportArchive -exportOptionsPlist build/exportOptions.plist` | EXPORT SUCCEEDED, `build/export/Parla.ipa`, 2.4 MB |
| Distribution signing | `codesign -dv` on the exported app | `Apple Distribution: Fornace s.r.l. (2V6YSU4HFB)` |
| Store profile | `security cms -D` on `embedded.mobileprovision` | `iOS Team Store Provisioning Profile: app.fornace.parla`, `get-task-allow` false |
| Ship script | `scripts/ship.sh --upload` | archives, exports, then stops at the missing API key with the message below |
| Debrief contract | compiled the real `@Generable` types and built their schemas | `DebriefDraft` and `DebriefNoteDraft` schemas construct |
| Prompts | `Tutor.instructions(...)`, `DebriefEngine.instructions(...)` | 1346 and 948 characters, scene and gentleness rules present |

So the app builds, signs against the Fornace team, archives, and exports a
distribution IPA. What is missing is one credential and one App Store Connect
record.

## Not verified here, and why

### The on-device model never answered on this Mac

```text
SystemLanguageModel.default.availability  ->  unavailable(modelNotReady)
SystemLanguageModel.default.contextSize   ->  0
LanguageModelSession(...).respond(...)    ->  "The model is not available. Try again later."
```

System Settings gives the reason: `Apple Intelligence requires that Mac and Siri
are set to the same language. Currently, your Mac is set to English (Italy) and
Siri is set to Italian (Italy).` Siri's language list has no English (Italy)
option, so enabling Apple Intelligence here means changing the Mac's system
language, which is the owner's decision.

The iOS simulator is no better: it reports `.available`, then every generation
fails at the safety model:

```text
Error Domain=FoundationModels.LanguageModelError Code=-1
  com.apple.SensitiveContentAnalysisML error 15
  ModelManagerServices.ModelManagerError 1001
```

Consequence: the conversation screen and the debrief have never rendered with
real model output on this machine. Everything that does not need the model was
exercised for real: the app launches, the store opens, the gate blocks the call
to action, the widget extension compiles and ships inside the app, and the
screens recorded in `listing/screenshots/` are real captures: the iPhone home
screen and the Mac window. The Mac settings screen renders (it was inspected on
screen while tuning the level chips) but a second later the shared machine's
display slept and the window capture failed, so it is not in the repository.

Capture the two missing screens on a machine with Apple Intelligence running:

```sh
xcodebuild -project Parla.xcodeproj -scheme Parla -destination 'platform=macOS' build
open ~/Library/Developer/Xcode/DerivedData/Parla-*/Build/Products/Debug/Parla.app
# open a room, speak for a minute, close it, screenshot the debrief
```

### The App Store Connect record does not exist yet

`xcodebuild` reaches App Store Connect with the account Xcode already holds
(that is how it registered the App Group and fetched the store profile). The
last step names the remaining gap exactly:

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

The API key named in `~/.agent_credentials/apple/appstore-connect.env` (key id
K6R4NZ46Z5, issuer 69a6de75-aa34-47e3-e053-5b8c7c11a4d1) points at
`~/.agent_credentials/apple/AuthKey_K6R4NZ46Z5.p8`, which is not on this Mac.
Safari is not signed in to App Store Connect either: it sits on
`appstoreconnect.apple.com/login?...&authResult=FAILED` with the Apple ID
prefilled and a password field, and typing that password is out of bounds.

### What one command fixes

Drop the `.p8` at the path above, then:

```sh
scripts/ship.sh --upload
```

That archives, exports, looks up the app record, creates it through the App
Store Connect web API if it is missing, and uploads the build. The App Store
record cannot be created with the API key alone, because App Store Connect has
no create-app endpoint; `asc web apps create` needs a web session, so
`asc web auth login` must have succeeded once (it prompts for the account and
2FA). With the key and that session, the script runs the whole chain.

Xcode's own Organizer can also create the record on the way to an upload. It was
attempted here; this Mac is shared with other agents and the frontmost window
kept changing under the automation, so the clicks landed in other apps' windows.
It is one GUI action away for whoever owns the machine.
