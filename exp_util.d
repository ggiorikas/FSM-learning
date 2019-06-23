

import util;

import moore;

import std.format;

import std.string;

import std.exception;

import std.datetime.stopwatch: StopWatch;

import std.stdio;

import std.conv;

import std.process;

import moore_learn_impl;




string escapeSlashes(string s) {

    return s.replace("/", "-");
}



class MachineInfo {

    string[string] info;

    this(string[string] info) {

        this.info = info;

    }


    string getFilename(string outDir) {
    
        alias info = this.info;
        
        auto gm = info["gen-method"];
        
        if (gm == "hand-made") {

            return info["fsm-fname"];
        
        } else if (gm == "random") {
        
            return  format!"%srandom-%s-%s-%s-%s"(
                outDir,info["rseed"], info["nq"], info["no"], info["ni"]);
       
       } else if (gm == "learned") {
            
            return format!"%slearned-%s-%s-%s-%s"(
                outDir,
                escapeSlashes(info["sample-fname"]),
                escapeSlashes(info["iface-fname"]),
                info["algo"], info["tlim"]);
        }

        assert(false);
    }


    string getGenCmd(string outDir) {

        alias info = this.info;
        
        auto gm = info["gen-method"];
        
        enforce(gm == "random");
        
        return format!"python gen_moore.py -mid %s -rs %s -nq %s -ni %s -no %s"(
            getFilename(outDir), info["rseed"], info["nq"], info["no"], info["ni"]);


    }

}

class SampleInfo {

    string[string] info;

    this(string[string] info) {
    
        this.info = info;
    }
    
    
    string getFilename(string outDir) {
    
        alias info = this.info;
        
        auto gm = info["gen-method"];
        
        if (gm == "hand-made") {
        
            return info["sample-fname"];
        
        } else if (gm == "cs") {
        
            return format!"%scs-%s"(outDir, escapeSlashes(info["fsm-fname"]));
        
        } else if (gm == "fixlen") {
        
            return format!"%sfixlen%s-%s-%s-%s-%s"(
                outDir,
                "z0" in info ? "-z0" : "",
                info["rseed"], info["wlen"], info["size"], 
                escapeSlashes(info["fsm-fname"]));

        } else if (gm == "tree") {
        
            return format!"%stree%s-%s-%s-%s"(
                outDir,
                "z0" in info ? "-z0" : "",
                info["rseed"], info["tlen"], escapeSlashes(info["fsm-fname"]));
        
        } else if (gm == "walk") {

            return format!"%swalk-%s-%s-%s"(outDir, info["rseed"], info["size"], escapeSlashes(info["fsm-fname"]));
        }
        
        assert(false);    
    }
    
    
    string getGenCmd(string outDir) {
    
        alias info = this.info;
        
        auto gm = info["gen-method"];
        
        auto sampleFname = getFilename(outDir);
        
        
        if (gm == "cs") {
        
            return format!"python gen_traces.py cs -mid %s -tid %s"(
                info["fsm-fname"], sampleFname);
        
        } else if (gm == "fixlen") {
        
            return format!"python %s fixlen -mid %s -rs %s -tid %s -sz %s -wlen %s"(
                        "z0" in info ? "gen-traces-z0.py" : "gen_traces.py",
                        info["fsm-fname"], info["rseed"], sampleFname, 
                        info["size"], info["wlen"]);
        
        } else if (gm == "tree") {
        
            return format!"python %s tree -mid %s -tid %s -rs %s -tlen %s"(
                        "z0" in info ? "gen-traces-z0.py" : "gen_traces.py",
                        info["fsm-fname"], sampleFname, 
                        info["rseed"], info["tlen"]);

        } else if (gm == "walk") {

            return format!"generate.exe --mid %s-D --tid %s --rs %s --sz %s"(
                info["fsm-fname"], sampleFname, info["rseed"], info["size"]);
        }
        
        
        assert(false);    
    }

}



import std.file:exists;

bool resourceExists(Info)(Info info, string outDir) {

    return exists(info.getFilename(outDir));

}


import std.stdio:writeln;
import std.process:executeShell;

void generateFromInfo(Info)(Info info, string outDir) {

    
    if (!resourceExists(info, outDir)) {
    
        writeln("\ngenerating non existing resource...");
        writeln(info.getFilename(outDir));

        auto genCmd = info.getGenCmd(outDir);
        
        writeln("\nrunning command...");
        writeln(genCmd);
        stdout.flush;
        
        executeShell(genCmd);
    
    }
}


Moore!TraceElem[string] MACHINE_CACHE;
Trace!string[][string] SAMPLE_CACHE;

auto loadCachedMachine(string fname) {

    if (auto pfsm = fname in MACHINE_CACHE) {
        
        return *pfsm;
    } else {
    
        auto fsm = Moore!TraceElem.fromFile(fname);
        
        MACHINE_CACHE[fname] = fsm; 
        
        return fsm;
    }
}


auto loadCachedSample(string fname) {
    
    if (auto psample = fname in SAMPLE_CACHE) {
        
        return *psample;
    } else {
    
        auto sample = loadMooreSample!string(fname);
    
        SAMPLE_CACHE[fname] = sample; 
    
        return sample;
    }
}

void clearCachedResource(Cache)(string fname, Cache cache) {
    enforce(cache.remove(fname));    
}

void clearCachedMachine(string fname) { clearCachedResource(fname, MACHINE_CACHE); }
void clearCachedSample (string fname) { clearCachedResource(fname,  SAMPLE_CACHE); }

auto updatedWith(K, V)(V[K] oldDict, V[K] extraStuff) {

    auto ret = oldDict.dup;

    foreach (k, v; extraStuff) {
        ret[k] = v;
    }
    
    return ret;
}


Moore!TraceElem learnCore(string aId, Trace!string[] sample, Moore!TraceElem targetMoore, 
    string learnedMooreOutputFile, string logOutputFile, double timeoutLimitSeconds, int memoryLimitMB) {

    Moore!TraceElem moore;

    StopWatch sw;
    sw.start();

    bool timeout = false;
    bool outofmem = false;

    ulong elapsed = 0;

    try {
             if (aId == "1") moore = algorithm1!TraceElem(sample, targetMoore, timeoutLimitSeconds, memoryLimitMB);
        else if (aId == "2") moore = algorithm2!TraceElem(sample, targetMoore, timeoutLimitSeconds, memoryLimitMB);
        else if (aId == "3") moore = algorithm3!TraceElem(sample, targetMoore, timeoutLimitSeconds, memoryLimitMB);

        elapsed = sw.peek.total!"usecs";


        writeln("storing learned Moore machine to..."); 
        writeln(learnedMooreOutputFile);
        stdout.flush;

        moore.saveToFile(learnedMooreOutputFile);
        writeln("done!"); stdout.flush;

    } catch (TimeoutLimitException) {

        timeout = true;
        moore = null;

        writeln("timeout!"); stdout.flush;

    } catch (MemoryLimitException) {

        outofmem = true;
        moore = null;

        writeln("out of memory!"); stdout.flush;

    } finally {

        if (logOutputFile !is null) {
            auto fout = File(logOutputFile, "w");

            fout.writeln("machine id | number of states | elapsed time");
            fout.writefln!"  %3s           %7s             %9.6f    "(
                learnedMooreOutputFile,
                timeout ? "timeout" : (outofmem ? "out-of-memory" : moore.states.length.to!string),
                elapsed / 1000000.0
            );
        }
    }
    
    if (outofmem) {
        import core.stdc.stdlib;
        writeln("exiting to free memory...");
        exit(0);
    }

    return moore;
    
}


void pym2dm(string pym, string dm, bool jsonExists = false) {


    auto pymjs = pym ~ ".json";
    
    if (!jsonExists) {
        auto cmd = format!"python moore2json.py -mid %s -fout %s"(pym, pymjs);
        executeShell(cmd);        
    }

    auto smoore = Moore!string.fromJsonFile(pymjs);

    auto bmoore = smoore.strMoore2binMoore!TraceElem;

    bmoore.saveToFile(dm);
}
