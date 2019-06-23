

import util;
import moore;
import exp_util;

import test_impl;
import isotest_impl;


import std.stdio;
import std.format;


import std.conv;

import std.algorithm;
import std.algorithm.searching;
import std.array;

import std.file;

import std.string;

import std.typecons;

import core.memory : GC;

import std.exception;

import std.math;

import core.stdc.stdlib : exit;


void memoryCheck() {

    if (GC.stats.usedSize > 6_000_000_000) {
        writeln("exiting to free memory...");
        exit(0);
    }

}


string str(T)(T v) {
    return v.to!string;
}


double avg(T)(T[] data) {

    if (data.length == 0) {
        return double.nan;
    }

    double ret = 0;

    foreach (e; data) { ret += e; }

    ret /= data.length;

    return ret;
}

double sdev(T)(T[] data) {

    if (data.length == 0) {
        return double.nan;
    }

    return sqrt(data.map!"a ^^ 2".array.avg - data.avg ^^ 2);
}

double mdn(T)(T[] data) {

    if (data.length == 0) {
        return double.nan;
    }
    
    auto sorted = data.dup.sort;
    
    if (sorted.length % 2 == 1) {
        return sorted[$ / 2];
    } else {
        return (sorted[$ / 2] + sorted[$ / 2 - 1]) / 2.0;
    }
}


void main() {

    string outDir = "o/";

    
    auto 
        Ni = 25, 
        No = 25,
        cspc = 100,
        
        mIdMin = 1,
        mIdMax = 10;

    auto accConfigs = ["strong", "medium", "weak"];
    
    auto NqList = [50, 150];
    
    auto allAlgoIds = [1, 2, 3]; // [1, 2, 3];

    auto allTrainSetPreInfos = [
        ["gen-method" : "cs"],
            
        ["gen-method" : "walk", "size" :       "1000"],
        ["gen-method" : "walk", "size" :      "10000"],
        ["gen-method" : "walk", "size" :     "100000"],
        ["gen-method" : "walk", "size" :    "1000000"],

    ];

    auto testSetSize = 2_000_000;

    int stateLimit = 1_000_000;


    bool runExperiments = true;

    if (runExperiments) {

        // run experiments

        foreach (Nq; NqList) {
        
            foreach (mId; mIdMin .. mIdMax + 1) {
            
                auto randMooreInfo = new MachineInfo([
                    "gen-method" : "random",
                    "rseed" : mId.str,
                    "nq" : Nq.str,
                    "ni" : Ni.str,
                    "no" : No.str
                ]);
                
                
                auto randMooreFnamePy = randMooreInfo.getFilename(outDir);
                
                writeln("generating Moore machine ", randMooreFnamePy); stdout.flush;
                
                generateFromInfo(randMooreInfo, outDir);

                auto randMooreFnameD = randMooreFnamePy ~ "-D";
                
                if (!randMooreFnameD.exists) {
                    pym2dm(randMooreFnamePy, randMooreFnameD);
                }                
                
                foreach (trainSetPreInfo; allTrainSetPreInfos) {
            
                    auto trainSetInfo = new SampleInfo(
                        trainSetPreInfo.updatedWith(["rseed" : mId.str, "fsm-fname" : randMooreFnamePy]));
                    
                    auto trainSetFname = trainSetInfo.getFilename(outDir);

                    writeln("generating traces for ", randMooreFnamePy); stdout.flush;
                    generateFromInfo(trainSetInfo, outDir);
                    

                    auto trainSample = loadCachedSample(trainSetFname);


                    auto testSetInfo = new SampleInfo([
                        "gen-method" : "walk", "size" : testSetSize.str, //"wlen" : wlen.str, 
                        "rseed" : mId.str, "fsm-fname" : randMooreFnamePy]);
                    
                    auto testSetFname = testSetInfo.getFilename(outDir);
                    
                    writeln("generating test traces for ", randMooreFnamePy); stdout.flush;
                    generateFromInfo(testSetInfo, outDir);
                    
                    
                    //writeln("loading cached moore...");
                    auto generatedMoore = loadCachedMachine(randMooreFnameD);
                    //writeln("loaded cached moore...");

                    foreach (aId; allAlgoIds) {

                        auto learnedMooreInfo = new MachineInfo([
                            "gen-method" : "learned",
                            "sample-fname" : trainSetFname,
                            "iface-fname" : randMooreFnameD,
                            "algo" : aId.str,
                            "tlim" : str(60 * 15)
                        ]);
                            
                        auto learnedMooreFname = learnedMooreInfo.getFilename(outDir);
                        
                        auto learnFout =  format!"%slearn-result-%s"(outDir, escapeSlashes(learnedMooreFname));
                        auto testFout =  format!"%stest-result-%s-%s"(outDir, escapeSlashes(learnedMooreFname), escapeSlashes(testSetFname));

                        Moore!TraceElem learnedMoore;

                        if (all!(e => format!"%s-%s"(testFout, e).exists)(["weak", "medium", "strong"])) {
                            writeln("testing has been done before -- skipping...");
                            continue;
                        }

                        if (resourceExists(learnedMooreInfo, outDir)) {
                            
                            writeln("loading learned machine from disk"); stdout.flush;
                            learnedMoore = learnedMoore.fromFile(learnedMooreFname);
                            
                        } else {

                            import std.file:exists;

                            if (learnFout.exists) {
                                writeln("learn log exists, but learned machine doesn't -- timeout or out-of-memory"); stdout.flush;
                                learnedMoore = null;
                            } else {

                                memoryCheck;

                                writeln("running algorithm ", aId); stdout.flush;
                                learnedMoore = learnCore(aId.str, trainSample, generatedMoore, learnedMooreFname, 
                                                    learnFout, learnedMooreInfo.info["tlim"].to!double, stateLimit);
                            }                            
                        }

                        //writeln("collecting..."); stdout.flush;
                        //GC.collect;

                        if (learnedMoore !is null) {

                            learnedMoore.checkInvars;
                            //learnedMoore.show;

                            memoryCheck;

                            writeln("loading test traces from...");
                            writeln(testSetFname);
                            stdout.flush;

                            auto testSample = loadCachedSample(testSetFname);
                            
                            foreach (tp ; [tuple("weak", &weakTest), tuple("medium", &mediumTest), tuple("strong", &strongTest)]) {

                                auto testConfig = tp[0], testFunc = tp[1];
                            
                                writefln!"computing accuracy using %s evaluation policy..."(testConfig); stdout.flush;
                            
                                auto accuracy = computeAccuracy!testFunc(learnedMoore, testSample.strSample2numSample(learnedMoore.s2bAlphaMap));
                                
                                if (testFout) {

                                    auto fout = File(format!"%s-%s"(testFout, testConfig), "w");

                                    fout.writefln!"machine id | accuracy (%s)"(testConfig);
                                    fout.writefln!"    %3s       %6.2f%%"(learnedMooreFname, accuracy);
                                }
                            
                                writefln!"machine id | accuracy (%s)"(testConfig);
                                writefln!"    %3s       %6.2f%%"(learnedMooreFname, accuracy);
                            }
                                

                            writeln("attempting to find isomorphism...");
                            stdout.flush;
                            
                            auto isomaps = findIsomorphismMappings(generatedMoore, learnedMoore);
                            
                            if (!isomaps.isNull) {
                                writeln("isomorphic");
                            } else {
                                writeln("NOT isomorphic");
                            }

                            stdout.flush;

                        }

                        //after_testing:;
                    }
                }
            }        
        }
    }


    // generate results

    auto fout = File(outDir ~ "all-results.txt", "w");


    foreach (Nq; NqList) {

        foreach (trainSetPreInfo; allTrainSetPreInfos) {

            fout.writefln!"\n\n--- %s states --- %s ---\n"(Nq, trainSetPreInfo);

            
            ulong[] tsSizes;
            double[] wAvgLens;

            foreach (mId; mIdMin .. mIdMax + 1) {

                auto randMooreInfo = new MachineInfo([
                    "gen-method" : "random",
                    "rseed" : mId.str,
                    "nq" : Nq.str,
                    "ni" : Ni.str,
                    "no" : No.str
                ]);
                
                
                auto randMooreFnamePy = randMooreInfo.getFilename(outDir);
            
                auto trainSetInfo = new SampleInfo(
                    trainSetPreInfo.updatedWith(["rseed" : mId.str, "fsm-fname" : randMooreFnamePy]));
                
                auto trainSetFname = trainSetInfo.getFilename(outDir);

                auto trainSample = loadCachedSample(trainSetFname);

                tsSizes ~= trainSample.length;
                wAvgLens ~= trainSample.map!"a.input.length".array.avg;
            }

            fout.writefln!"avg train sample size: %s"(tsSizes.avg);
            fout.writefln!"avg input word len: %s"(wAvgLens.avg);

            foreach (aId; allAlgoIds) {

                fout.writefln!"\nalgorithm %s \n"(aId);

                double[] times;
                double[] states;

                double[][string] accs = ["strong" : [], "medium" : [], "weak" : []];

                foreach (mId; mIdMin .. mIdMax + 1) {

                    auto randMooreInfo = new MachineInfo([
                        "gen-method" : "random",
                        "rseed" : mId.str,
                        "nq" : Nq.str,
                        "ni" : Ni.str,
                        "no" : No.str
                    ]);
                    
                    
                    auto randMooreFnamePy = randMooreInfo.getFilename(outDir);

                    auto randMooreFnameD = randMooreFnamePy ~ "-D";
                
                    auto trainSetInfo = new SampleInfo(
                        trainSetPreInfo.updatedWith(["rseed" : mId.str, "fsm-fname" : randMooreFnamePy]));
                    
                    auto trainSetFname = trainSetInfo.getFilename(outDir);


                    auto testSetInfo = new SampleInfo([
                        "gen-method" : "walk", "size" : testSetSize.str, //"wlen" : wlen.str, 
                        "rseed" : mId.str, "fsm-fname" : randMooreFnamePy]);
                    
                    auto testSetFname = testSetInfo.getFilename(outDir);

                    auto learnedMooreInfo = new MachineInfo([
                        "gen-method" : "learned",
                        "sample-fname" : trainSetFname,
                        "iface-fname" : randMooreFnameD,
                        "algo" : aId.str,
                        "tlim" : str(60 * 15)
                    ]);

                    auto learnedMooreFname = learnedMooreInfo.getFilename(outDir);
                    
                    auto learnFout =  format!"%slearn-result-%s"(outDir, escapeSlashes(learnedMooreFname));
                    auto testFout =  format!"%stest-result-%s-%s"(outDir, escapeSlashes(learnedMooreFname), escapeSlashes(testSetFname));

                    try {

                        auto fin = File(learnFout, "r");

                        auto lines = fin.byLine;

                        lines.popFront;

                        auto line = lines.front.strip.split;

                        fout.writef!"%s     %s     %s     "(line[0], line[1], line[2]);

                        bool timeout = false;
                        bool outofmem = false;

                        if (line[1] == "timeout") timeout = true;
                        else if (line[1] == "out-of-memory") outofmem = true;
                        else {
                            states ~= line[1].to!uint;
                            times ~= line[2].to!double;
                        }

                    } catch (FileException e) {
                        // file not found...
                    } catch (ErrnoException e) {
                        // file not found...
                    }

                    try {

                        foreach (ac; accConfigs) {

                            auto fin = File(format!"%s-%s"(testFout, ac), "r");

                            auto lines = fin.byLine;

                            lines.popFront;

                            auto line = lines.front.strip.split;

                            fout.write(line[1], " ");

                            accs[ac] ~= line[1][0..$-1].to!double;
                        }

                    } catch (FileException e) {

                        fout.write(" ---  ", " ");

                    } catch (ErrnoException e) {
                        fout.write(" ---  ", " ");
                    }

                    fout.writeln;

                }

                fout.writefln!"avg    %s    %s    %s%%   %s%%   %s%%"(
                    states.avg, times.avg,
                    accs["strong"].avg,
                    accs["medium"].avg,
                    accs["weak"].avg);

                fout.writefln!"sdev    %s    %s    %s%%   %s%%   %s%%"(
                    states.sdev, times.sdev,
                    accs["strong"].sdev,
                    accs["medium"].sdev,
                    accs["weak"].sdev);
                    
                fout.writefln!"mdn    %s    %s    %s%%   %s%%   %s%%"(
                    states.mdn, times.mdn,
                    accs["strong"].mdn,
                    accs["medium"].mdn,
                    accs["weak"].mdn);

                writefln!"%s %s %s %s"(times, times.avg, times.sdev, times.mdn);
                writefln!"%s %s %s %s"(states, states.avg, states.sdev, states.mdn);
                foreach (ac; accConfigs) {
                    writefln!"%s %s %s %s %s"(
                        ac, accs[ac], accs[ac].avg, accs[ac].sdev, accs[ac].mdn);
                }

                stdout.flush;

            }

        }
    }

}