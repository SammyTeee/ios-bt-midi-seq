# Pocket Sequence

A native iPhone/iPad step sequencer for the M-VAVE FM-1 and other MIDI synths. SwiftUI + Core MIDI; iOS 17 or newer. No server, account, or third-party app dependencies.

- Eight banks (A–H), each with 16, 32, 48 or 64 sixteenth-note steps.
- One note per step, rests, velocity and gate length.
- Pattern looping or a looping song chain with up to 128 entries, including repeated banks.
- Bluetooth MIDI connection panel, output selection and MIDI channels 1–16. USB MIDI endpoints work too.
- Automatic local save, JSON session import/export, bank copy and clear.
- Dedicated clock queue with timestamped note on/off scheduling. Stop flushes pending output and sends note-offs; panic button for stuck notes.

## Get the IPA without a Mac

Open [Actions](https://github.com/SammyTeee/ios-bt-midi-seq/actions/workflows/ios.yml), select a successful **Build iOS IPA** run, and download **PocketSequence-unsigned-IPA** under Artifacts (requires GitHub login). Extract the ZIP to obtain `PocketSequence-unsigned.ipa`.

GitHub's macOS runner runs core tests, compiles simulator and device apps, and packages the device app. No Apple credentials or certificates are needed in GitHub. **The IPA is unsigned: Windows sideloading software signs it for your phone.** Opening the file directly on your iPhone will not install it.

### Windows installation: Sideloadly

1. Download Sideloadly from its official site: <https://sideloadly.io/>. Follow its current Windows prerequisites for Apple device drivers/iTunes and iCloud; use the links on that site.
2. Connect the iPhone by USB, unlock it, and trust the computer when prompted.
3. Open Sideloadly, select your phone and drag in `PocketSequence-unsigned.ipa`.
4. Enter your Apple account in Sideloadly itself and follow its sign-in / two-factor prompts. Never put Apple passwords in this repository or GitHub secrets.
5. Start installation. On the phone, trust your developer profile under **Settings → General → VPN & Device Management** if prompted.
6. Enable **Settings → Privacy & Security → Developer Mode**, restart and confirm if iOS asks for it. Launch Pocket Sequence and allow Bluetooth.

Free Apple accounts require re-signing every **7 days**. Sideloadly offers automatic refresh while your PC and phone can communicate. Keep the bundle ID and Apple account the same when installing updates to preserve app data, and export songs as backups. Apple's free-account app limits still apply. See the [official Sideloadly FAQ](https://sideloadly.io/faq).

[AltStore Classic on Windows](https://faq.altstore.io/altstore-classic/how-to-install-altstore-windows) is an alternative; it also needs periodic refresh. A paid Apple Developer membership is not required for this personal sideloading route.

## Connect the FM-1

1. Enable FM-1 Bluetooth (long-press HOME/BT according to its manual).
2. In Pocket Sequence tap **Connect**, then choose the FM-1 in Apple's Bluetooth MIDI panel.
3. Tap **Done** and explicitly select the FM-1 in **Output**. Match the MIDI channel to the synth's receive channel.
4. Stop the synth's internal sequencer/arp. Enable notes in the app and press Play.
5. Listen through the synth's speaker or audio output. Bluetooth MIDI sends musical instructions, not audio.

Tap a step to select it, then tap again or use its toggle to enable it. Set pitch, velocity and gate below the grid. Use bank pages to edit beyond 16 steps. Append banks in **Song chain**, choose **Play chain**, then Play. Tap chain entries to remove them; at least one remains. Copying a bank replaces its target. Shortening a pattern retains hidden steps so extending it restores them.

## First-version limits and hardware validation

Playback is foreground-only: the display stays awake during playback, and entering the background stops playback and sends note-offs. Edits are disabled while playing; stop to change tempo, notes, routing or the chain. Bluetooth pairing may interrupt playback, so connect before starting.

This is an external monophonic step sequencer, not an editor for the FM-1's internal sequence memory. It does not yet record incoming MIDI, send MIDI clock/transport, provide chords, swing, ties or CC automation. The external synth plays incoming notes directly without needing clock sync.

CI compilation and model tests cannot verify physical BLE MIDI timing or FM-1 firmware behaviour. Before relying on it live, test: connect → one note → 64-step bank → A/A/B chain → Stop during a long gate → disconnect while playing → reconnect → background the app. Verify no notes stick. USB is a fallback if radio timing is inconsistent.

## Development

On a Mac with Xcode and XcodeGen:

```sh
swift test
xcodegen generate
open PocketSequence.xcodeproj
```

`project.yml` is the source of truth for the generated Xcode project. `Sources/Core` is shared with the Swift package tests. The app compiles those files directly. Project output, credentials, provisioning profiles and IPAs are ignored by Git.
