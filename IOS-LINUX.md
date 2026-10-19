# Build and install openGym on an iPhone from Linux

The **iOS unsigned IPA** GitHub Actions workflow builds the existing Capacitor iOS
app on a hosted macOS runner. No local Mac, Apple credentials, certificates, or
GitHub signing secrets are required for the build. The output is a device app,
not a simulator build. The exercise media shipped in this repository are bundled
with it for offline use, with their licence notice preserved.

1. Open this fork's **Actions → iOS unsigned IPA → Run workflow**.
2. When it succeeds, download the **openGym-iOS-unsigned** artifact and extract it.
3. Verify the IPA in the extracted directory with
   `sha256sum -c openGym-*-unsigned.ipa.sha256`.
4. Get [iloader from its official releases](https://github.com/nab138/iloader/releases).
   Linux also needs `usbmuxd`; connect an unlocked iPhone with a USB data cable and
   accept **Trust This Computer** on the phone if prompted.
5. Open iloader, sign into your Apple Account directly in that app, select your
   phone, and use **Import IPA** to choose `openGym-…-unsigned.ipa`.
   Let iloader sign and install it. Never put your Apple password, pairing record,
   or signing certificate in GitHub, a public log, or a support conversation.
6. If iOS requests it, trust the developer under **Settings → General → VPN &
   Device Management**. Enable **Settings → Privacy & Security → Developer Mode**
   and complete the requested reboot/confirmation. Then open openGym.

A free Apple Account's development signature normally lasts seven days. Re-sign
and reinstall before it expires, using the same Apple Account; avoid deleting the
app so its local workout data stays in place, and keep an in-app backup. A paid
developer membership has different signing limits. iloader is an independent
third-party signing tool: [its README](https://github.com/nab138/iloader) documents
Linux support, Apple sign-in, and importing an IPA.

The workflow installs dependencies, runs frontend tests with `TZ=UTC`, runs the
project's mobile build checks, archives for physical iOS devices, verifies an
arm64 executable and bundled media, and publishes the unsigned IPA with SHA-256
and the source commit. Failures preserve build logs as a separate artifact.
Artifacts expire after 14 days; rerun the workflow whenever another copy is needed.

To build on a Mac yourself, run `bash scripts/build-ios-unsigned.sh` at the repo
root with Xcode, CocoaPods, and Node 22 installed. Output goes to `ios-artifacts/`.
