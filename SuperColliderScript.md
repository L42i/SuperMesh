# Spatial Audio SuperCollider - (10/29/26)
## Overview & Network Requirements

This repository contains the SuperCollider ('sclang') script for a ream-time spatial audio system driven by OSC (Open Sound Control) messages. 
### Network Configuration
* **IP Address:** Ensure your sender script transmits to the correct IP address.
* **Port:** Match SuperCollider's listening port with your sender script.
* **OSC Address Format:**
  * `/person`: Transmits tracking ID and spatial coordinate information (`[id, x, z]`).
  * `/people`: Transmits a list of currently active tracking IDs (`[active_ids...]`).
 
 ---
 ## High-Level Script Logic
  This SuperCollider script is a sound generator that transforms tracking coordinates into audio parameters:
  * **Dynamic Voice Allocation:** It monitors incoming OSC messages and automatically creates a dedicated synthesizer voice for each unique person detected in the space, up to a configurable maximum (`~maxVoices = 100` for now).
* **Coordinate to Audio Mapping:** 
  * The **X coordinate** is mapped directly to oscillator frequency (pitch ranges from 100 Hz to 800 Hz).
  * The **Z coordinate** is mapped to wave distortion amount (ranging from 0.1 to 20.0);
* **Smooth Transitions & Safety:** Incoming coordinates are constrained using `.clip(-1.5, 1.5)` and smoothed via `Lag.kr` to prevent abrupt audio jumps or jitter. Envelopes (`Env.asr`) handle clean fades when voices are created or removed.
* **Master Limiter Protection:** All active voice synths are summed automatically on the server bus and run through a master limiter group (`\masterLimiter`) to cap cumulative volume at `0.8` and prevent digital clipping.

---

## Behind-the-Scenes Execution Order

The entire block is wrapped in a `waitForBoot` routine executed via a `Routine` so everything initializes in the correct asynchronous sequence:
1. **Server Boot:** Starts the audio server engine if not already running.
2. **Synth Compilation:** Compiles the voice and master limiter `SynthDef` templates.
3. **Sync:** Waits for server confirmation (`s.sync`).
4. **Group Initialization + Master Synth:** Sets up voice and limiter groups, positioning the master limiter to execute *after* the voices.
5. **Dictionary Setup:** Initializes the tracking dictionary and voice cap.
6. **OSC Listeners Activation:** Activates `/person` and `/people` handlers.

---
## How to Run the Script

1. Install **SuperCollider** on your system.
2. Open the **SuperCollider IDE**.
3. Create a **New Document** (`Cmd + N` on macOS).
4. Paste the complete script below into the editor.
5. Execute the entire block at once (place your cursor inside the outer parentheses and press `Cmd + Enter`).
---

## SuperCollider Script
```supercollider
(
s = Server.default;

// waitForBoot automatically boots the server if necessary
s.waitForBoot({

    Routine({

        // STEP 1: Define the voice SynthDef
        SynthDef(\voice, {
            |x = 0, z = 0, gate = 1, out = 0|

            var freq, dist, sig, env;

            // Clip coordinates to the mapping range
            x = x.clip(-1.5, 1.5);
            z = z.clip(-1.5, 1.5);

            // Smooth coordinate changes
            x = Lag.kr(x, 0.1);
            z = Lag.kr(z, 0.1);

            // X controls pitch
            freq = x.linlin(-1.5, 1.5, 100, 800);

            // Z controls distortion amount
            dist = z.linlin(-1.5, 1.5, 0.1, 20.0);

            sig = SinOsc.ar(freq);
            sig = (sig * dist).distort;

            // Envelope for smooth creation/removal
            env = EnvGen.kr(
                Env.asr(0.05, 1, 0.3),
                gate,
                doneAction: 2
            );

            sig = sig * 0.15 * env;

            Out.ar(out, sig ! 2);

        }).add;


        // STEP 2: Define the master limiter
        SynthDef(\masterLimiter, {
            var sig;

            sig = In.ar(0, 2);
            sig = Limiter.ar(sig, 0.8);

            ReplaceOut.ar(0, sig);

        }).add;


        // STEP 3: Wait until definitions are loaded
        s.sync;

        "SynthDefs loaded successfully".postln;


        // STEP 4: Create audio groups
        ~voiceGroup = Group.head(s);

        // Limiter group executes AFTER voice group
        ~limiterGroup = Group.after(~voiceGroup);

        ~masterLimiter = Synth.head(
            ~limiterGroup,
            \masterLimiter
        );

        s.sync;

        "Audio groups initialized".postln;


        // STEP 5: Initialize voice management
        ~maxVoices = 100;
        ~voices = Dictionary.new;


        // STEP 6: Listen for individual people
        OSCdef(\personListener, {
            |msg, time, addr, recvPort|

            var id, x, z;

            msg.postln;

            if(msg.size >= 4, {

                // Expected: /person ID x z
                id = msg[1];
                x = msg[2];
                z = msg[3];

                if(~voices[id].isNil, {

                    if(~voices.size < ~maxVoices, {

                        // Create a separate synth for this ID
                        ~voices[id] = Synth.head(
                            ~voiceGroup,
                            \voice,
                            [\x, x, \z, z]
                        );

                        ("CREATED synth for ID " ++ id).postln;

                    }, {
                        ("Voice cap reached: " ++ id).postln;
                    });

                }, {

                    // Update existing person's synth
                    ~voices[id].set(
                        \x, x,
                        \z, z
                    );

                    ("UPDATED synth for ID " ++ id).postln;

                });

            }, {
                "Invalid /person message".warn;
            });

        }, '/person', recvPort: NetAddr.langPort);


        // STEP 7: Listen for active IDs
        OSCdef(\peopleListener, {
            |msg, time, addr, recvPort|

            var activeIDs = msg[1..];

            msg.postln;

            // Iterate over a snapshot of the keys
            ~voices.keys.do({ |id|

                if(activeIDs.includes(id).not, {

                    // Release this person's synth
                    ~voices[id].set(\gate, 0);

                    // Remove from tracking dictionary
                    ~voices.removeAt(id);

                    ("REMOVED synth for ID " ++ id).postln;

                });

            });

        }, '/people', recvPort: NetAddr.langPort);


        "OSC listeners ready".postln;
        ("Listening on port: " ++ NetAddr.langPort).postln;
        "SYSTEM READY".postln;

    }).play(SystemClock);

});
)

