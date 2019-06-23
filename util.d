
import std.stdio;
import std.string;
import std.algorithm;
import std.algorithm.iteration : splitter;
import std.conv;
import std.array;
import std.typecons;

import moore;

class TimeoutLimitException : Exception {

    this(string msg, string file = __FILE__, size_t line = __LINE__) {
        super(msg, file, line);
    }
}

class MemoryLimitException : Exception {

    this(string msg, string file = __FILE__, size_t line = __LINE__) {
        super(msg, file, line);
    }
}


struct Trace(Tin, Tout = Tin) {

    Tin[] input;
    Tout[] output;

}


alias TraceElem = ubyte;


struct AlphaMap(TinFrom, TinTo, ToutFrom = TinFrom, ToutTo = TinTo) {

     TinTo[ TinFrom]  inMap;
    ToutTo[ToutFrom] outMap;

    auto inverted() {

        AlphaMap!(TinTo, TinFrom, ToutTo, ToutFrom) ret;

        foreach (e; this. inMap.byKeyValue) ret. inMap[e.value] = e.key;
        foreach (e; this.outMap.byKeyValue) ret.outMap[e.value] = e.key;

        return ret;
    }

    string toJsonStr() const {

        import std.json;

        JSONValue jsobj() {
            return parseJSON("{}");
        }

        auto jsInMap = jsobj;
        auto jsOutMap = jsobj;

        foreach (k, v; inMap) {
            jsInMap.object[k.to!string] = v.to!string;
        }

        foreach (k, v; outMap) {
            jsOutMap.object[k.to!string] = v.to!string;
        }

        auto ret = jsobj;

        ret.object["input-map"] = jsInMap;
        ret.object["output-map"] = jsOutMap;

        return ret.toPrettyString;
    }

    static auto fromJson(string jsonStr) {

        AlphaMap!(TinFrom, TinTo, ToutFrom, ToutTo) ret;

        import std.json;

        auto data = jsonStr.parseJSON;

        foreach (k, v; data["input-map"].object) {
            ret.inMap[k.to!TinFrom] = v.str.to!TinTo;
        }

        foreach (k, v; data["output-map"].object) {
            ret.outMap[k.to!ToutFrom] = v.str.to!ToutTo;
        }

        return ret;
    }

}


void saveMooreSample(Tin, Tout = Tin)(Trace!(Tin, Tout)[] sample, string fname) {

    auto fout = File(fname, "w");

    foreach (tr; sample) {

        fout.write(tr.input.join(","));
        fout.write(" -> ");
        fout.writeln(tr.output.join(","));
    }
}


auto loadMooreSample(Tin, Tout = Tin)(string fname) {

    import core.memory: GC;

    Trace!(Tin, Tout)[] sample;

    Trace!(Tin, Tout) curTrace;

    auto fin = File(fname);

    int curLine = 0;

    foreach (string line; lines(fin)) {

        //*

        auto temp = line.strip.split(" -> ");

        //writeln(temp[0]);
        //writeln(temp[1]);
        //writeln();

        curTrace.input = temp[0].split(",").map!(a => a.to!Tin).array;
        curTrace.output = temp[1].split(",").map!(a => a.to!Tout).array;

        sample ~= curTrace;

        //*/



    }

    GC.collect;

    return sample;
}



auto loadMealySampleFF(string fname) {

    // parse flexfringe input file format

    Trace!(string, string)[] sample;

    auto fin = File(fname);

    int curLine = 0;

    foreach (string line; lines(fin)) {

        if (curLine++ == 0) continue; // skip header

        auto temp = line.strip.split(" ");

        // skip temp[0]

        auto len = temp[1].to!int;

        Trace!(string, string) curTrace;

        for (int i = 2; i < len + 2; ++ i) {

            auto io = temp[i].split("/");

            curTrace.input ~= io[0];
            curTrace.output ~= io[1];
        }

        sample ~= curTrace;
    }

    import core.memory: GC;

    GC.collect;

    /*
    foreach (e; sample) {
        writeln(e.input);
        writeln(e.output);
        writeln;
    }
    //*/

    return sample;
}


auto loadMealySample(Tin, Tout = Tin)(string fname) {

    import core.memory: GC;

    Trace!(Tin, Tout)[] sample;

    auto fin = File(fname);

    int curLine = 0;

    foreach (string line; lines(fin)) {

        //+

        auto temp = line.strip.split(" -> ");

        //writeln(temp[0]);
        //writeln(temp[1]);
        //writeln();

        Trace!(Tin, Tout) curTrace;

        curTrace.input = temp[0].split(",").map!(a => a.to!Tin).array;
        curTrace.output = temp[1].split(",").map!(a => a.to!Tout).array;

        sample ~= curTrace;

        //+/



    }

    GC.collect;

    return sample;
}



auto alphabets2strNumMappings(Tin, Tout = Tin)(bool[string] alphaIn, bool[string] alphaOut) {

    AlphaMap!(string, Tin, string, Tout) ret;

     Tin[string] inMap;
    Tout[string] outMap;

    Tin  uidIn  = 0; 
    foreach (a; alphaIn .byKey) inMap[a] = uidIn ++; 
    assert(uidIn  == alphaIn .length);

    Tout uidOut = 0; 
    foreach (a; alphaOut.byKey) outMap[a] = uidOut ++; 
    assert(uidOut == alphaOut.length);

    ret.inMap = inMap;
    ret.outMap = outMap;

    return ret;
}


auto strSample2numSample(Trace!(string)[] strSample, AlphaMap!(string, TraceElem) alphaMap) {

    Trace!(TraceElem)[] ret;

    Trace!(TraceElem) curTrace;

    foreach(ref t; strSample) {

        curTrace.input  = t.input .map!(a => alphaMap. inMap[a]).array;
        curTrace.output = t.output.map!(a => alphaMap.outMap[a]).array;

        ret ~= curTrace;
    }

    return ret;
}


auto numSample2strSample(Trace!(TraceElem)[] strSample, AlphaMap!(TraceElem, string) alphaMap) {

    Trace!(string)[] ret;

    Trace!(string) curTrace;

    foreach(ref t; strSample) {

        curTrace.input  = t.input .map!(a => alphaMap. inMap[a]).array;
        curTrace.output = t.output.map!(a => alphaMap.outMap[a]).array;

        ret ~= curTrace;
    }

    return ret;
}


auto strAlpha2numAlpha(bool[string] strAlphaIn, bool[string] strAlphaOut, AlphaMap!(string, TraceElem) alphaMap) {

    bool[TraceElem] alphaIn;
    bool[TraceElem] alphaOut;

    foreach (k; strAlphaIn .byKey) alphaIn [alphaMap. inMap[k]] = true;
    foreach (k; strAlphaOut.byKey) alphaOut[alphaMap.outMap[k]] = true;

    return tuple(alphaIn, alphaOut);
}


Tuple!(bool[Tin], bool[Tout]) sample2alphabets(Tin, Tout)(const ref Trace!(Tin, Tout)[] sample) {

    bool[Tin ] alphaIn;
    bool[Tout] alphaOut;

    foreach (ref t; sample) {
        foreach (i; t.input ) alphaIn [i] = true;
        foreach (o; t.output) alphaOut[o] = true;
    }

    return tuple(alphaIn, alphaOut);
}


Tuple!(bool[string], bool[string]) loadAlphabets(string fsmInterfacePath) {

    import std.file, std.json;

    auto data = fsmInterfacePath.readText.parseJSON;

    bool[string] alphaIn;
    bool[string] alphaOut;

    foreach (e; data["input-alphabet"].array) {
        alphaIn[e.str] = true;
    }

    foreach (e; data["output-alphabet"].array) {
        alphaOut[e.str] = true;
    }

    return tuple(alphaIn, alphaOut);
}



// convert string moore to int moore

Moore!(Tin, Tout) strMoore2binMoore(Tin, Tout = Tin)(Moore!(string, string) smoore) {

    auto bmoore = new Moore!(Tin, Tout);


    // first, map the alphabets

    bmoore.s2bAlphaMap = alphabets2strNumMappings!(Tin, Tout)(smoore.alphaIn, smoore.alphaOut);
    bmoore.b2sAlphaMap = bmoore.s2bAlphaMap.inverted;
    

    // now, build bmoore

    foreach (k, v; bmoore.s2bAlphaMap.inMap) {
        bmoore.alphaIn[v] = true;
    }

    foreach (k, v; bmoore.s2bAlphaMap.outMap) {
        bmoore.alphaOut[v] = true;
    }

    foreach (i, sq; smoore.states) {

        MooreState!(Tin, Tout) bq;

        if (auto pbq = i in bmoore.states) {
            bq = *pbq;
        } else {
            bq = new typeof(bq);
            bmoore.states[i] = bq;
        }

        bq.id = i;
        bq.value = bmoore.s2bAlphaMap.outMap[sq.value];

        foreach (a, sqa; sq.children) {

            typeof(bq) bqa;

            auto j = sqa.id;

            if (auto pbqa = j in bmoore.states) {
                bqa = *pbqa;
            } else {
                bqa = new typeof(bq);
                bmoore.states[j] = bqa;
            }

            bq.children[bmoore.s2bAlphaMap.inMap[a]] = bqa;
        }

    }

    bmoore.init = bmoore.states[0];

    return bmoore;
}


