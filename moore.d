


import std.algorithm;
import std.conv;
import std.array;

import std.exception;
import std.traits;
import std.format;
import std.stdio;

import util;

class MooreState(Tin, Tout = Tin) {

    Tout value;

    MooreState[Tin] children;

    uint id;
}


struct JustInterface;


class Moore(Tin, Tout = Tin) {

    MooreState!(Tin, Tout) init;

    MooreState!(Tin, Tout)[uint] states; // init should always be on id 0

    bool[Tin]  alphaIn;
    bool[Tout] alphaOut;

    AlphaMap!(Tin, string, Tout, string) b2sAlphaMap;
    AlphaMap!(string, Tin, string, Tout) s2bAlphaMap;


    void checkInvars() {
        enforce(init == states[0]);
    }

    void show() {

        writeln("\ninput alphabet:");
        alphaIn.keys.sort.writeln;

        writeln("\noutput alphabet:");
        alphaOut.keys.sort.writeln;

        writeln("\nstates:");

        foreach (i; states.keys.sort) {

            auto q = states[i];

            enforce(q.id == i);

            writeln("\nid: ", i);
            //writeln("address: ", &q);
            writeln("output: ", q.value);
            writeln("children: ");

            foreach (a; alphaIn.keys.sort) {
                writeln("  ", a, " -> ", q.children[a].id);
                enforce(q.children[a] == states[q.children[a].id]);
            }

            writeln;
        }

    }

    void saveToFile(JI = void)(string path) const {

        import std.stdio;
        import std.file : write;
        import std.algorithm;
        import std.json;

        /* binary format

            size of input alphabet
            input alphabet elements
            size of output alphabet
            output alphabet elements
            number of states
            
            states (in order of increasing id)
                value
                children ids (in order of increasing input letter), -1 if does not exist

        */

        //writeln("saving fsm: ", path);

        auto fout = File(path, "wb");

        //writefln!"storing alphaIn len: %s"(alphaIn.keys.length);
        fout.rawWrite([alphaIn.keys.length]);
        fout.rawWrite(alphaIn.keys.sort.array);

        //writefln!"storing alphaOut len: %s"(alphaIn.keys.length);
        fout.rawWrite([alphaOut.keys.length]);
        fout.rawWrite(alphaOut.keys.sort.array);

        // TODO: also store mappings (as json) if available -- DONE

        if (s2bAlphaMap.inMap  !is null && 
            s2bAlphaMap.outMap !is null && 
            b2sAlphaMap.inMap  !is null && 
            b2sAlphaMap.outMap !is null) {
                
            format!"%s-alpha-maps.json"(path).write(
                format!"[\n%s\n,\n%s\n]"(
                    s2bAlphaMap.toJsonStr,
                    b2sAlphaMap.toJsonStr
                )
            );
        }

        static if (allSameType!(JI, JustInterface)) {
            return;
        }

        fout.rawWrite([states.length]);

        auto sortedAlphabet = alphaIn.keys.sort.array;

        typeof(MooreState!(Tin, Tout).id)[1] idArr;
        typeof(MooreState!(Tin, Tout).value)[1] valueArr;

        //pragma(msg, typeof(idArr));
        //pragma(msg, typeof(valueArr));

        typeof(MooreState!(Tin, Tout).id)[] childrenArr;
        childrenArr.length = sortedAlphabet.length;

        //pragma(msg, typeof(childrenArr));

        foreach (q; states) {

            //enforce(i == q.id);

            idArr[0] = q.id;
            valueArr[0] = q.value;

            fout.rawWrite(idArr);
            fout.rawWrite(valueArr);

            foreach (i, a; sortedAlphabet) {
                childrenArr[i] = a in q.children ? q.children[a].id : -1;
            }

            //auto children = sortedAlphabet.map!(a => a in q.children ? q.children[a].id : -1).array;

            fout.rawWrite(childrenArr);
        }

    }

    static Moore!(Tin, Tout) fromFile(JI = void)(string path) {

        

        import std.stdio;
        import std.file;
        import std.algorithm;
        import std.json;

        /* binary format

            size of input alphabet
            input alphabet elements
            size of output alphabet
            output alphabet elements
            number of states
            
            states (in order of increasing id)
                value
                children ids (in order of increasing input letter), -1 if does not exist

        */

        //writeln("loading fsm: ", path);

        auto ret = new Moore!(Tin, Tout);

        auto fin = File(path, "rb");

        auto alphaInSize = fin.rawRead(new typeof(alphaIn.keys.length)[1])[0];
        auto alphaInArr = fin.rawRead(new Tin[alphaInSize]);

        foreach (a; alphaInArr) {
            ret.alphaIn[a] = true;
        }

        //writefln!"loaded alphaIn len: %s"(ret.alphaIn.keys.length);


        auto alphaOutSize = fin.rawRead(new typeof(alphaOut.keys.length)[1])[0];
        auto alphaOutArr = fin.rawRead(new Tout[alphaOutSize]);

        foreach (a; alphaOutArr) {
            ret.alphaOut[a] = true;
        }

        //writefln!"loaded alphaOut len: %s"(ret.alphaOut.keys.length);


        // TODO: also load mappings (from json) if available -- DONE

        auto mapsPath = format!"%s-alpha-maps.json"(path);

        if (mapsPath.exists) {
            //writeln("reading alpha maps...");
            auto data = mapsPath.readText.parseJSON;
            ret.s2bAlphaMap = ret.s2bAlphaMap.fromJson(data.array[0].toString);
            ret.b2sAlphaMap = ret.b2sAlphaMap.fromJson(data.array[1].toString);
        }


        static if (allSameType!(JI, JustInterface)) {
            return ret;
        }

        //writefln!"\nstate count: %s \nalphaInSize: %s \nalphaOutSize: %s"(
        //    -1, alphaInSize, alphaOutSize);

        auto stateCount = fin.rawRead(new typeof(states.length)[1])[0];

        typeof(MooreState!(Tin, Tout).id)[1] idArr;
        typeof(MooreState!(Tin, Tout).value)[1] valueArr;

        //pragma(msg, typeof(idArr));
        //pragma(msg, typeof(valueArr));

        typeof(MooreState!(Tin, Tout).id)[] childrenArr;
        childrenArr.length = alphaInSize;

        auto sortedAlphabet = ret.alphaIn.keys.sort.array;

        foreach (i; 0 .. stateCount) {
            
            //auto q = new MooreState!(Tin, Tout);

            fin.rawRead(idArr);
            fin.rawRead(valueArr);

            auto id = idArr[0];
            auto value = valueArr[0];

            MooreState!(Tin, Tout) q;

            if (auto pq = id in ret.states) {
                q = *pq;
            } else {
                q = new typeof(q);
                ret.states[id] = q;
            }

            q.id = id;
            q.value = value;

            fin.rawRead(childrenArr);

            foreach (j, cid; childrenArr) {

                auto a = sortedAlphabet[j];

                MooreState!(Tin, Tout) c;

                if (auto pc = cid in ret.states) {
                    c = *pc;
                } else {
                    c = new typeof(c);
                    ret.states[cid] = c;
                }

                q.children[a] = c;
            }
        }

        ret.init = ret.states[0];

        return ret;
    }


    static Moore!(string, string) fromJsonFile(string path) {

        import std.file, std.json;

        auto ret = new Moore!(string, string);

        auto data = path.readText.parseJSON;
        //auto data = jsonStr.parseJSON;

        foreach (e; data["input-alphabet"].array) {
            ret.alphaIn[e.str] = true;
        }

        foreach (e; data["output-alphabet"].array) {
            ret.alphaOut[e.str] = true;
        }


        uint[string] state2id;

        uint curId = 1; // reserve 0 for initial state

        auto initState = data["initial-state"].str;

        foreach (e; data["states"].array) {

            auto state = new MooreState!(string, string);

            if (e.str == initState) {
                state.id = 0;
                ret.states[0] = state;
                state2id[e.str] = 0;
            } else {
                state.id = curId;
                ret.states[curId] = state;
                state2id[e.str] = curId++;
            }
        }


        foreach (k, v; data["output-function"].object) {
            ret.states[state2id[k]].value = v.str;
        }

        foreach (k, v; data["transition-function"].object) {

            auto source = ret.states[state2id[k]];

            foreach (a, q; v.object) {
                source.children[a] = ret.states[state2id[q.str]];
            }
        }

        ret.init = ret.states[0];

        return ret;
    }


    string toJsonStr() const {

        import std.json;

        JSONValue jsobj() {
            return parseJSON("{}");
        }

        auto jsTransitions = jsobj;
        auto jsOutputs = jsobj;

        foreach (s; states.byValue) {

            JSONValue jsTrans = jsobj;

            foreach (a; alphaIn.byKey) {

                jsTrans.object[a.to!string] = s.children[a].id.to!string;
                //jsTrans.object[strAlphaMap.inMap[a]] = s.children[a].id.to!string;

            }

            jsTransitions.object[s.id.to!string] = jsTrans;

            jsOutputs.object[s.id.to!string] = s.value.to!string;
            //jsOutputs.object[s.id.to!string] = strAlphaMap.outMap[s.value];
        }

        auto jsMoore = jsobj;

        jsMoore.object["input-alphabet"] = alphaIn .keys.map!"a.to!string".array;
        jsMoore.object["output-alphabet"] = alphaOut.keys.map!"a.to!string".array;

        //jsMoore.object["input-alphabet"] = alphaIn .keys.map!(a => strAlphaMap.inMap[a]).array;
        //jsMoore.object["output-alphabet"] = alphaOut.keys.map!(a => strAlphaMap.outMap[a]).array;

        jsMoore.object["states"] = states.keys.map!"a.to!string".array;
        jsMoore.object["initial-state"] = init.id.to!string;

        jsMoore.object["output-function"] = jsOutputs;
        jsMoore.object["transition-function"] = jsTransitions;

        return jsMoore.toPrettyString;
    }


    void makeComplete() {

        import std.stdio;

        foreach (s; states.byValue)
            foreach (a; alphaIn.byKey)
                if (a !in s.children) {

                    //writefln!"completing %s with %s"(s.id, a);

                    s.children[a] = s;

                } else {

                    //writefln!"NOT completing %s with %s"(s.id, a);
                }
    }

}