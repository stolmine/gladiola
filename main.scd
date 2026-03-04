// Gladiola - Main Boot File
// A groovebox for monome grid, powered by SuperCollider
//
// Usage: "/path/to/main.scd".load;

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

"[Gladiola] Booting server...".postln;

s.waitForBoot({

	// ========================================
	// LOAD SYNTHDEF
	// ========================================

	loadOrError.(basePath +/+ "synthdefs/sample_voice.scd");
	~gladiolaLoadSynthDefs.();
	s.sync;
	"[Gladiola] SynthDef loaded.".postln;

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
	// LOAD GRID HANDLER (define only; connect via ~connectGrid)
	// ========================================

	loadOrError.(basePath +/+ "grid_handler.scd");

	// ========================================
	// CONNECT GRID
	// ========================================

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
		~initGridHandler.();
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

			// Free immediately so only the first-listed device connects.
			// Re-call ~connectSerialosc to select a different device.
			OSCdef(\gladiolaDeviceInfo).free;
		}, '/serialosc/device');

		// Guard against no device responding: free the listener after 5 seconds.
		// Uses a flag rather than re-querying OSCdef, which always returns non-nil.
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
		if(~stopTransport.notNil)  { ~stopTransport.() };
		if(~disconnectGrid.notNil) { ~disconnectGrid.() };
		if(~freeSamples.notNil)    { ~freeSamples.() };
		if(~voice.notNil)          { ~voice.free; ~voice = nil };
		"[Gladiola] Cleanup complete.".postln;
	};

	// ========================================
	// BOOT COMPLETE
	// ========================================

	"[Gladiola] ========================================".postln;
	"[Gladiola] BOOT COMPLETE".postln;
	"[Gladiola] ========================================".postln;
	"[Gladiola] Samples: % banks loaded".format(~numBanks).postln;
	"[Gladiola] BPM: %".format(~bpm).postln;
	"[Gladiola] ========================================".postln;
	"[Gladiola] Functions:".postln;
	"[Gladiola]   ~connectSerialosc.()             - Auto-detect hardware grid".postln;
	"[Gladiola]   ~connectGrid.(ip, port, osc, px) - Connect manually".postln;
	"[Gladiola]   ~startTransport.()               - Start sequencer".postln;
	"[Gladiola]   ~stopTransport.()                - Stop sequencer".postln;
	"[Gladiola]   ~loadSamples.(path, mode)        - Load samples".postln;
	"[Gladiola]   ~setClockDiv.(div)                - Set clock division (0.0625-4.0)".postln;
	"[Gladiola]   ~setTempo.(bpm)                  - Change tempo (20-300 BPM)".postln;
	"[Gladiola]   ~setPatternLength.(n)            - Set pattern length (1-128)".postln;
	"[Gladiola]   ~clearPattern.()                 - Clear all steps".postln;
	"[Gladiola]   ~cleanup.()                      - Shutdown".postln;
	"[Gladiola] ========================================".postln;
});

)
