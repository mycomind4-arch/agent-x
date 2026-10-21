# Wi-Fi Stabilizer for macOS

A native SwiftUI app that helps diagnose an unstable Wi-Fi connection. It measures the radio link with Apple's CoreWLAN framework and separately checks internet and DNS reachability. It offers practical suggestions and an optional reconnect attempt. It cannot amplify the Mac's radio or change the router's physical range.

## What it does

- Shows signal strength, noise, signal-to-noise ratio, transmit rate, channel, and Wi-Fi band.
- Measures internet reachability, TCP connection time, DNS reachability, and three-packet ICMP loss/latency every 20 seconds.
- Separates likely weak Wi-Fi from internet or DNS failures in its guidance.
- Scans nearby networks on demand to estimate channel overlap. Scanning may briefly interrupt Wi-Fi.
- Saves seven days of measurements locally, grouped by a location name you choose.
- Offers an optional automatic reconnect after three failed internet checks and a very weak signal, with a ten-minute cooldown. It is off by default.
- Shows quick status in the menu bar.
- Provides an opt-in Presence page: on-device camera person detection, speech-sound classification, a 60-second anonymous Bluetooth scan, and Wi-Fi signal-change clues.

## Requirements

macOS 13 or later. A Wi-Fi adapter is required for radio metrics. The app has no third-party runtime dependencies.

## Build and run

With Xcode installed, open `Package.swift` in Xcode, select the `WiFiStabilizer` scheme, and run. From the terminal, `swift build` and `swift test` work with a full Xcode installation.

On a Mac with only the Apple Command Line Tools, build a local app bundle with:

```sh
sh scripts/build-app.sh
open .build/local/WiFiStabilizer.app
```

The script signs the local bundle ad hoc. It does not install or publish the app. Run `sh scripts/test-core.sh` for the dependency-free diagnostic self-test.

## Permissions and limits

The app requests Location Services only when you first ask to scan nearby networks. macOS may hide Wi-Fi network names without permission. The scan and signal metrics use supported CoreWLAN APIs; no private Wi-Fi frameworks, administrator access, or network-setting changes are used.

The Presence page requests camera, microphone, and Bluetooth access only when you start those sensors. Camera frames and microphone audio are processed on this Mac and are not saved or uploaded. Bluetooth identifiers are used to deduplicate a single scan and then discarded. Camera detection covers only its field of view; speech can come from a recording; Bluetooth devices may have no person nearby. Wi-Fi signal changes are weak clues and can be caused by interference. The Mac's standard Wi-Fi API does not provide a through-wall image or reliable device-free person count.

Internet tests contact `1.1.1.1:443` and `example.com:443`; the ICMP test pings `1.1.1.1`. Some networks block ICMP; in that case the app leaves packet loss blank and uses TCP connection time for latency. The internet test is a diagnostic sample, not a speed test. Channel overlap is an estimate, not a complete spectrum survey.

Automatic reconnect asks macOS to disconnect from the current access point and relies on macOS to rejoin. It can interrupt active calls or transfers, so it is disabled by default. Router channel, band, and DNS changes remain in router or macOS settings.

Measurements are stored at `~/Library/Application Support/WiFiStabilizer/history.jsonl` and are not uploaded.

## Repository history

This repository previously held the Agent-X Python starter. Its original `main` is preserved at branch [`codex/agent-x-original-20261020`](https://github.com/mycomind4-arch/agent-x/tree/codex/agent-x-original-20261020). The new app replaces that starter in `main`.

See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) for code provenance.
