(
~sessionName = nil;
~sessionPath = nil;
~sessionWindow = nil;

~buildSessionSnapshot = {
	var snapshot = Dictionary.new;
	snapshot[\sampleDir] = ~sampleDir;
	snapshot[\bpm] = ~bpm;
	snapshot[\fxParams] = ~fxParams.copy;
	snapshot[\transpose] = ~transpose;
	snapshot[\globalReverse] = ~globalReverse;
	snapshot[\swing] = ~swing;
	snapshot[\trackVolumes] = ~trackVolumes.copy;
	snapshot[\trackModSettings] = ~numTracks.collect { |i|
		var ms = ~trackModSettings[i];
		Dictionary[\shape -> ms[\shape], \rate16ths -> ms[\rate16ths],
			\depths -> ms[\depths].copy, \polarities -> ms[\polarities].copy]
	};
	snapshot[\tracks] = ~numTracks.collect { |i|
		var t = ~tracks[i];
		Dictionary[
			\steps -> t[\steps].collect { |s| ~deepCopyStep.(s) },
			\startStep -> t[\startStep],
			\endStep -> t[\endStep],
			\muted -> t[\muted],
			\clockDiv -> t[\clockDiv],
			\sliceMode -> t[\sliceMode]
		]
	};
	snapshot[\presets] = ~presets.collect { |p|
		if(p.notNil) {
			var copy = Dictionary.new;
			copy[\tracks] = p[\tracks].collect { |t|
				var td = Dictionary[
					\steps -> t[\steps].collect { |s| ~deepCopyStep.(s) },
					\startStep -> t[\startStep],
					\endStep -> t[\endStep],
					\muted -> t[\muted]
				];
				if(t[\clockDiv].notNil) { td[\clockDiv] = t[\clockDiv] };
				if(t[\sliceMode].notNil) { td[\sliceMode] = t[\sliceMode] };
				td
			};
			copy[\clockDiv] = p[\clockDiv];
			if(p[\fxParams].notNil) { copy[\fxParams] = p[\fxParams].copy };
			copy[\delayDiv] = p[\delayDiv];
			copy[\transpose] = p[\transpose];
			copy[\globalReverse] = p[\globalReverse];
				if(p[\trackModSettings].notNil) { copy[\trackModSettings] = p[\trackModSettings].collect { |ms|
					Dictionary[\shape -> ms[\shape], \rate16ths -> ms[\rate16ths],
						\depths -> ms[\depths].copy, \polarities -> ms[\polarities].copy]
				} };
			copy
		} { nil }
	};
	snapshot[\presetSlotMap] = ~presetSlotMap.copy;
	snapshot[\presetConfirmMode] = ~presetConfirmMode;
	snapshot[\presetQuantized] = ~presetQuantized;
	snapshot[\activePresetButton] = ~activePresetButton;
	snapshot
};

~saveSession = {
	if(~sessionName.notNil) {
		var snapshot = ~buildSessionSnapshot.();
		snapshot.writeArchive(~sessionPath);
		"[Gladiola] Session '%' saved.".format(~sessionName).postln;
		if(~grid.notNil && ~gridAnimSave.notNil) {
			~gridAnimSave.({ ~updateGridLEDs.() });
		};
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
		var animDone = false;
		var loadDone = false;

		if(File.exists(path).not) {
			"[Gladiola] Session file not found: %".format(path).postln;
		} {
			snapshot = Object.readArchive(path);

			if(snapshot.isNil) {
				"[Gladiola] Failed to read session: %".format(path).postln;
			} {
				// Start scatter animation concurrently — it runs alongside the load
				if(~grid.notNil && ~gridAnimScatter.notNil) {
					~gridAnimScatter.({
						animDone = true;
						if(loadDone) { ~updateGridLEDs.() };
					});
				} { animDone = true };

				if(~playing) { ~stopTransport.() };

				~loadSamples.(snapshot[\sampleDir]);
				Server.default.sync;

				~numTracks.do { |i|
					var saved = snapshot[\tracks][i];
					saved[\steps].do { |step|
						if(step[\subSteps].isNil) {
							step[\subSteps] = Array.fill(9, { nil });
							step[\subActive] = Array.fill(9, { |i| i == 0 });
							step[\subIdx] = 0;
						};
						if(step[\attack].isNil) { step[\attack] = 0.002 };
						if(step[\sliceIdx].isNil) { step[\sliceIdx] = 0 };
					};
					~tracks[i][\steps] = saved[\steps].collect { |s| ~deepCopyStep.(s) };
					~tracks[i][\startStep] = saved[\startStep];
					~tracks[i][\endStep] = saved[\endStep];
					~tracks[i][\muted] = saved[\muted];
					~tracks[i][\currentStep] = ~tracks[i][\startStep];
					if(saved[\clockDiv].notNil) {
						~tracks[i][\clockDiv] = saved[\clockDiv];
					} {
						~tracks[i][\clockDiv] = 0.25;
					};
					~tracks[i][\sliceMode] = saved[\sliceMode] ?? { false };
					if(~tracks[i][\voice].notNil) {
						~tracks[i][\voice].set(\sliceMode, ~tracks[i][\sliceMode].asInteger);
					};
				};

				~trackVolumes = snapshot[\trackVolumes] ?? { Array.fill(7, { 1.0 }) };
			~numTracks.do { |i|
				if(~tracks[i][\voice].notNil) { ~tracks[i][\voice].set(\trackAmp, ~trackVolumes[i]) };
			};

			if(snapshot[\trackModSettings].notNil) {
				~numTracks.do { |i|
					var saved = snapshot[\trackModSettings][i];
					~trackModSettings[i] = Dictionary[\shape -> saved[\shape], \rate16ths -> saved[\rate16ths],
						\depths -> saved[\depths].copy, \polarities -> saved[\polarities].copy];
					~setModShape.(i, saved[\shape]); ~updateLfoRate.(i); ~applyModDepths.(i);
				};
			} { ~numTracks.do { |i| ~resetModSettings.(i) } };

			~bpm = snapshot[\bpm];
				if(snapshot[\fxParams].notNil) {
					snapshot[\fxParams].keysValuesDo { |key, val|
						~setFxParam.(key, val);
					};
				} {
					// Backward compat: old session with only delayDiv
					~fxParamDefaults.keysValuesDo { |key, val|
						~setFxParam.(key, val);
					};
					if(snapshot[\delayDiv].notNil) {
						~setFxParam.(\delayDiv, snapshot[\delayDiv]);
					};
				};
				~transpose = snapshot[\transpose];
				~globalReverse = snapshot[\globalReverse] ? false;
				~swing = snapshot[\swing] ?? { 50 };

				~presets = snapshot[\presets].collect { |p|
					if(p.notNil) {
						var copy = Dictionary.new;
						copy[\tracks] = p[\tracks].collect { |t|
							var td;
							t[\steps].do { |step|
								if(step[\subSteps].isNil) {
									step[\subSteps] = Array.fill(9, { nil });
									step[\subActive] = Array.fill(9, { |i| i == 0 });
									step[\subIdx] = 0;
								};
								if(step[\attack].isNil) { step[\attack] = 0.002 };
								if(step[\sliceIdx].isNil) { step[\sliceIdx] = 0 };
							};
							td = Dictionary[
								\steps -> t[\steps].collect { |s| ~deepCopyStep.(s) },
								\startStep -> t[\startStep],
								\endStep -> t[\endStep],
								\muted -> t[\muted]
							];
							if(t[\clockDiv].notNil) { td[\clockDiv] = t[\clockDiv] };
							if(t[\sliceMode].notNil) { td[\sliceMode] = t[\sliceMode] };
							td
						};
						copy[\clockDiv] = p[\clockDiv];
						copy[\delayDiv] = p[\delayDiv];
						if(p[\fxParams].notNil) { copy[\fxParams] = p[\fxParams].copy };
						copy[\transpose] = p[\transpose];
						copy[\globalReverse] = p[\globalReverse];
							if(p[\trackModSettings].notNil) { copy[\trackModSettings] = p[\trackModSettings].collect { |ms|
								Dictionary[\shape -> ms[\shape], \rate16ths -> ms[\rate16ths],
									\depths -> ms[\depths].copy, \polarities -> ms[\polarities].copy]
							} };
						copy
					} { nil }
				};
				if(~presets.size < 49) {
					var old = ~presets;
					~presets = Array.fill(49, { nil });
					old.do { |p, i| ~presets[i] = p };
				};
				~presetSlotMap = snapshot[\presetSlotMap] ?? { [0, 1, 2, 3] };
				~presetConfirmMode = snapshot[\presetConfirmMode] ?? { true };
				~presetQuantized = snapshot[\presetQuantized] ?? { false };
				~activePresetButton = snapshot[\activePresetButton];
				~pendingPresetRecall = nil;
				~pendingPresetButton = nil;
				~presetSelectedSlot = nil;

				~sessionName = name;
				~sessionPath = path;

				"[Gladiola] Session '%' loaded.".format(name).postln;
				loadDone = true;
				if(animDone) {
					{ ~updateGridLEDs.() }.defer;
				};
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
		~transpose = 1.0;
		~globalReverse = false;
		~swing = 50;
		~trackVolumes = Array.fill(7, { 1.0 });
		~numTracks.do { |i|
			if(~tracks[i][\voice].notNil) { ~tracks[i][\voice].set(\trackAmp, 1.0) };
		};
		~numTracks.do { |i| ~resetModSettings.(i) };
		~numTracks.do { |i| ~tracks[i][\sliceMode] = false };
		~setTempo.(~bpm);

		~presets = Array.fill(49, { nil });
		~presetSlotMap = [0, 1, 2, 3];
		~presetSelectedSlot = nil;
		~presetConfirmMode = true;
		~presetQuantized = false;
		~pendingPresetRecall = nil;
		~pendingPresetButton = nil;
		~activePresetButton = nil;

		~sessionName = name;
		~sessionPath = ~sessionsDir +/+ name ++ ".gladiola";
		~saveSession.();

		"[Gladiola] New session '%' created.".format(name).postln;
		if(~grid.notNil && ~gridAnimScatter.notNil) {
			~gridAnimScatter.({ ~updateGridLEDs.() });
		} {
			{ ~updateGridLEDs.() }.defer;
		};
	}.play;
};

~sessionGUI = {
	if(~sessionWindow.notNil && { ~sessionWindow.isClosed.not }) {
		~sessionWindow.front;
	} {
		var bpmLabel, swingLabel, sampleDirLabel, gridStatusLabel, recordLabel, meterL, meterR, updateTask, smoothL = 0, smoothR = 0, peakL = 0, peakR = 0, peakDecay = 0.985;

		s.recHeaderFormat = "aiff";
		s.recSampleFormat = "int24";

		~sessionWindow = Window("Gladiola — %".format(~sessionName ? "unsaved"), Rect(100, 100, 460, 130), resizable: false)
		.alwaysOnTop_(true);

		bpmLabel = StaticText().string_("BPM: %".format(~bpm));
		swingLabel = StaticText().string_("Swing: %%".format(~swing, "%"));
		sampleDirLabel = StaticText().string_("Samples: %".format(~sampleDir ? "—"));
		gridStatusLabel = StaticText().string_(if(~grid.notNil) { "Grid: connected" } { "Grid: —" });
		recordLabel = StaticText().string_("00:00");
		meterL = LevelIndicator().style_(\continuous).drawsPeak_(true).warning_(0.7).critical_(0.9);
		meterR = LevelIndicator().style_(\continuous).drawsPeak_(true).warning_(0.7).critical_(0.9);

		updateTask = Routine({
			loop {
				{
					if(~sessionWindow.notNil && { ~sessionWindow.isClosed.not }) {
						var l = ~meterLevel[0];
						var r = ~meterLevel[1];
						var coefL = if(l > smoothL) { 0.6 } { 0.15 };
						var coefR = if(r > smoothR) { 0.6 } { 0.15 };
						smoothL = smoothL + (coefL * (l - smoothL));
						smoothR = smoothR + (coefR * (r - smoothR));
						peakL = if(l > peakL) { l } { peakL * peakDecay };
						peakR = if(r > peakR) { r } { peakR * peakDecay };
						meterL.value = smoothL; meterL.peakLevel = peakL;
						meterR.value = smoothR; meterR.peakLevel = peakR;
						~sessionWindow.name = "Gladiola — %".format(~sessionName ? "unsaved");
						bpmLabel.string = "BPM: %".format(~bpm);
						swingLabel.string = "Swing: %%".format(~swing, "%");
						sampleDirLabel.string = "Samples: %".format(
							if(~sampleDir.notNil) { PathName(~sampleDir).folderName } { "—" }
						);
						gridStatusLabel.string = if(~grid.notNil) { "Grid: connected" } { "Grid: —" };
						if(~recordStartTime.notNil) {
							var elapsed = (Main.elapsedTime - ~recordStartTime).asInteger;
							var mins = (elapsed / 60).floor.asInteger;
							var secs = elapsed % 60;
							recordLabel.string = "%:%".format(
								mins.asString.padLeft(2, "0"),
								secs.asString.padLeft(2, "0")
							);
						};
					};
				}.defer;
				0.05.wait;
			}
		}).play(AppClock);

		~sessionWindow.layout_(VLayout(
			HLayout(
				bpmLabel,
				swingLabel,
				nil,
				gridStatusLabel,
				recordLabel,
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
				}),
				Button().states_([["Grid"]]).action_({
					~connectSerialosc.();
				}),
				Button().states_([
					["Rec", Color.white, Color(0.4, 0.4, 0.4)],
					["Rec", Color.white, Color(0.8, 0.2, 0.2)]
				]).action_({ |btn|
					if(btn.value == 1) {
						s.record;
						~recordStartTime = Main.elapsedTime;
					} {
						s.stopRecording;
						~recordStartTime = nil;
						recordLabel.string = "00:00";
					};
				}),
				Button().states_([["Quit", Color.white, Color(0.6, 0.2, 0.2)]]).action_({
					var dlg = Window("Quit Gladiola?", Rect(200, 200, 250, 60), resizable: false);
					dlg.layout_(HLayout(
						Button().states_([["Cancel"]]).action_({ dlg.close }),
						Button().states_([["Quit", Color.white, Color(0.6, 0.2, 0.2)]]).action_({
							dlg.close;
							"[Gladiola] Shutting down...".postln;
							if(s.isRecording) { s.stopRecording; ~recordStartTime = nil };
							if(~playing) { ~stopTransport.() };
							~stopPulseRoutine.();
							~panicVoices.();
							~killFxTails.();
							if(~grid.notNil) {
								~grid.clear;
								~grid.free;
							};
							~sessionWindow.close;
							Server.default.quit;
							"[Gladiola] Goodbye.".postln;
						})
					));
					dlg.front;
				})
			)
		));

		~sessionWindow.onClose_({
			updateTask.stop;
		});

		~sessionWindow.front;
	};
};

"[Gladiola] session.scd loaded.".postln;
)
