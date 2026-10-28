# Waggle Games 🥚

Open-source, motion-controlled party sports for **macOS, Windows and Linux**, played with an
**iPhone as the controller** (gyro + accelerometer). You play as a customisable egg.

Ten mini-games in two sets:

| Classic Five | Holiday Sports |
|---|---|
| Court Rally (racket duel) | Bow Range (archery) |
| Slugger (batting) | Disc Toss |
| Pin Roll (ten-pin rolling) | Foil Duel (fencing) |
| Fairway (golf) | Hoops (free throws) |
| Sparring (boxing) | Paddle Rally (table duel) |

Everything is original: all models are built from primitives in code, all sounds are
synthesised at runtime, and there are no copied assets, names, characters or music. See
[LEGAL.md](LEGAL.md).

## Run it

Requires [Godot 4.4+](https://godotengine.org) (tested on 4.7).

```sh
godot --path game          # or open game/project.godot in the editor and press Play
```

No phone? Keyboard + mouse work: drag the mouse to swing, `Space` = A, `Shift` = B, `F` / arrow keys =
quick swings, `A`/`D` = wrist twist, `Esc` = pause. The phone's pointer also drives the menu; press A to click.

## Phone remote (iOS)

`ios/` is a SwiftUI app (iOS 16+). Generate and open the project:

```sh
brew install xcodegen
cd ios && xcodegen generate && open WaggleRemote.xcodeproj
```

Run it on a real iPhone (the Simulator has no motion sensors). On the game's main menu you will see a
**pairing code** and your computer's IP. Type the code into the app and tap Connect. It auto-discovers the
game on your Wi-Fi, or enter the IP by hand. Hold the phone like a remote, screen up, top edge pointing at the
screen; tap **Recenter** to set "straight ahead". Up to two phones can connect at once. The phone buzzes on hits.

Protocol details: [docs/PROTOCOL.md](docs/PROTOCOL.md).

## Customise your egg

Main menu → **Customize egg**: shell colour, pattern, hat, face and a name. It is saved locally.

## Tests

```sh
godot --headless --path game scenes/smoke.tscn              # loads and plays all 10 games with scripted input
godot --headless --path game scenes/menu_test.tscn          # egg editor + every egg combination
godot --headless --path game scenes/net_test.tscn &         # then: python3 tools/fake_phone.py
```

## Building release binaries

Install Godot export templates, then `tools/build.sh` exports macOS, Windows and Linux builds from your own machine
(no VM needed; see the script header).

## Status

Games are small, playable and tuned by feel rather than by playtesting. Tuning, art and new games are welcome. See
[CONTRIBUTING.md](CONTRIBUTING.md).

MIT licensed.
