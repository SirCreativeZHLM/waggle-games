# Phone ⇄ host protocol (v1)

UDP, port **47777**, UTF-8 JSON (except discovery). The phone sends ~60 packets/second.

## Pairing
1. Discovery (optional): phone broadcasts the text `WAGGLE?`; host replies `{"t":"host","name":…,"port":47777}`.
2. Phone → host: `{"t":"hello","id":"<uuid>","code":"<4 digits>","name":"<device>"}`.
3. Host → phone: `{"t":"ok","slot":0,"host":"<name>"}`, or `{"t":"no","why":"code"|"full"}`.
The code is shown on the game's main menu and regenerated every launch. Packets from unpaired addresses are ignored.
Slots time out after 2.5 s without packets.

## State (phone → host)
```json
{"t":"s","id":"<uuid>",
 "x":[..3],"y":[..3],"z":[..3],   // device axes expressed in the world frame (rows of CoreMotion's rotation matrix)
 "a":[..3],                      // user acceleration in the device frame, in g (gravity removed)
 "g":[..3],                      // rotation rate, rad/s
 "b":0}                          // bit0 A, bit1 B, bit2 Recenter, bit3 Pause
```
World frame is CoreMotion `xArbitraryZVertical` (z up). The host derives pointer aim from the device Y axis relative to a
calibrated heading, wrist twist from the X axis, and detects swings from `|a|` > 1.25 g (direction and power from a 100 ms window).

## Host → phone
`{"t":"r","s":0.0-1.0,"ms":120}` haptic pulse.
