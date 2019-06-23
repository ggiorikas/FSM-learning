

import std;

import util;

import moore;

import generate_impl;


void main(string[] args) {



    import std.getopt;


    string fsmPath;
    string samplePath;
    int randomSeed;
    int sampleSize;


    auto helpInfo = getopt(
        args,

        std.getopt.config.required,
        "mid", "path to machine", &fsmPath, 
        
        std.getopt.config.required,
        "tid", "path to store generated traces", &samplePath,
        
        std.getopt.config.required,
        "rs", "random seed", &randomSeed, 

        std.getopt.config.required,
        "sz", "trace count", &sampleSize, 
    );

    if (helpInfo.helpWanted) {

        defaultGetoptPrinter("Usage:", helpInfo.options);
        return;
    }


    // load machine

    auto fsm = Moore!TraceElem.fromFile(fsmPath);


    // generate sample

    auto rng = Random(randomSeed);

    auto sample = genSample(rng, fsm, sampleSize);
    //auto sample = genTreeSample(rng, fsm, sampleSize);
    

    auto sampleStr = numSample2strSample(sample, fsm.b2sAlphaMap);

    sampleStr.saveMooreSample(samplePath);

    // store sample to file


    

}