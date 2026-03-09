(
var rawPath = thisProcess.nowExecutingPath;
var basePath = if(rawPath.notNil && { rawPath.size > 0 }) {
	rawPath.dirname
} {
	File.getcwd
};

var loadOrError = { |path|
	if(File.exists(path).not) {
		Error("[Gladiola] Required file not found: %".format(path)).throw;
	};
	path.load;
};

~basePath = basePath;

"[Gladiola] Booting server...".postln;

s.waitForBoot({

	// ========================================
	// LOAD SYNTHDEF
	// ========================================

	loadOrError.(basePath +/+ "synthdefs/sample_voice.scd");
	~gladiolaLoadSynthDefs.();
	loadOrError.(basePath +/+ "synthdefs/fx_chain.scd");
	~gladiolaLoadFxSynthDefs.();
	loadOrError.(basePath +/+ "synthdefs/lfo.scd");
	~gladiolaLoadLfoSynthDef.();
	s.sync;
	"[Gladiola] SynthDefs loaded.".postln;

	// ========================================
	// LOAD SAMPLE LOADER
	// ========================================

	~sampleDir = basePath +/+ "samples";
	loadOrError.(basePath +/+ "sample_loader.scd");

	// ========================================
	// LOAD SAMPLES
	// ========================================

	~loadSamples.(~sampleDir, \subdirectory);

	// ========================================
	// LOAD SEQUENCER
	// ========================================

	loadOrError.(basePath +/+ "sequencer.scd");
	~initSequencer.();
	s.sync;

	// ========================================
	// LOAD GRID MODULES
	// ========================================

	loadOrError.(basePath +/+ "grid_params.scd");
	loadOrError.(basePath +/+ "fx_params.scd");
	loadOrError.(basePath +/+ "lfo_params.scd");
	loadOrError.(basePath +/+ "grid_leds.scd");
	loadOrError.(basePath +/+ "grid_input.scd");

	// ========================================
	// LOAD SESSION MANAGER
	// ========================================

	~sessionsDir = "~/gladiola-sessions".standardizePath;
	if(File.exists(~sessionsDir).not) { File.mkdir(~sessionsDir) };
	loadOrError.(basePath +/+ "session.scd");

	// ========================================
	// CONNECT GRID
	// ========================================

	~gridAnimFill = { |callback|
		// Sequential fill: lights each cell one by one, left-to-right top-to-bottom
		Routine {
			~grid.clear;
			8.do { |y|
				16.do { |x|
					~grid.led(x, y, GridInterface.ledBright);
					(0.005).wait;
				};
			};
			0.15.wait;
			if(callback.notNil) { callback.() };
		}.play(AppClock);
	};

	~gridAnimScatter = { |callback|
		// Random fill: each cell fades 0→full over several frames
		var positions = 128.collect { |i| [i % 16, i div: 16] }.scramble;
		var levels = Array.fill(128, { 0 });
		var steps = 4;
		var inc = (GridInterface.ledFull / steps).ceil.asInteger;
		Routine {
			~grid.clear;
			positions.do { |pos, idx|
				levels[idx] = 1;
				// Fade up any cell that has been started
				levels.do { |lvl, j|
					if(lvl > 0 && (lvl < GridInterface.ledFull)) {
						levels[j] = (lvl + inc).min(GridInterface.ledFull);
						~grid.led(positions[j][0], positions[j][1], levels[j]);
					};
				};
				(0.02).wait;
			};
			// Finish fading any cells not yet at full
			steps.do {
				levels.do { |lvl, j|
					if(lvl > 0 && (lvl < GridInterface.ledFull)) {
						levels[j] = (lvl + inc).min(GridInterface.ledFull);
						~grid.led(positions[j][0], positions[j][1], levels[j]);
					};
				};
				(0.02).wait;
			};
			0.1.wait;
			if(callback.notNil) { callback.() };
		}.play(AppClock);
	};

	~connectGrid = { |ip = "127.0.0.1", port = 13001, oscgrid = true, prefix = "/monome"|
		if(~grid.notNil) { ~grid.free };
		~grid = GridInterface.new(ip, port, oscgrid, prefix);

		if(oscgrid.not) {
			var deviceAddr = NetAddr(ip, port);
			deviceAddr.sendMsg('/sys/port', NetAddr.langPort);
			deviceAddr.sendMsg('/sys/host', "127.0.0.1");
			deviceAddr.sendMsg('/sys/prefix', prefix);
			"[Gladiola] serialosc handshake sent (prefix: %, port: %).".format(prefix, NetAddr.langPort).postln;
		};

		"[Gladiola] Grid connected (%, port %).".format(ip, port).postln;
		~gridAnimFill.({ ~initGridHandler.(); ~updateGridLEDs.() });
	};

	~disconnectGrid = {
		if(~grid.notNil) {
			~grid.free;
			~grid = nil;
			"[Gladiola] Grid disconnected.".postln;
		};
	};

	// ========================================
	// SERIALOSC AUTO-DETECT
	// ========================================

	~connectSerialosc = {
		var serialoscAddr = NetAddr("127.0.0.1", 12002);
		var connected = false;

		OSCdef(\gladiolaDeviceInfo, { |msg|
			var id = msg[1].asString;
			var type = msg[2].asString;
			var port = msg[3].asInteger;

			"[Gladiola] Found device: % (%) on port %".format(id, type, port).postln;

			connected = true;
			~connectGrid.("127.0.0.1", port, false, "/" ++ id);

			OSCdef(\gladiolaDeviceInfo).free;
		}, '/serialosc/device');

		AppClock.sched(5.0, {
			if(connected.not) {
				OSCdef(\gladiolaDeviceInfo).free;
				"[Gladiola] serialosc scan timed out — no device found.".postln;
			};
		});

		serialoscAddr.sendMsg('/serialosc/list', "127.0.0.1", NetAddr.langPort);
		"[Gladiola] Scanning for serialosc devices...".postln;
	};

	// ========================================
	// CLEANUP
	// ========================================

	~cleanup = {
		if(~meterUpdateRoutine.notNil) { ~meterUpdateRoutine.stop; ~meterUpdateRoutine = nil };
		if(~meterSynth.notNil) { ~meterSynth.free; ~meterSynth = nil };
		if(~meterBus.notNil) { ~meterBus.free; ~meterBus = nil };
		if(~stopTransport.notNil)  { ~stopTransport.() };
		if(~disconnectGrid.notNil) { ~disconnectGrid.() };
		if(~freeSamples.notNil)    { ~freeSamples.() };
		[\delaySynth, \granularSynth, \reverbSynth, \satSynth, \tiltSynth, \compSynth, \limiterSynth].do { |key|
			var synth = key.envirGet;
			if(synth.notNil) { synth.free; key.envirPut(nil) };
		};
		if(~lfoSynths.notNil) { ~lfoSynths.do { |s| if(s.notNil) { s.free } }; ~lfoSynths = nil };
		if(~lfoGroup.notNil) { ~lfoGroup.free; ~lfoGroup = nil };
		if(~lfoBus.notNil) { ~lfoBus.free; ~lfoBus = nil };
		[\masterGroup, \fxGroup, \satGroup, \voiceGroup].do { |key|
			var group = key.envirGet;
			if(group.notNil) { group.free; key.envirPut(nil) };
		};
		if(~fxSendBus.notNil) { ~fxSendBus.free; ~fxSendBus = nil };
		"[Gladiola] Cleanup complete.".postln;
	};

	// ========================================
	// BOOT COMPLETE
	// ========================================

	"[Gladiola] ========================================".postln;
	"[Gladiola] BOOT COMPLETE".postln;
	"[Gladiola] ========================================".postln;
	"[Gladiola] % tracks × % steps".format(~numTracks, ~stepsPerTrack).postln;
	"[Gladiola] Samples: % banks loaded".format(~numBanks).postln;
	"[Gladiola] BPM: %".format(~bpm).postln;
	"[Gladiola] ========================================".postln;
	"[Gladiola] Functions:".postln;
	"[Gladiola]   ~connectSerialosc.()             - Auto-detect hardware grid".postln;
	"[Gladiola]   ~connectGrid.(ip, port, osc, px) - Connect manually".postln;
	"[Gladiola]   ~startTransport.()               - Start sequencer".postln;
	"[Gladiola]   ~stopTransport.()                - Stop sequencer".postln;
	"[Gladiola]   ~loadSamples.(path, mode)        - Load samples".postln;
	"[Gladiola]   ~setTrackClockDiv.(trackIdx, div) - Per-track clock division (0.0625-4.0)".postln;
	"[Gladiola]   ~setFxParam.(key, val)            - Set FX parameter".postln;
	"[Gladiola]   ~setTempo.(bpm)                  - Change tempo (20-300)".postln;
	"[Gladiola]   ~setTrackStart.(t, step)          - Track start point (0-15)".postln;
	"[Gladiola]   ~setTrackEnd.(t, step)            - Track end point (0-15)".postln;
	"[Gladiola]   ~muteTrack.(idx) / ~unmuteTrack.(idx)".postln;
	"[Gladiola]   ~clearPattern.()                 - Clear all steps".postln;
	"[Gladiola]   ~cleanup.()                      - Shutdown".postln;
	"[Gladiola]   ~sessionGUI.()                  - Open session manager".postln;
	"[Gladiola] ========================================".postln;

	{ ~sessionGUI.() }.defer;
});

)
