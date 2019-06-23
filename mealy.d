

//import std;

import std.stdio;
import std.algorithm;
import std.conv;
import std.array;

import util;



class MealyState(Tin, Tout = Tin) {

    //Tout value;

    Tout[Tin] values;

    MealyState[Tin] children;
    
    uint id;
}


class Mealy(Tin, Tout = Tin) {

    MealyState!(Tin, Tout) init;

    MealyState!(Tin, Tout)[uint] states;

    bool[Tin] alphaIn;

    bool[Tout] alphaOut;

    AlphaMap!(Tin, string) strAlphaMap;


    Tout[] transduce(Tin[] input) {

        auto state = init;

        Tout[] ret;

        foreach (a; input) {
            
            ret ~= state.values[a];

            state = state.children[a];
        }

        return ret;
    }



    static Mealy!(string, string) fromJsonFile(string path) {

        import std.file, std.json;

        auto ret = new Mealy!(string, string);

        auto data = path.readText.parseJSON;
        //auto data = jsonStr.parseJSON;

        //writeln("parsing alphabets");

        foreach (e; data["input-alphabet"].array) {
            ret.alphaIn[e.str] = true;
        }

        foreach (e; data["output-alphabet"].array) {
            ret.alphaOut[e.str] = true;
        }

        //writeln("parsing states");

        uint[string] state2id;

        uint curId = 1; // reserve 0 for initial state

        auto initState = data["initial-state"].str;

        foreach (e; data["states"].array) {

            auto state = new MealyState!(string, string);

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


        //writeln("parsing output function");


        foreach (k, v; data["output-function"].object) {
            
            auto source = ret.states[state2id[k]];

            foreach (a, o; v.object) {
                source.values[a] = o.str;
            }

        }


        //writeln("parsing transition function");

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

            auto jsTrans = jsobj;

            foreach (a; alphaIn.byKey) {

                //jsTrans.object[a.to!string] = s.children[a].id.to!string;
                jsTrans.object[strAlphaMap.inMap[a]] = s.children[a].id.to!string;

            }

            jsTransitions.object[s.id.to!string] = jsTrans;

            //jsOutputs.object[s.id.to!string] = s.value.to!string;
            //jsOutputs.object[s.id.to!string] = strAlphaMap.outMap[s.value];

            auto jsOuts = jsobj;

            foreach (a; alphaIn.byKey) {
                //jsOuts.object[a.to!string] = s.values[a].to!string;
                jsOuts.object[strAlphaMap.inMap[a]] = strAlphaMap.outMap[s.values[a]];
            }

            jsOutputs.object[s.id.to!string] = jsOuts;
        }

        auto jsMealy = jsobj;

        //jsMealy.object["input-alphabet"] = alphaIn .keys.map!"a.to!string".array;
        //jsMealy.object["output-alphabet"] = alphaOut.keys.map!"a.to!string".array;

        jsMealy.object["input-alphabet"] = alphaIn .keys.map!(a => strAlphaMap.inMap[a]).array;
        jsMealy.object["output-alphabet"] = alphaOut.keys.map!(a => strAlphaMap.outMap[a]).array;

        jsMealy.object["states"] = states.keys.map!"a.to!string".array;
        jsMealy.object["initial-state"] = init.id.to!string;

        jsMealy.object["output-function"] = jsOutputs;
        jsMealy.object["transition-function"] = jsTransitions;

        return jsMealy.toPrettyString;
    }


    void makeComplete() {

        auto minOutput = minElement(alphaOut.byKey);


        foreach (s; states.byValue) {
            foreach (a; alphaIn.byKey) {
                if (a !in s.children) {

                    //writefln!"completing %d with %d"(s.id, a);

                    s.children[a] = s;

                } else {

                    //writefln!"NOT completing %d with %d"(s.id, a);
                }

                if (a !in s.values) {
                    s.values[a] = minOutput;
                }
            }
        }
                
    }

}
