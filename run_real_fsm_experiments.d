

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


void main() {

    string outDir = "o2/";

    
    auto accConfigs = ["strong", "medium", "weak"];

    auto allMachines = ["cvs", "editor", "jhotdraw", "elevator"];
        
    auto allAlgoIds = [1, 2, 3]; // [1, 2, 3];

    auto allTrainSetPreInfos = [

        "cvs" : [
            ["gen-method" : "cs"],        
    
            ["gen-method" : "walk", "size" :  "20000"],
            ["gen-method" : "walk", "size" :  "40000"],
            ["gen-method" : "walk", "size" :  "60000"],
            ["gen-method" : "walk", "size" :  "80000"],
    
        ],

        "editor" : [
            ["gen-method" : "cs"],        
            ["gen-method" : "walk", "size" :  "100"],
            ["gen-method" : "walk", "size" :  "200"],
            ["gen-method" : "walk", "size" :  "300"],
            ["gen-method" : "walk", "size" :  "400"],
            ["gen-method" : "walk", "size" :  "500"],

        ],

        "jhotdraw" : [
            ["gen-method" : "cs"],        
            ["gen-method" : "walk", "size" :   "250"],
            ["gen-method" : "walk", "size" :   "500"],
            ["gen-method" : "walk", "size" :   "750"],
            ["gen-method" : "walk", "size" :  "1000"],

        ],

        "elevator" : [
            ["gen-method" : "cs"],        
            ["gen-method" : "walk", "size" :   "200"],
            ["gen-method" : "walk", "size" :   "400"],
            ["gen-method" : "walk", "size" :   "600"],
            ["gen-method" : "walk", "size" :   "800"],

        ],
    ];

    auto testSetSize = 200_000;

    int stateLimit = 1_000_000;


    bool runExperiments = true;

    if (runExperiments) {

        // run experiments
    
        foreach (mIdI, mId; allMachines) {

            ++ mIdI;
        
            auto realMooreInfo = new MachineInfo([
                "gen-method" : "hand-made",
                "fsm-fname" : "fsm/" ~ mId
            ]);


            auto realMooreFnamePy = realMooreInfo.getFilename(outDir);
            
            auto realMooreFnameD = realMooreFnamePy ~ "-D";
            pym2dm(realMooreFnamePy, realMooreFnameD, true);
            
            
            foreach (trainSetPreInfo; allTrainSetPreInfos[mId]) {
        
                auto trainSetInfo = new SampleInfo(
                    trainSetPreInfo.updatedWith(["rseed" : (mIdI+1).str, "fsm-fname" : realMooreFnamePy]));
                
                auto trainSetFname = trainSetInfo.getFilename(outDir);

                writeln("generating traces for ", realMooreFnamePy); stdout.flush;
                generateFromInfo(trainSetInfo, outDir);
                

                auto trainSample = loadCachedSample(trainSetFname);


                auto testSetInfo = new SampleInfo([
                    "gen-method" : "walk", "size" : testSetSize.str, //"wlen" : wlen.str, 
                    "rseed" : (mIdI+1).str, "fsm-fname" : realMooreFnamePy]);
                
                auto testSetFname = testSetInfo.getFilename(outDir);
                
                writeln("generating test traces for ", realMooreFnamePy); stdout.flush;
                generateFromInfo(testSetInfo, outDir);
                
                
                //writeln("loading cached moore...");
                auto generatedMoore = loadCachedMachine(realMooreFnameD);
                //writeln("loaded cached moore...");

                foreach (aId; allAlgoIds) {

                    auto learnedMooreInfo = new MachineInfo([
                        "gen-method" : "learned",
                        "sample-fname" : trainSetFname,
                        "iface-fname" : realMooreFnameD,
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


    // generate results

    auto fout = File(outDir ~ "all-results.txt", "w");


    foreach (mIdI, mId; allMachines) {

        ++ mIdI;

        auto realMooreInfo = new MachineInfo([
            "gen-method" : "hand-made",
            "fsm-fname" : "fsm/" ~ mId
        ]);


        auto realMooreFnamePy = realMooreInfo.getFilename(outDir);
        
        auto realMooreFnameD = realMooreFnamePy  ~ "-D";


        foreach (aId; allAlgoIds) {

            //fout.writefln!"\n\n--- %s states --- %s ---\n"(Nq, trainSetPreInfo);

            fout.writefln!"\n\n--- %s --- %s ---\n"(mId, aId);

            double[] times;
            uint[] states;

            double[][string] accs = ["strong" : [], "medium" : [], "weak" : []];

            foreach (trainSetPreInfo; allTrainSetPreInfos[mId]) {

                //fout.writefln!"\nalgorithm %s \n"(aId);

                auto trainSetInfo = new SampleInfo(
                    trainSetPreInfo.updatedWith(["rseed" : (mIdI+1).str, "fsm-fname" : realMooreFnamePy]));
                
                auto trainSetFname = trainSetInfo.getFilename(outDir);

                fout.writefln!"\ntraining sample %s \n"(trainSetInfo.info);


                auto testSetInfo = new SampleInfo([
                    "gen-method" : "walk", "size" : testSetSize.str, //"wlen" : wlen.str, 
                    "rseed" : (mIdI+1).str, "fsm-fname" : realMooreFnamePy]);
                
                auto testSetFname = testSetInfo.getFilename(outDir);

                auto learnedMooreInfo = new MachineInfo([
                    "gen-method" : "learned",
                    "sample-fname" : trainSetFname,
                    "iface-fname" : realMooreFnameD,
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
            
        }
    }

}