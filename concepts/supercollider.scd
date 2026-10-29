
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

