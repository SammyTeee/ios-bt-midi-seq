# Pocket Sequence

A native iPhone/iPad step sequencer for the M-VAVE FM-1 and other MIDI synths. SwiftUI + Core MIDI; iOS 17 or newer. No server, account, or third-party app dependencies.

- Eight banks (A–H), each with 16, 32, 48 or 64 sixteenth-note steps.
- One note per step, rests, velocity and gate length.
- Live pattern launch: tap another bank to queue it for the end of the current pattern. Tap a different bank to replace the queue; tap the queued bank again to cancel. Saved song chains are also available.
- Adaptive piano roll: 16 visible steps in landscape, eight in portrait. Tap to add/remove and drag to move notes.
- Step Record: tap the piano keys to enter notes sequentially; Rest advances with a gap. The cursor wraps at the pattern end.
- Scale lock (root plus major, minor, Dorian, pentatonic or chromatic), repeatable seed generation with density and octave range, and one-level pattern undo.
- Bluetooth MIDI connection panel, output selection and MIDI channels 1–16. USB MIDI endpoints work too.
- Automatic local save, JSON session import/export, bank copy and clear.
- Dedicated clock queue with timestamped note on/off scheduling. Stop flushes pending output and sends note-offs; panic button for stuck notes.

## Get the IPA without a Mac

Open [Actions](https://github.com/SammyTeee/ios-bt-midi-seq/actions/workflows/ios.yml), select a successful **Build iOS IPA** run, and download **PocketSequence-unsigned-IPA** under Artifacts (requires GitHub login). Extract the ZIP to obtain `PocketSequence-unsigned.ipa`.

GitHub's macOS runner runs core tests, compiles simulator and device apps, and packages the device app. No Apple credentials or certificates are needed in GitHub. **The IPA is unsigned: Windows sideloading software signs it for your phone.** Opening the file directly on your iPhone will not install it.

### Windows installation: AltStore Classic (preferred)

Keep AltServer running on Windows with your iPhone on the same Wi-Fi or connected by USB. Put the extracted `.ipa` in Files on your phone, then choose **AltStore → My Apps → +** and select it. Install updates with the same Apple account and bundle identifier to preserve sessions. Export sessions as a backup before updating. Free-account apps need refreshing within seven days. See [AltStore's Windows guide](https://faq.altstore.io/altstore-classic/how-to-install-altstore-windows).

### Alternative: Sideloadly

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
2. Tap the antenna icon → **Connect Bluetooth MIDI**, then choose the FM-1 in Apple's Bluetooth MIDI panel.
3. Tap **Done** and explicitly select the FM-1 in **Output**. Match the MIDI channel to the synth's receive channel.
4. Stop the synth's internal sequencer/arp. Enable notes in the app and press Play.
5. Listen through the synth's speaker or audio output. Bluetooth MIDI sends musical instructions, not audio.

The main screen contains transport, bank launchers, piano roll and entry controls. MIDI, tempo, scale, generator, chain and session controls open in sheets. Turn off iPhone Rotation Lock to use landscape.

Tap an empty piano-roll cell to add a note, tap it again to erase, or drag to change its pitch/step. Each step holds one note. The octave menu selects the visible pitch range; arrows indicate notes outside it. The page menu selects later steps. Gate and velocity controls are below the grid in portrait or under **Note** in landscape.

Enable **Step Record** (REC in landscape), then tap the piano keys down the left edge. Notes are entered consecutively, with automatic page advancement. **Rest →** writes a rest and advances. Tap the grid to reposition the cursor. Input wraps at the end of the bank. While stopped, piano-key input auditions on the selected MIDI output. During playback it edits without sending extra notes.

Tap A–H to launch a bank; if already playing it queues for the next whole-pattern boundary. Green means playing, amber means queued, and the white outline marks the bank being edited. Without a MIDI output, bank taps select for editing only. Use **Edit A/B…** to inspect a different bank without launching it. Follow playing pattern can be toggled there. The latest queued choice wins; tapping the queued bank cancels it. A launch during saved-chain playback takes over into a live loop at the boundary.

**Tools → Scale lock** snaps new/moved notes and generated notes. Existing notes are preserved unless **Snap existing notes** is chosen. **Seed generator** previews a repeatable pattern from a numeric seed, density, octave and range. Apply replaces the edited bank. **Pattern tools → Undo** restores the previous pattern edit while stopped. Copy and clear are also there. Shortening a bank retains its hidden notes.

## Drum machine

Tap **Drums** below the bank buttons to open the standalone drum machine. It has synthesized kick, snare, closed hi-hat and clap sounds, a 16-step pattern, audition buttons, and a 40–240 BPM tempo control. No samples, extra apps, or MIDI connection are required: listen through your phone's audio output or headphones.

Tap numbered steps to toggle hits, then press **Play**. Stop before editing or changing tempo. **Starter beat** restores the default beat and tempo; **Clear** empties the grid after confirmation. The beat and tempo save automatically on this device, separately from MIDI session JSON exports. Opening Drums stops MIDI playback; Done or leaving the foreground stops drum audio. This initial version does not synchronize drums with the MIDI sequencer.

The existing **Build iOS IPA** GitHub Actions workflow includes the new screen, synthesis tests and navigation UI test automatically. Push changes to `main`/`master` (or run the workflow manually after pushing), then download the unsigned IPA as described above. Local Windows development does not require Xcode; actual iOS compilation happens on the macOS runner.

## First-version limits and hardware validation

Playback is foreground-only: the display stays awake during playback, and entering the background stops playback and sends note-offs. Notes can be edited live; an already scheduled note may have up to 20ms of lookahead. Stop to change tempo, pattern length, routing or the saved chain. Bluetooth pairing may interrupt playback, so connect before starting.

This is an external monophonic step sequencer, not an editor for the FM-1's internal sequence memory. It does not yet record incoming MIDI, send MIDI clock/transport, provide chords, swing, ties, glide or CC automation. The external synth plays incoming notes directly without needing clock sync. Existing 0.1 session files remain compatible.

CI compilation and model tests cannot verify physical BLE MIDI timing or FM-1 firmware behaviour. Before relying on it live, test: connect → one note → 64-step bank → A/A/B chain → Stop during a long gate → disconnect while playing → reconnect → background the app. Verify no notes stick. USB is a fallback if radio timing is inconsistent.

## Development

On a Mac with Xcode and XcodeGen:

```sh
swift test
xcodegen generate
open PocketSequence.xcodeproj
```

`project.yml` is the source of truth for the generated Xcode project. `Sources/Core` is shared with the Swift package tests. The app compiles those files directly. Project output, credentials, provisioning profiles and IPAs are ignored by Git.
