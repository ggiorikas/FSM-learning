
module mealy_learn;

import std.stdio;
import std.string;
import std.algorithm;
import std.algorithm.iteration : splitter;
import std.conv;
import std.array;
import std.typecons;


import util;

import mealy;


enum Color : byte { red, blue, white }

class PTMState(Tin, Tout) {

    //bool initialized = false;

    //Tout value;

    Tout[] values;
    PTMState[] children;

    PTMState parent;

    Tin parentLetter;

    uint id;

    Color color = Color.white;
}


class PTMStateSet(Tin, Tout) {

    import std.container.rbtree;

    Color color = Color.white;

    RedBlackTree!(PTMState!(Tin, Tout), "a.id < b.id") treeSet;

    this(Color c) {
        color = c;
        treeSet = new RedBlackTree!(PTMState!(Tin, Tout), "a.id < b.id");
    }

    void addState(PTMState!(Tin, Tout) state) {

        //writefln!"adding %d to %d"(state.id, color);

        assert(state.color == Color.white, "addState");

        state.color = color;

        treeSet.insert(state);
    }

    void removeState(PTMState!(Tin, Tout) state) {

        //writefln!"removing %d from %d"(state.id, color);

        assert(state.color == color, "removeState");

        state.color = Color.white;

        treeSet.removeKey(state);
    }

    bool hasState(PTMState!(Tin, Tout) state) {
        return state.color == color;
    }

    PTMState!(Tin, Tout) frontState() {
        return treeSet.front;
    }

    bool empty() {
        return treeSet.empty;
    }

}




class PTM(Tin, Tout) {


    PTMState!(Tin, Tout) init;

    PTMStateSet!(Tin, Tout)  redSet;
    PTMStateSet!(Tin, Tout) blueSet;

    //bool[Tin] alphaIn;
    //bool[Tout] alphaOut;

    Tin alphaInMax;
    Tout alphaOutMax;


    void swap(PTMState!(Tin, Tout) p, PTMState!(Tin, Tout) q) {

        auto pCol = p.color;
        auto qCol = q.color;

        setColor(p, Color.white);
        setColor(q, Color.white);

        // TODO: how does this affect red and blue sets?
        auto temp = p.id;
        p.id = q.id;
        q.id = temp;

        setColor(p, pCol);
        setColor(q, qCol);
    }


    struct UndoList {

        enum sizeMax = 50;

        Command[sizeMax] first;
        Command[] rest;

        uint size = 0;

        
        ref UndoList opOpAssign(string op)(Command cmd) if (op == "~") {
            
            if (size < sizeMax) {
                first[size] = cmd;
            } else {
                rest ~= cmd;
            }

            ++size;

            return this;
        }
    }



    class Command {

        void invoke() { }

    }

    class ColorCommand : Command {

        PTMState!(Tin, Tout) state;
        Color color;

        this(PTMState!(Tin, Tout) s, Color c) {
            color = c;
            state = s;
        }

        override void invoke() {
            setColor(state, color);
        }
    }

    class SwapCommand : Command {

        PTMState!(Tin, Tout) p;
        PTMState!(Tin, Tout) q;

        this(PTMState!(Tin, Tout) p_, PTMState!(Tin, Tout) q_) {
            p = p_;
            q = q_;
        }

        override void invoke() {
            swap(p, q);
        }
    }

    class DelChildCommand : Command {

        PTMState!(Tin, Tout) parent;
        Tin letter;

        this(PTMState!(Tin, Tout) p, Tin a) {
            parent = p;
            letter = a;
        }

        override void invoke() {
            //parent.children.remove(letter);
            parent.children[letter] = null;
        }
    }

    class SetChildCommand : Command {

        PTMState!(Tin, Tout) parent;
        Tin letter;
        PTMState!(Tin, Tout) child;

        this(PTMState!(Tin, Tout) p, Tin a, PTMState!(Tin, Tout) c) {
            parent = p;
            letter = a;
            child = c;
        }

        override void invoke() {
            parent.children[letter] = child;
        }
    }

    class SetParentCommand : Command {

        PTMState!(Tin, Tout) child;
        PTMState!(Tin, Tout) parent;

        this(PTMState!(Tin, Tout) c, PTMState!(Tin, Tout) p) {
            child = c;
            parent = p;
        }

        override void invoke() {
            child.parent = parent;
        }
    }

    class DelOutputCommand : Command {

        PTMState!(Tin, Tout) state;
        Tin letter;

        this(typeof(state) s, Tin a) {
            state = s;
            letter = a;
        }

        override void invoke() {
            //state.values.remove(letter);
            state.values[letter] = cast(Tout) -1;
        }
    }
    

    this() {

        init = new PTMState!(Tin, Tout);

         redSet = new PTMStateSet!(Tin, Tout)(Color.red);
        blueSet = new PTMStateSet!(Tin, Tout)(Color.blue);

    }

    void setAlphas(bool[Tin] ain, bool[Tout] aout) {

        //alphaIn = ain;
        //alphaOut = aout;

        alphaInMax = cast(Tin) ain.length;
        alphaOutMax = cast(Tout) aout.length;

        //writeln("inputs: ", alphaInMax, ", outputs: ", alphaOutMax);

        init.children.length = alphaInMax;
        init.values.length = alphaInMax;
        init.values[] = cast(Tout)-1;

        //writeln(init.children);
        //writeln(init.values);
    }


    void setColor(PTMState!(Tin, Tout) state, Color color) {

        if (state.color == color) return;

        if (state.color == Color.red) {
            redSet.removeState(state);
        } else if (state.color == Color.blue) {
            blueSet.removeState(state);
        }

        if (color == Color.red) {
            redSet.addState(state);
        } else if (color == Color.blue) {
            blueSet.addState(state);
        }
    }

    void addTrace(const ref Trace!(Tin, Tout) trace) {

        auto state = init;

        //state.value = trace.output[0];

        foreach (i, a; trace.input) {



            auto child = state.children[a];

            if (child is null) {
                child = new PTMState!(Tin, Tout);
                child.children.length = alphaInMax;
                child.values.length = alphaInMax;
                child.values[] = cast(Tout)-1;
                state.children[a] = child;
            }

            //auto child = state.children[a];

            child.parent = state;

            child.parentLetter = a;

            //child.value = trace.output[i + 1];

            state.values[a] = trace.output[i];

            state = child;
        }
    }

    void assignIds() {


        // do a bfs visiting children in lex order

        import std.container;

        auto queue = DList!(PTMState!(Tin, Tout))(init);

        uint nextId = 0;

        while (!queue.empty) {

            auto state = queue.front;

            state.id = nextId ++;


            foreach (Tin a; 0 .. alphaInMax) {
                if (auto c = state.children[a])
                //if (c !is null)
                    queue.insertBack(c);
            }

            queue.removeFront;

        }

        writeln("total nodes: ", nextId);

    }




    bool merge(PTMState!(Tin, Tout) r, PTMState!(Tin, Tout) b) {

        // merge blue state b into red state r

        //writefln!"merging %d and %d"(r.id, b.id);

        assert(redSet.hasState(r), "redSet");
        assert(blueSet.hasState(b), "blueSet");


        foreach (Tin a; 0 .. alphaInMax) {
            auto v1 = r.values[a];
            if (v1 != cast(Tout)-1) {
                auto v2 = b.values[a];
                if (v2 != cast(Tout)-1 && v1 != v2) 
                    return false;
            }
        }



        version(custom_undo) {
            UndoList undoList;
        } else {
            Command[] undoList;    
        }



        undoList ~= new ColorCommand(b, Color.blue);


        blueSet.removeState(b);



        auto bp = b.parent;
        auto bpa = b.parentLetter;

        if (bp.children[bpa] !is null) { // i think this is always true...


            undoList ~= new SetChildCommand(bp, bpa, bp.children[bpa]);


        } else {

            undoList ~= new DelChildCommand(bp, bpa);

        }

        bp.children[bpa] = r;




        bool fold(PTMState!(Tin, Tout) p, PTMState!(Tin, Tout) q) {

            //writefln!"folding %d %d"(p.id, q.id);

            if (p.id == q.id || p == q) return true;


            foreach (Tin a; 0 .. alphaInMax) {
                auto v1 = p.values[a];
                if (v1 != cast(Tout)-1) {
                    auto v2 = q.values[a];
                    if (v2 != cast(Tout)-1 && v1 != v2) 
                        return false;
                }
            }

            //assert(p.value == q.value, "merging incompatible states");
            

            //swap ids
            if (q.id < p.id) { // TODO -- try to optimize this somehow

                //writeln("swapping");

                undoList ~= new SwapCommand(p, q);


                swap(p, q);

            } else {

                //writeln("not swapping");
            }



            if (p.color == Color.white && q.color == Color.blue) {


                undoList ~= new ColorCommand(p, Color.white);


                blueSet.addState(p);
            }

            if (p.color == Color.white && q.color == Color.red) {


                undoList ~= new ColorCommand(p, Color.white);


                redSet.addState(p);
            }

            foreach (Tin a; 0 .. alphaInMax) {

                //writefln!"state %d letter %d"(q.id, a);



                auto qc = q.children[a];
                if (qc is null) continue;


                auto pc = p.children[a];
                if (pc !is null) {


                    if (!fold(pc, qc)) {
                        return false;
                    }


                } else {

                    // update children
                    undoList ~= new DelChildCommand(p, a);
                    p.children[a] = qc;

                    undoList ~= new SetParentCommand(qc, q);
                    qc.parent = p;

                    undoList ~= new SetChildCommand(q, a, qc);               
                    q.children[a] = null;


                    // update outputs
                    undoList ~= new DelOutputCommand(p, a);
                    p.values[a] = q.values[a];

                }

            }

            return true;
        }

        if (!fold(r, b)) {


            version(custom_undo) {

                foreach_reverse (cmd; undoList.rest) {
                    cmd.invoke;
                }

                for (int i = undoList.size - 1; i >= 0; -- i) {
                    undoList.first[i].invoke;
                }

            } else {

                foreach_reverse (cmd; undoList) {
                    cmd.invoke;
                }

            }


            return false;
        }

        return true;
    }


    void doMergePhase() {

        bool[uint] examined;

        redSet.addState(init);

        //foreach (c; init.children.byValue) {
        foreach (c; init.children) {
            if (c !is null)
                blueSet.addState(c);
        }

        //writefln!"red size: %d"(redSet.treeSet.length);
        //writefln!"blue size: %d"(blueSet.treeSet.length);

        //writeln("starting merge phase...");


        while (!blueSet.empty) {

            
            
            auto b = blueSet.frontState;


            
            typeof(b) mergeTarget = null;

            foreach (r; redSet.treeSet.dup) { 

                if (merge(r, b)) {
                    mergeTarget = r;
                    break;
                }

            }

            if (mergeTarget is null) {

                // promote blue to red

                //writefln!"promoting %d from blue to red"(b.id);

                blueSet.removeState(b);
                redSet.addState(b);

                foreach (c; b.children) {
                    
                    if (c !is null)
                        blueSet.addState(c);

                }

            } else {


                foreach (r; redSet.treeSet) {
                    //foreach (c; r.children.byValue) {
                    foreach (c; r.children) {
                        if (c !is null && c.color == Color.white) {
                            blueSet.addState(c);
                        }
                    }
                }


            }


        }

    }

    auto toMealy(bool colorCheck = true)(bool[Tin] alphaIn, bool[Tout] alphaOut) {

        auto ret = new Mealy!(Tin, Tout);


        // do a reachability analysis to identify the states

        bool[uint] visited;

        auto mlInit = new MealyState!(Tin, Tout);

        uint[uint] ptmId2mealyId;

        uint mlId = 0;

        void dfs(typeof(init) ptmState, typeof(mlInit) mlState) {

            static if (colorCheck) {
                if (ptmState.color != Color.red) {
                    writefln!"%d colored reachable state %d..."(ptmState.color, ptmState.id);
                }

                assert(ptmState.color == Color.red, "non-red reachable state...");
            }

            //if (ptmState.id in visited) return;

            visited[ptmState.id] = true;

            //auto mlState = new MealyState!(Tin, Tout);

            ptmId2mealyId[ptmState.id] = mlId;

            mlState.id = mlId ++;

            //mlState.value = ptmState.value;

            ret.states[mlState.id] = mlState;

            //foreach (a; ptmState.children.byKey) {
            foreach (Tin a; 0 .. alphaInMax) {

                auto ptms = ptmState.children[a];

                if (ptms is null) continue;

                if (ptms.id in visited) {

                    mlState.children[a] = ret.states[ptmId2mealyId[ptms.id]];

                } else {
                    auto mls = new MealyState!(Tin, Tout);

                    mlState.children[a] = mls;

                    dfs(ptms, mls);
                }

                mlState.values[a] = ptmState.values[a];
            }
        }


        dfs(init, mlInit);

        ret.init = mlInit;
        ret.alphaIn = alphaIn;
        ret.alphaOut = alphaOut;

        return ret;

    }

}


Mealy!(Tin, Tout) algorithm1(Tin, Tout = Tin)(Trace!(string)[] strSample,
                                              bool[string] strAlphaIn,
                                              bool[string] strAlphaOut) {

    writeln("learning with algorithm1...");

    auto alphaMap = alphabets2strNumMappings(strAlphaIn, strAlphaOut);

    auto sample = strSample2numSample(strSample, alphaMap);

    auto alphas = strAlpha2numAlpha(strAlphaIn, strAlphaOut, alphaMap);

    auto alphaIn  = alphas[0];
    auto alphaOut = alphas[1];

    auto ptm = sample2PTM(sample);

    auto mealy = ptm.toMealy!false(alphaIn, alphaOut);

    mealy.makeComplete();

    mealy.strAlphaMap = alphaMap.inverted;

    return mealy;
}


Mealy!(Tin, Tout) algorithm2(Tin, Tout = Tin)(Trace!(string)[] strSample,
                                              bool[string] strAlphaIn,
                                              bool[string] strAlphaOut) {

    writeln("learning with algorithm2...");

    auto alphaMap = alphabets2strNumMappings(strAlphaIn, strAlphaOut);

    auto sample = strSample2numSample(strSample, alphaMap);

    auto alphas = strAlpha2numAlpha(strAlphaIn, strAlphaOut, alphaMap);

    auto alphaIn  = alphas[0];
    auto alphaOut = alphas[1];



    import std.math;

    // decide how many PTMs you need

    uint ptmCount = (ceil(log2(alphaOut.length + 1)) + 0.1).to!uint;

    if (ptmCount < 1) ptmCount = 1;


    PTM!(Tin, Tout)[] ptms;

    ptms.length = ptmCount;


    void adjustOutputs(PTM!(Tin, Tout) ptm, uint bitPos) {

        bool[uint] visited;

        void dfs(typeof(ptm.init) node) {

            if (node.id in visited) return;

            visited[node.id] = true;

            //node.value = (node.value >> bitPos) & 1u;
            foreach (a, v; node.values) {
                node[a] = (v >> bitPos) & 1u;
            }


            foreach (c; node.children.byValue) {
                dfs(c);
            }

        }

        dfs(ptm.init);

    }


    foreach (uint i, ref ptm; ptms) {

        ptm = sample2PTM(sample);

        adjustOutputs(ptm, i);

        ptm.doMergePhase();
    }


    // now, take the product, turn it into a Mealy machine, complete it and return it.

    auto product2Mealy() {

        auto ret = new Mealy!(Tin, Tout);


        // do a reachability analysis to identify the states

        bool[ArrayKey!uint] visited; // this needs to be a tuple of ptmCount ids

        PTMState!(Tin, Tout)[] inits;

        foreach (ptm; ptms) {
            inits ~= ptm.init;
        }

        auto mlInit = new MealyState!(Tin, Tout);

        uint[ArrayKey!uint] arrayId2mealyId;

        auto mlId = 0;

        void dfs(typeof(inits) ptmStates, typeof(mlInit) mlState) {

            foreach (ptmState; ptmStates) {
                if (ptmState.color != Color.red) {
                    writefln!"%d colored reachable state %d..."(ptmState.color, ptmState.id);
                }

                assert(ptmState.color == Color.red, "non-red reachable state...");
            }

            auto id = ArrayKey!uint(ptmStates.map!"a.id".array);

            //if (ptmState.id in visited) return;

            visited[id] = true;

            //auto mlState = new MealyState!(Tin, Tout);

            arrayId2mealyId[id] = mlId;

            mlState.id = mlId ++;


            foreach (a; alphaIn.byKey) {

                mlState.values[a] = 0;

                foreach (i, ptmState; ptmStates) {
                    if (a in ptmState.values) {
                        mlState.values[a] |= (ptmState.values[a] << i);
                    }
                }

                if (mlState.values[a] >= alphaOut.length) {
                    mlState.values[a] = 0;
                }
            }


            ret.states[mlState.id] = mlState;

            typeof(ptmStates) nextPtmStates;
            nextPtmStates.length = ptmCount;


            outer:
            foreach (a; alphaIn.byKey) {

                foreach (i, ptmState; ptmStates) {
                    if (a !in ptmState.children) {
                        continue outer;
                    } else {
                        nextPtmStates[i] = ptmState.children[a];
                    }
                }

                auto nextId = ArrayKey!uint(nextPtmStates.map!"a.id".array);

                //auto ptms = ptmState.children[a];

                if (nextId in visited) {

                    mlState.children[a] = ret.states[arrayId2mealyId[nextId]];

                } else {
                    auto mls = new MealyState!(Tin, Tout);

                    mlState.children[a] = mls;

                    dfs(nextPtmStates, mls);
                }

            }


        }


        dfs(inits, mlInit);

        ret.init = mlInit;
        ret.alphaIn = alphaIn;
        ret.alphaOut = alphaOut;

        return ret;

    }


    auto mealy = product2Mealy();

    mealy.makeComplete();

    mealy.strAlphaMap = alphaMap.inverted;

    return mealy;
}

/*
Mealy!(Tin, Tout) algorithm3(Tin, Tout = Tin)(Trace!(string)[] strSample,
                                              bool[string] strAlphaIn,
                                              bool[string] strAlphaOut) {
//*/

//*
Mealy!(Tin, Tout) algorithm3(Tin, Tout = Tin)(Trace!(string)[] sampleStr,
                                              bool[string] alphaInStr,
                                              bool[string] alphaOutStr) {
//*/
    writeln("learning with algorithm3..."); stdout.flush;

    auto alphaMap = alphabets2strNumMappings!(Tin, Tout)(alphaInStr, alphaOutStr);

    auto sample = strSample2numSample(sampleStr, alphaMap);

    auto alphas = strAlpha2numAlpha(alphaInStr, alphaOutStr, alphaMap);

    auto alphaIn  = alphas[0];
    auto alphaOut = alphas[1];

    writeln("building prefix tree..."); stdout.flush;

    //auto ptm = sample2PTM(sample);


    auto ptm = new PTM!(Tin, Tout);

    ptm.setAlphas(alphaIn, alphaOut);

    foreach (ref t; sample) ptm.addTrace(t);

    ptm.assignIds();


    writeln("beginning merging phase..."); stdout.flush;

    ptm.doMergePhase();

    auto mealy = ptm.toMealy(alphaIn, alphaOut);

    writeln("completing..."); stdout.flush;

    mealy.makeComplete();

    mealy.strAlphaMap = alphaMap.inverted;

    return mealy;
}


auto sample2PTM(Tin, Tout)(const ref Trace!(Tin, Tout)[] sample) {

    auto ptm = new PTM!(Tin, Tout);

    foreach (ref t; sample) ptm.addTrace(t);

    ptm.assignIds();

    return ptm;
}




alias ArrayKey(T) = immutable(T)[];



void main(string[] args) {

    import core.memory: GC;

    import std.datetime.stopwatch: StopWatch;

    //GC.disable;

    assert(args.length >= 3, "wrong arguments!");

    string trainSampleFile = args[1];

    string algo = args[2];

    //test(); return;

    //writeln("hello!");

    //readln;

    writefln!"loading sample..."; stdout.flush;


    StopWatch sw1;
    sw1.start();

    Trace!(string, string)[] sample;

    if (args.length == 4) {

        sample = loadMealySampleFF(trainSampleFile);

    } else {

        sample = loadMealySample!string(trainSampleFile);

    }

    long load_ms = sw1.peek.total!"msecs";

    writefln!"done loading sample in %s s..."(load_ms / 1000.0); stdout.flush;
    //readln;

    writefln!"extracting alphabet..."; stdout.flush;

    auto alphabets = sample2alphabets(sample);

    Mealy!(TraceElem, TraceElem) mealy;



    StopWatch sw;
    sw.start();
    

    //if (algo == "1") mealy = algorithm1!TraceElem(sample, alphabets[0], alphabets[1]);
    //if (algo == "2") mealy = algorithm2!TraceElem(sample, alphabets[0], alphabets[1]);
    if (algo == "3") mealy = algorithm3!TraceElem(sample, alphabets[0], alphabets[1]);

    long exec_ms = sw.peek.total!"msecs";

    writefln!"learned %s states in %s s"(mealy.states.length, exec_ms / 1000.0); stdout.flush;

    {
        File fout = File("learned.json", "w");
        fout.writeln(mealy.toJsonStr);

        //mealy.toJsonStr.writeln;
    }
    stdout.flush;

}

