s.boot; //Ensures that the server is running, engine started --> Since the lang and audio engine are separate things
//This next block replaces the 4 PureData objects:
//Netreceive -u -b 9005 --> This one was opening the socket and listening for binary UDP
//Uscparse --> Decodes binary into usable list, Trim --> cleans list, Route Person People --> "person" divisions
//thisProcess.openUDPPort(9001);

Server.default.waitForBoot({
	~limiterGroup = Group.new; //Group is like a container so we can position things in the signal chain

	SynthDef(\masterLimiter, {
		var sig = In.ar(0,2); //Whatever is currently on the main output "bus" is grabbed
		sig = Limiter.ar(sig, 0.8); //Caps the volume so it can't exceed the safe level

		ReplaceOut.ar(0,sig) //Writes this new signal back to main output
	}).add;

	Synth.after(~limiterGroup, \masterLimiter); //Ensures limiter carries out after everything. That way it can ensure all the voices added together is controlled rather than sooner
});

SynthDef(\voice, {|x = 0, z= 0, gate =1, out =0, freq=100, cutoff=1000|

	var note, midinote;
	var resonance;
	var scale, inScale;
	var env, sig;

	x = x.clip(-100, 100); //These are safety nets to if out of bounds then it gets capped here
	z = z.clip(-100,100);

	//One of the problems from before was jittery shifts, we want the sound to move slowly towards it
	x = Lag.kr(x,0.1);
	z = Lag.kr(z, 0.1);

	/*//Defining the pitch
	note = (((x * (-1)) +3)*10)+36; //flip it, shift it, scale up, set a musical baseline (same as prev)
	note = note.asInteger; //rounding down to a whole number since notes are steps

	scale = [0, 2, 4, 5, 7, 9, 11]; //These are the notes allowed in a major scale
	inScale = scale.includes(note % 12); //this sees if it lands on the scale
	midinote = note + (if(inScale, 0, -1)); //If not on the scale then we nudge it down one semitone so it fits

	midinote = midinote.clip(24, 96); //Keeping the note in a good audible range
	freq = midinote.midicps; //Converting the note number into Hz*/

	//Now writing the brightness of the sound from z
	//cutoff = (((z*(-1)) + 3) * 300) + 200; //Flips, shifts and scales the value into a frequency range ov around 200 Hz
	//cutoff = cutoff.clip(200,8000); //Safety net as before, keeps it in a safe range

	freq = x.linlin(-1.5, 1.5, 100, 800);
	freq = freq.clip(100, 800);

	sig = SinOsc.ar(freq);

	env = EnvGen.kr(
    Env.asr(0.05, 1, 0.3),
    gate,
    doneAction: 2
	);

	sig = sig * 0.15 * env;

	Out.ar(out, sig ! 2);
	
	/*
	resonance = 2; //Fixed amount - so that energy doesn't pile up at the center frequency

	sig = SinOsc.ar(freq, 0, 10, 0); //Creates a sound, a buzzy tone that matches the frequency we generated
	sig = BPF.ar(sig, cutoff, 1/resonance); //Filtered, brightness controlled by our cutoff

	env = EnvGen.kr(Env.asr(0.05, 1, 0.3), gate, doneAction: 2); //Smooth fade in/out instead of on/off
	sig = sig *0.1 *env; //Volume turned down and faded

	Out.ar(out, sig!2); //output sent to both speakers
	*/
}).add;


/*
OSCdef(
	\personListener, //Label for the listener (like naming a subpatch)
	{ |msg, time, addr, recovPort| //Msg is equivalent of what comes out of oscparse + trim. Its an already parsed list of values so there's no manual decoding needed.
		var id, x, z;
		id = msg[2];  //Similar to the unpack ff objects. First outlet of msg is the OSC address, real data starts at msg[1] as the id. This is the tracking id we can use
		x = msg[3]; //First coordinate, equivalent to the second unpack ff
		z = msg[4]; //Second coordinate

		//Print statement check so data is arriving correctly
		//("Person " ++ id ++ " at x=" ++ x ++ " z=" ++ z).postln;
		msg.postln;
		b.set(\freq, x.linexp(-1.5,1.5,80,2000).round(50))
	},
	'/person', //Only run the function for messages addressed to /person --> Also equivalent to "route person people" in the previous code.
	recvPort: 57120 //What port are we listening on, "netreceive -u -b 9005"
);
//This next function --> other outlet of "route person people" but it looks at the people side
//Essentially beofre the patch used conditional logic to check whether a given tracking ID was active
*/

/*
OSCdef(
	\peopleListener,
	{ |msg, time, addr, recvPort|
		msg.postln; //Printing msg for now, we can put the active/inactive ID check logic here later
	},
	'/people', //People outlet of the "route person people"
	recvPort: 9005 //Same port, both listeners share it
);
*/

//I wanted to put a cap on the total number of users rather than hardocding the value
//This way if only one person is in the space, we only have to spend resources on 1 voice
~maxVoices = 100;
~voices = IdentityDictionary.new; //ID mapping dictionaries in sclang. This dictionary replaces the hardcoded "voice" boxes and also the "route 1 2 3 4 5 6 7 8" object that hardwired ID.
//ID = Key
//Synth = Value and is created only when the ID shows up

//This function runs every time another person message comes in

OSCdef(\personListener, {|msg, time, addr, recvPort|
	var id, x, z;
	//Just the person's tracking ID numb
	id = msg[1];
	x = msg[2]; //x coordinate
	z = msg[3]; //z coordinate

	//Print statement check so data is arriving correctly
	msg.postln;

	if(~voices[id].isNil, { //If we already don't have a voice for this person
		if(~voices.size< ~maxVoices, { //If the cap hasn't been reached
			~voices[id] = Synth(\voice, [\x, x, \z, z]); //Make a new voice
			("CREATED synth for ID " ++ id).postln;
		}, {
			("The Voice cap (" ++ ~maxVoices ++ ") reached - ignoring id " ++id).postln;
		}); //Else we just output that we hit the limit, and they aren't considered
	}, {
		~voices[id].set(\x, x, \z, z); //If they already have a voice we just update the coordinates
		("UPDATED synth for ID " ++ id).postln;
	});
}, '/person', recvPort: 57120);


//The next function is for seeing who is still active - runs everytime a people message comes in

OSCdef(\peopleListener, {|msg, time, addr, recvPort|
	var activeIDs = msg[1..]; //Lists who's currently there, active IDs

	msg.postln;

	~voices.keysValuesDo({ |id, synth| //Go through every voice
		if (activeIDs.includes(id).not, { //If the person is not active
			synth.set(\gate,0); //fadeout and remove the ID from the tracking list
			~voices.removeAt(id);
		});
	});
}, '/people');




//SC automatically sums any number of synths so we don't need to manually add the signals together

//Ideas:
// (1) We could pan between the speakers, like you can hear where someone is standing - fairly simple we just use the coordinates to distribute the sound
//(2) Movement speed (how much x/z change since last update) could change the amount of lag between notes . Or it could affect envelope (sustaining) where fast speed = fast release envelope. Slow speed = sustain. Almost like staccato versus legato.
//For this we could store how long a user stays in a place and use that data to define the sound when they move
//(3) Proximity between 2 users --> Creating harmonies, like they snap to the nearest harmony?
