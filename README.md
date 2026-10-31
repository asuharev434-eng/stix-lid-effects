# STIX Lid Effects

Native MacBook lid effects, based on [Mac Duo by Makito](https://github.com/sumimakito/Mac-Duo), Apache 2.0. macOS 14 or newer.

- Mini control window from the menu bar.
- Eight selectable effects: CRT, frosted glass, waves, paper fold, particles, edge light, cinematic fade, and cracking glass with falling shards; original Duo remains available.
- **Option+B** toggles live Gaussian blur of real windows on every connected display (15 fps, neutral colour, 14 pt radius). **Escape does not dismiss it.** While active, input is suppressed except Option+B. A frozen cursor image is composited into the source before blur; the real pointer is hidden using a transparent cursor and cursor rectangles on the overlay. Images stay in memory; they are never saved or uploaded. This is a visual effect, not a screen lock.
- **Option+M** plays the selected effect across every display and holds a fully black screen until Option+M is pressed again. Repeat the shortcut during animation to reverse smoothly from the current frame. Repeat it from held black to play the same effect in reverse over freshly captured windows. While black, Option+B does not reveal the screen. Black windows require no ongoing capture or GPU animation. During the manual effect and restoration, only Option+M passes through the input shield and the cursor is hidden.
- The cracking-glass effect reveals cracks spreading from an impact point, then drops independent Voronoi glass plates: fine chips around the impact, larger plates at the edges, staggered release, ballistic motion, 3D rotation, dark backs and refractive edge highlights. Depth testing handles overlapping fragments. The manual glass sequence lasts three seconds.
- Login startup via SMAppService, with an on/off switch.
- Only the overlay windows are excluded from capture; the control panel and other app windows remain visible under the blur.
- Sleep and display changes dismiss manual blur to prevent stale overlays. Option+M blackout remains latched and covers the updated display layout until toggled off.
- Lid effects require a built-in lid angle sensor. Manual blur works independently.

## Build and install

Run `swift test`, then `./build.sh`. Copy `build/STIX Lid Effects.app` into Applications and launch. For a stable signed local build, set `SIGN_IDENTITY` to your Developer ID identity before running the build script. Grant Screen Recording permission to **STIX Lid Effects**, then restart it if macOS requests this. Also enable the app in Privacy & Security → Accessibility to use the manual input shield. Local builds are not notarized automatically.

The app registers Option+B and Option+M using Carbon, with key-release tracking to prevent repeated toggles while a key is held. Accessibility permission is required for the temporary input shield. The HID event tap does not record input and is removed when the mode ends; cursor visibility and the previously active application are restored. Tap failure cancels the mode and restores control. If another app has reserved this shortcut, the mini window reports the conflict. Close the mini window to leave the menu bar utility running; use its Quit button to exit.

## Verification

`swift test` covers the existing lid policies and localization, progress validation, shader compilation and GPU-rendered frames for all effects. Pixel tests verify a clear desktop at zero progress, distinct intermediate effects, visible cracking/falling stages and completely black final frames for every manual effect. State tests verify preparation cancellation, indefinite black-screen hold, reverse playback and continuous direction changes. Input-policy tests verify the mode-specific exit shortcut, blocked keys, pointer/scroll/gesture events, and the blurred-cursor compositing test verifies that the pointer is part of the source image.

## Upstream documentation

<div align="center">

# Mac Duo

**Wish you could bring the iPhone Duo effect to your MacBook?**

https://github.com/user-attachments/assets/3ea3b098-c6d2-4398-8f3a-e9087bbb33f2

Close the lid and watch your screen content tilt, blur, and fade as it moves.  
Mac Duo adds this effect to your MacBook, with controls in the menu bar.

**Available in:** English and Simplified Chinese (简体中文).

<img src="./assets/menu.png" width="400" alt="Mac Duo menu">

</div>

<hr>

With the default settings, it's recommended to view the effect in front of your MacBook.

- **Metal rendering:** Uses GPU rendering to apply perspective, blur, and dimming as the lid closes.
- **Live screen content:** Uses ScreenCaptureKit to capture and render screen content in real time.
- **Adjustable perspective:** Tweak the perspective to suit your viewing position and make the effect look more natural.


> [!NOTE]
> Mac Duo is completely **free** to use. Whether you use the app or reuse its code in your projects, please consider [sponsoring me](https://github.com/sponsors/sumimakito) if you find it helpful.
>
> Special thanks to our team at [Moeru AI](https://github.com/moeru-ai) for sponsoring the Apple Developer Program membership used to sign and notarize the prebuilt app here.

## Download

[Download DMG](https://github.com/sumimakito/Mac-Duo/releases/download/dev/Mac-Duo-dev.dmg) | [Download ZIP](https://github.com/sumimakito/Mac-Duo/releases/download/dev/Mac-Duo-dev.zip)

These downloads contain the latest [development build](https://github.com/sumimakito/Mac-Duo/releases/tag/dev) for Apple Silicon and Intel Macs.

Requires macOS 14 or later and a MacBook with a compatible lid angle sensor.
Grant Screen Recording permission when prompted to enable the effect.

## Build

Requires Xcode with Swift 6.0 or later. Run from the project directory:

```sh
./build.sh
```

The script creates `build/Mac Duo.app` with an ad-hoc signature. Open it from Finder, or build and launch with:

```sh
./build.sh --run
```

macOS may require Screen Recording permission again after rebuilding with ad-hoc signing.

## Known limitations

- Only MacBooks with a compatible lid angle sensor can use the effect. The app reports when no sensor is available.
- The sensor must be one macOS marks as built-in. An external display with a similar sensor is ignored.
- The effect applies only to the built-in display.
- The effect stops when macOS sleeps as the lid closes.
- Clicks pass through the effect to the apps underneath.

## Acknowledgements

This project is built with AI assistance.

## License

Licensed under the [Apache License 2.0](LICENSE). Copyright 2026 Makito.

See [NOTICE](NOTICE) for attribution.
