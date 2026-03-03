(
var audioExts = ["wav", "aif", "aiff", "flac"];
var maxBanks = 16;
var maxPerBank = 15;

~sampleDir = ~sampleDir ?? { thisProcess.nowExecutingPath.dirname +/+ "samples" };

~sampleBanks = Array.fill(maxBanks, { Array.newClear(maxPerBank) });
~samplePaths = Array.fill(maxBanks, { Array.newClear(maxPerBank) });
~numBanks = 0;

~freeSamples = {
    ~sampleBanks.do { |bank|
        bank.do { |buf|
            if(buf.notNil) { buf.free }
        }
    };
    ~sampleBanks = Array.fill(maxBanks, { Array.newClear(maxPerBank) });
    ~samplePaths = Array.fill(maxBanks, { Array.newClear(maxPerBank) });
    ~numBanks = 0;
    "[Gladiola] Samples freed.".postln;
};

~getSample = { |bank, index|
    if((bank >= 0) && (bank < maxBanks) && (index >= 0) && (index < maxPerBank)) {
        ~sampleBanks[bank][index]
    } {
        "[Gladiola] getSample: index out of bounds (bank: %, index: %)".format(bank, index).postln;
        nil
    }
};

~loadSamples = { |path, mode = \subdirectory|
    var allFiles, groups, bankIndex, sampleIndex, totalLoaded;

    path = path ?? { ~sampleDir };

    if(PathName(path).isFolder.not) {
        "[Gladiola] Directory not found: %".format(path).postln;
    } {
        ~freeSamples.value;

        allFiles = [];
        PathName(path).filesDo { |pn|
            var ext = pn.extension.toLower;
            if(audioExts.any { |e| e == ext }) {
                allFiles = allFiles.add(pn);
            };
        };

        if(allFiles.isEmpty) {
            "[Gladiola] No audio files found in: %".format(path).postln;
        } {
            groups = switch(mode)
            {\subdirectory} {
                var byFolder = Dictionary.new;
                allFiles.do { |pn|
                    var folderName = PathName(pn.pathOnly).folderName;
                    byFolder[folderName] = byFolder[folderName] ?? { [] };
                    byFolder[folderName] = byFolder[folderName].add(pn);
                };
                byFolder.keys.asSortedList.collect { |key| byFolder[key] }
            }
            {\random} {
                var shuffled = allFiles.scramble;
                (shuffled.size / maxPerBank).ceil.asInteger.collect { |i|
                    shuffled.copyRange(i * maxPerBank, (i * maxPerBank) + maxPerBank - 1)
                }
            }
            {\sequential} {
                (allFiles.size / maxPerBank).ceil.asInteger.collect { |i|
                    allFiles.copyRange(i * maxPerBank, (i * maxPerBank) + maxPerBank - 1)
                }
            };

            bankIndex = 0;
            totalLoaded = 0;

            groups.do { |fileList|
                var fileQueue = fileList.select(_.notNil);

                while { fileQueue.notEmpty && (bankIndex < maxBanks) } {
                    sampleIndex = 0;

                    while { fileQueue.notEmpty && (sampleIndex < maxPerBank) } {
                        var pn = fileQueue.removeAt(0);
                        var buf = Buffer.readChannel(Server.default, pn.fullPath, channels: [0]);
                        ~sampleBanks[bankIndex][sampleIndex] = buf;
                        ~samplePaths[bankIndex][sampleIndex] = pn.fullPath;
                        sampleIndex = sampleIndex + 1;
                        totalLoaded = totalLoaded + 1;
                    };

                    bankIndex = bankIndex + 1;
                };
            };

            // Server.sync requires a Routine context. Boot calls ~loadSamples from
            // waitForBoot's Routine, so this is always valid at startup. If called
            // interactively from the interpreter, wrap in a Routine: { ~loadSamples.(); }.fork
            if(thisThread.isKindOf(Routine)) {
                Server.default.sync;
            };

            ~numBanks = bankIndex;

            "[Gladiola] Sample loading complete.".postln;
            "[Gladiola] Mode: %".format(mode).postln;
            "[Gladiola] Banks loaded: %".format(~numBanks).postln;
            ~numBanks.do { |b|
                var count = ~sampleBanks[b].select(_.notNil).size;
                "[Gladiola] Bank %: % samples".format(b, count).postln;
            };
            "[Gladiola] Total samples: %".format(totalLoaded).postln;
        };
    };
};

"[Gladiola] sample_loader.scd loaded.".postln;
)
