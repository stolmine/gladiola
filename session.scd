(
~sessionName = nil;
~sessionPath = nil;
~sessionWindow = nil;

~buildSessionSnapshot = {
	var snapshot = Dictionary.new;
	snapshot[\sampleDir] = ~sampleDir;
	snapshot[\bpm] = ~bpm;
	snapshot[\delayDiv] = ~delayDiv;
	snapshot[\transpose] = ~transpose;
	snapshot[\globalReverse] = ~globalReverse;
	snapshot[\tracks] = ~numTracks.collect { |i|
		var t = ~tracks[i];
		Dictionary[
			\steps -> t[\steps].collect { |s| s.copy },
			\startStep -> t[\startStep],
			\endStep -> t[\endStep],
			\muted -> t[\muted],
			\clockDiv -> t[\clockDiv]
		]
	};
	snapshot[\presets] = ~presets.collect { |p|
		if(p.notNil) {
			var copy = Dictionary.new;
			copy[\tracks] = p[\tracks].collect { |t|
				var td = Dictionary[
					\steps -> t[\steps].collect { |s| s.copy },
					\startStep -> t[\startStep],
					\endStep -> t[\endStep],
					\muted -> t[\muted]
				];
				if(t[\clockDiv].notNil) { td[\clockDiv] = t[\clockDiv] };
				td
			};
			copy[\clockDiv] = p[\clockDiv];
			copy[\delayDiv] = p[\delayDiv];
			copy[\transpose] = p[\transpose];
			copy[\globalReverse] = p[\globalReverse];
			copy
		} { nil }
	};
	snapshot
};

~saveSession = {
	if(~sessionName.notNil) {
		var snapshot = ~buildSessionSnapshot.();
		snapshot.writeArchive(~sessionPath);
		"[Gladiola] Session '%' saved.".format(~sessionName).postln;
	} {
		"[Gladiola] No session name set.".postln;
	};
};

~saveSessionAs = { |name|
	~sessionName = name;
	~sessionPath = ~sessionsDir +/+ name ++ ".gladiola";
	~saveSession.();
};

~loadSession = { |name|
	Routine {
		var path = ~sessionsDir +/+ name ++ ".gladiola";
		var snapshot;

		if(File.exists(path).not) {
			"[Gladiola] Session file not found: %".format(path).postln;
		} {
			snapshot = Object.readArchive(path);

			if(snapshot.isNil) {
				"[Gladiola] Failed to read session: %".format(path).postln;
			} {
				if(~playing) { ~stopTransport.() };

				~loadSamples.(snapshot[\sampleDir]);
				Server.default.sync;

				~numTracks.do { |i|
					var saved = snapshot[\tracks][i];
					~tracks[i][\steps] = saved[\steps].collect { |s| s.copy };
					~tracks[i][\startStep] = saved[\startStep];
					~tracks[i][\endStep] = saved[\endStep];
					~tracks[i][\muted] = saved[\muted];
					~tracks[i][\currentStep] = ~tracks[i][\startStep];
					if(saved[\clockDiv].notNil) {
						~tracks[i][\clockDiv] = saved[\clockDiv];
					} {
						~tracks[i][\clockDiv] = 0.25;
					};
				};

				~bpm = snapshot[\bpm];
				~delayDiv = snapshot[\delayDiv];
				~transpose = snapshot[\transpose];
				~globalReverse = snapshot[\globalReverse] ? false;
				~updateDelayTime.();

				~presets = snapshot[\presets].collect { |p|
					if(p.notNil) {
						var copy = Dictionary.new;
						copy[\tracks] = p[\tracks].collect { |t|
							var td = Dictionary[
								\steps -> t[\steps].collect { |s| s.copy },
								\startStep -> t[\startStep],
								\endStep -> t[\endStep],
								\muted -> t[\muted]
							];
							if(t[\clockDiv].notNil) { td[\clockDiv] = t[\clockDiv] };
							td
						};
						copy[\clockDiv] = p[\clockDiv];
						copy[\delayDiv] = p[\delayDiv];
						copy[\transpose] = p[\transpose];
						copy[\globalReverse] = p[\globalReverse];
						copy
					} { nil }
				};

				~sessionName = name;
				~sessionPath = path;

				{ ~updateGridLEDs.() }.defer;
				"[Gladiola] Session '%' loaded.".format(name).postln;
			};
		};
	}.play;
};

~newSession = { |name, sampleDir|
	Routine {
		if(~playing) { ~stopTransport.() };

		~loadSamples.(sampleDir);
		Server.default.sync;

		~clearPattern.();

		~bpm = 120;
		~delayDiv = 0.25;
		~transpose = 1.0;
		~globalReverse = false;
		~updateDelayTime.();
		~setTempo.(~bpm);

		~presets = Array.fill(4, { nil });

		~sessionName = name;
		~sessionPath = ~sessionsDir +/+ name ++ ".gladiola";
		~saveSession.();

		{ ~updateGridLEDs.() }.defer;
		"[Gladiola] New session '%' created.".format(name).postln;
	}.play;
};

~sessionGUI = {
	if(~sessionWindow.notNil && { ~sessionWindow.isClosed.not }) {
		~sessionWindow.front;
	} {
		var bpmLabel, sampleDirLabel, meterL, meterR, updateTask, meterSynth, meterBus, meterResp;

		~sessionWindow = Window("Gladiola", Rect(100, 100, 400, 130), resizable: false)
		.alwaysOnTop_(true);

		bpmLabel = StaticText().string_("BPM: %".format(~bpm));
		sampleDirLabel = StaticText().string_("Samples: %".format(~sampleDir ? "—"));
		meterL = LevelIndicator().style_(\continuous).drawsPeak_(true).warning_(0.7).critical_(0.9);
		meterR = LevelIndicator().style_(\continuous).drawsPeak_(true).warning_(0.7).critical_(0.9);

		meterBus = Bus.control(Server.default, 2);
		meterSynth = SynthDef(\gladiolaMeter, {
			var sig = In.ar(0, 2);
			var amp = Amplitude.kr(sig, 0.01, 0.1);
			Out.kr(meterBus, amp);
		}).play(Server.default, addAction: \addToTail);

		updateTask = Routine({
			loop {
				meterBus.getn(2, { |vals|
					{
						if(~sessionWindow.notNil && { ~sessionWindow.isClosed.not }) {
							meterL.value = vals[0].ampdb.linlin(-40, 0, 0, 1).clip(0, 1);
							meterL.peakLevel = vals[0].ampdb.linlin(-40, 0, 0, 1).clip(0, 1);
							meterR.value = vals[1].ampdb.linlin(-40, 0, 0, 1).clip(0, 1);
							meterR.peakLevel = vals[1].ampdb.linlin(-40, 0, 0, 1).clip(0, 1);
							bpmLabel.string = "BPM: %".format(~bpm);
							sampleDirLabel.string = "Samples: %".format(
								if(~sampleDir.notNil) { PathName(~sampleDir).folderName } { "—" }
							);
						};
					}.defer;
				});
				0.05.wait;
			}
		}).play(AppClock);

		~sessionWindow.layout_(VLayout(
			HLayout(
				bpmLabel,
				nil,
				sampleDirLabel
			),
			HLayout(meterL, meterR),
			HLayout(
				Button().states_([["New"]]).action_({
					var dlg = Window("New Session", Rect(200, 200, 300, 70), resizable: false);
					var field = TextField().string_("untitled");
					dlg.layout_(VLayout(
						field,
						Button().states_([["OK"]]).action_({
							var name = field.string;
							dlg.close;
							FileDialog({ |folder|
								~newSession.(name, folder[0]);
							}, fileMode: 2, stripResult: false);
						})
					));
					dlg.front;
				}),
				Button().states_([["Save"]]).action_({
					if(~sessionName.notNil) {
						~saveSession.();
					} {
						var dlg = Window("Save As", Rect(200, 200, 300, 70), resizable: false);
						var field = TextField().string_("untitled");
						dlg.layout_(VLayout(
							field,
							Button().states_([["OK"]]).action_({
								var name = field.string;
								dlg.close;
								~saveSessionAs.(name);
							})
						));
						dlg.front;
					};
				}),
				Button().states_([["Save As"]]).action_({
					var dlg = Window("Save As", Rect(200, 200, 300, 70), resizable: false);
					var field = TextField().string_(~sessionName ? "untitled");
					dlg.layout_(VLayout(
						field,
						Button().states_([["OK"]]).action_({
							var name = field.string;
							dlg.close;
							~saveSessionAs.(name);
						})
					));
					dlg.front;
				}),
				Button().states_([["Load"]]).action_({
					var files = PathName(~sessionsDir).files.select { |f|
						f.extension == "gladiola"
					};
					var names = files.collect { |f| f.fileNameWithoutExtension };
					if(names.isEmpty) {
						"[Gladiola] No sessions found.".postln;
					} {
						var dlg = Window("Load Session", Rect(200, 200, 300, 200), resizable: false);
						var list = ListView().items_(names);
						dlg.layout_(VLayout(
							list,
							Button().states_([["OK"]]).action_({
								var name = names[list.value];
								dlg.close;
								~loadSession.(name);
							})
						));
						dlg.front;
					};
				})
			)
		));

		~sessionWindow.onClose_({
			updateTask.stop;
			meterSynth.free;
			meterBus.free;
		});

		~sessionWindow.front;
	};
};

"[Gladiola] session.scd loaded.".postln;
)
