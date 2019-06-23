
import std.stdio;
import std.algorithm;
import std.random;
import std.array;
import std.process;
import std.typecons;
import std.conv;
import std.exception;
import std.range;
import std.math;

import util;
import exp_util;
import moore;

import mealy;


double normal(RNG)(double mu, double sigma, ref RNG rng) {

    // https://en.wikipedia.org/wiki/Box%E2%80%93Muller_transform

	static const double two_pi = 2.0*3.14159265358979323846;

	static double z1;
	static bool generate = false;

	generate = !generate;

	if (!generate) {
        return z1 * sigma + mu;
    }

	double u1 = uniform!"()"(0.0, 1.0, rng);
    double u2 = uniform!"()"(0.0, 1.0, rng);

    double z0 = sqrt(-2.0 * log(u1)) * cos(two_pi * u2);
           z1 = sqrt(-2.0 * log(u1)) * sin(two_pi * u2);
	
    return z0 * sigma + mu;
}



uint biasedChoice(RNG)(ref RNG rng, double[] dist) {

    double sum = 0;

    auto u01 = uniform01(rng);

    //writefln!"u01 == %s"(u01);

    foreach (i, e; dist) {

        sum += e;

        if (u01 <= sum) {
            return cast(uint)i;
        }
    }

    return cast(uint)(dist.length - 1);
}



uint diameter(Tin, Tout, alias FSM)(FSM!(Tin, Tout) fsm) 
    if (is(FSM!(Tin, Tout) == Moore!(Tin, Tout)) || 
        is(FSM!(Tin, Tout) == Mealy!(Tin, Tout))) {

    //writeln("computing diameter...");

    // use bfs

    import std.container;

    bool[uint] visited;

    auto queue = DList!(Tuple!(typeof(fsm.init), int))();

    auto sortedAlphaIn = fsm.alphaIn.keys.sort;

    auto distMax = 0;


    queue.insertBack(tuple(fsm.init, 0));

    //writeln("entering bfs loop...");

    while (!queue.empty) {

        //writefln!"popping front..."();

        auto t = queue.front;
        queue.removeFront;

        auto state = t[0], dist = t[1];

        //writefln!"marking %s visited..."(state.id);

        visited[state.id] = true;

        //enforce(dist >= distMax);

        if (dist > distMax) { // do we really need to test? -- looks like no...
            distMax = dist;
        }

        //writefln!"entering child loop..."();

        foreach (a; sortedAlphaIn) {
            //writefln!"checking child %s of %s..."(a, state.id);
            auto child = state.children[a];

            auto cdist = dist + 1;

            if (child.id !in visited) {
                queue.insertBack(tuple(child, cdist));
            }
        }
    }

    return distMax;
}


const useTree = true;

Trace!(Tin, Tout)[] genSample(RNG, Tin, Tout, alias FSM)(ref RNG rng, FSM!(Tin, Tout) fsm, int sampleSize)
    if (is(FSM!(Tin, Tout) == Moore!(Tin, Tout)) || 
        is(FSM!(Tin, Tout) == Mealy!(Tin, Tout))) {


    bool[ulong] sink;

    uint[ulong] visited; // track how many times each state has been visited so far

    uint[Tin][ulong] taken; // track how many transitions were taken

    Tin[][ulong][ulong] targetStates; // from q i can visit p with {a, b, c}

    foreach (k, v; fsm.states) {
        visited[k] = 0;

        foreach (i; 0 .. fsm.alphaIn.length) {
            //taken[k][i] = 0;
        }

        foreach (a; fsm.alphaIn.byKey) {
            taken[k][a] = 0;
            auto c = v.children[a];
            targetStates[v.id][c.id] ~= a;
        }

        if (all!(a => v.id == v.children[a].id)(fsm.alphaIn.keys)) {
            sink[v.id] = true;
        } else {
            sink[v.id] = false;
        }
    }

    auto alphaInSorted = fsm.alphaIn.keys.sort.array;

    Trace!(Tin, Tout)[] ret;

    auto diam = diameter(fsm);

    //writeln("done with diameter...");

    auto loLen = (0.5 * diam + 0.1).to!int;
    if (loLen <= 0) loLen = 1;

    auto hiLen = (3.5 * diam + 0.1).to!int;
    if (hiLen <= 0) hiLen = 1;

    writefln!"diam: %s, loLen: %s, hiLen: %s"(diam, loLen, hiLen);


    static if (useTree) {
        auto root = new TreeNode!(Tin, Tout);
        int treeLen = 1;

    }

    const twiceDiam = 2.0 * diam;
    const halfDiam = 0.5 * diam; 


    //foreach (_; 0 .. sampleSize) {
    int n = 0;
    outer:
    while (true) {

        auto q = fsm.init;

        ++visited[q.id];

        Trace!(Tin, Tout) tr;

        static if (is(FSM!(Tin, Tout) == Moore!(Tin, Tout))){
            tr.output ~= q.value;            
        }

        //auto traceSize = uniform!"[]"(loLen, hiLen, rng);

        auto traceSize = (normal(twiceDiam, halfDiam, rng) + 0.5).to!int + 1;

        static if (useTree) {
            bool traceExists = true;
            auto tnode = root;
        }

        //foreach (i; 0 .. traceSize) {
        int i = 0;
        while (true) {

            auto targetStatesArr = targetStates[q.id].keys;

            auto freq = targetStatesArr.map!(sid => visited[sid] + 1).array;

            double m = freq.maxElement;

            double d = 1.0 / (freq.map!(a => (m/a) ).sum);

            auto dist = freq.map!(a => (m/a)*d).array;

            auto nextStates = alphaInSorted.map!(a => q.children[a].id).array;

            //writeln; q.id.writeln; nextStates.writeln; 
            //targetStatesArr.writeln; freq.writeln; dist.writeln;

            auto j = biasedChoice(rng, dist);

            auto q1id = targetStatesArr[j];

            // pick the letter randomly

            auto a = choice(targetStates[q.id][q1id], rng);

            ++ taken[q.id][a];

            //writefln!"picked letter %s to visit state %s"(alphaInSorted[j], q.children[a].id);

            tr.input ~= a;

            static if (is(FSM!(Tin, Tout) == Mealy!(Tin, Tout))){
                tr.output ~= q.values[a];            
            }

            q = q.children[a];

            static if (is(FSM!(Tin, Tout) == Moore!(Tin, Tout))){
                tr.output ~= q.value;            
            }
            

            ++ visited[q.id];



            static if (useTree) {
                auto added = tnode.addChild(a);

                if (added) {
                    treeLen += 1;
                    traceExists = false;

                    if (treeLen >= sampleSize) {
                        ret ~= tr;
                        break outer;
                    }
                }
                
                tnode = tnode.children[a];
            }

            if (i ++ >= traceSize) {
                static if (useTree) {
                    if (!traceExists) {
                        break;
                    }
                } else {
                    break;
                }
            }


        }

        ret ~= tr;

        static if (useTree) {
            if (treeLen >= sampleSize) {
                break;
            }
        } else {
            if (++n >= sampleSize) {
                break;
            }
        }
    }

    writeln; writeln(visited);

    static if (false) {
        writeln; foreach (k, v; taken) { 
            write(k, " "); 
            auto vs = v.byPair.array.sort!"a[1] < b[1]";
            
            '['.write;
            foreach (k1, v1; vs) {
                write(" (", k1, " : ", v1, "), ");
            }
            ']'.write;

            writeln;
        }
    }
        

    return ret;
}



class TreeNode(Tin, Tout) {

    ulong id;

    Tin value;

    uint rootDist = 0;

    MooreState!(Tin, Tout) state;

    TreeNode[Tin] children;

    this(ulong id = 0) {
        this.id = id;
    }

    bool addChild(Tin letter) {
        if (letter in children) {
            return false;
        }

        auto child = new typeof(this);

        children[letter] = child;

        return true;
    }

}

