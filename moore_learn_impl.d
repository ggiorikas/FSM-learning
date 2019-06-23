
module moore_learn_impl;


import std.stdio;
import std.string;
import std.algorithm;
import std.algorithm.iteration : splitter;
import std.conv;
import std.array;
import std.typecons;

import std.exception;

import core.memory: GC;
import std.datetime.stopwatch: StopWatch;

import std.traits;

import util;
import moore;

enum Color : byte { red, blue, white }

class PTMState(Tin, Tout = Tin) {

    //bool initialized = false;

    Tout value;

    PTMState[Tin] children;

    PTMState parent;

    Tin parentLetter;

    uint id;

    Color color = Color.white;
}


class PTMStateSet(Tin, Tout = Tin) {

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

    bool[Tin] alphaIn;
    bool[Tout] alphaOut;

    StopWatch * psw;
    ulong timeoutLimit;
    ulong stateLimit;


    void checkLimits() {

        //writeln("checking limits..."); 

        if (psw.peek.total!"msecs" > timeoutLimit) {
            throw new TimeoutLimitException("time limit exceeded!");
        }


        //writeln("checked limits..."); 

    }


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

    version (strcmd) {

        enum StructCommandType : ubyte { 
            ColorStructCommand, SwapStructCommand, DelChildStructCommand, SetChildStructCommand, SetParentStructCommand }

        struct StructCommand {

            StructCommandType type;

            PTM ptm;
            
            PTMState!(Tin, Tout) s1;
            PTMState!(Tin, Tout) s2;
            Tin letter;
            Color color;

            void invoke() {

                if (type == StructCommandType.ColorStructCommand) {
                    ptm.setColor(s1, color);
                } else if (type == StructCommandType.SwapStructCommand) {
                    ptm.swap(s1, s2);
                } else if (type == StructCommandType.DelChildStructCommand) {
                    s1.children.remove(letter);
                } else if (type == StructCommandType.SetChildStructCommand) {
                    s1.children[letter] = s2;
                } else if (type == StructCommandType.SetParentStructCommand) {
                    s1.parent = s2;
                }
            }

        }

    } else {

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
                parent.children.remove(letter);
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
    }



    this() {

        init = new PTMState!(Tin, Tout);

         redSet = new PTMStateSet!(Tin, Tout)(Color.red);
        blueSet = new PTMStateSet!(Tin, Tout)(Color.blue);

    }

    void setAlphas(typeof(alphaIn) ain, typeof(alphaOut) aout) {

        alphaIn = ain;
        alphaOut = aout;
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

        state.value = trace.output[0];

        foreach (i, a; trace.input) {

            if (a !in state.children) {
                state.children[a] = new PTMState!(Tin, Tout);
            }

            auto child = state.children[a];

            child.parent = state;

            child.parentLetter = a;

            child.value = trace.output[i + 1];

            state = child;
        }
    }

    void assignIds() {


        // do a bfs visiting children in lex order

        import std.container;

        auto queue = DList!(PTMState!(Tin, Tout))(init);

        uint nextId = 0;

        auto sortedAlphaIn = alphaIn.keys.sort;

        while (!queue.empty) {

            auto state = queue.front;

            state.id = nextId ++;

            auto letters = state.children.keys;
            letters.sort;
            foreach (a; letters) queue.insertBack(state.children[a]);

            //foreach (a; sortedAlphaIn) if (auto psa = a in state.children) queue.insertBack(*psa);

            queue.removeFront;

        }

        writeln("total nodes: ", nextId);

    }



    bool merge(PTMState!(Tin, Tout) r, PTMState!(Tin, Tout) b) {

        // merge blue state b into red state r

        //writefln!"merging %d and %d"(r.id, b.id);

        assert(redSet.hasState(r), "redSet");
        assert(blueSet.hasState(b), "blueSet");

        if (r.value != b.value) return false;


        version (strcmd) {
            StructCommand[] undoList;
        } else {
            Command[] undoList;
        }


        version (strcmd) {
            undoList ~= StructCommand(StructCommandType.ColorStructCommand, this, b, null, 0, Color.blue);
        } else {
            undoList ~= new ColorCommand(b, Color.blue);
        }
        

        blueSet.removeState(b);



        auto bp = b.parent;
        auto bpa = b.parentLetter;

        if (bpa in bp.children) { // i think this is always true...

            version (strcmd) {
                undoList ~= StructCommand(StructCommandType.SetChildStructCommand, this, bp, bp.children[bpa], bpa);
            } else {
                undoList ~= new SetChildCommand(bp, bpa, bp.children[bpa]);
            }
            

        } else {

            version (strcmd) {
                undoList ~= StructCommand(StructCommandType.DelChildStructCommand, this, bp, null, bpa);
            } else {
                undoList ~= new DelChildCommand(bp, bpa);
            }            

        }

        bp.children[bpa] = r;



        bool fold(PTMState!(Tin, Tout) p, PTMState!(Tin, Tout) q) {

            //writefln!"folding %d %d"(p.id, q.id);

            if (p.id == q.id || p == q) return true;

            if (p.value != q.value) {
                //writefln!"merging %d and %d"(p.id, q.id);

                return false;
            }

            assert(p.value == q.value, "merging incompatible states");

            //swap ids
            if (q.id < p.id) {

                //writeln("swapping");

                version (strcmd) {
                    undoList ~= StructCommand(StructCommandType.SwapStructCommand, this, p, q);
                } else {
                    undoList ~= new SwapCommand(p, q);
                }

                swap(p, q);

            } else {

                //writeln("not swapping");
            }



            if (p.color == Color.white && q.color == Color.blue) {

                version (strcmd) {
                    undoList ~= StructCommand(StructCommandType.ColorStructCommand, this, p, null, 0, Color.white);
                } else {
                    undoList ~= new ColorCommand(p, Color.white);
                }

                blueSet.addState(p);
            }

            if (p.color == Color.white && q.color == Color.red) {

                version (strcmd) {
                    undoList ~= StructCommand(StructCommandType.ColorStructCommand, this, p, null, 0, Color.white);
                } else {
                    undoList ~= new ColorCommand(p, Color.white);
                }

                redSet.addState(p);
            }

            foreach (a; alphaIn.byKey) {

                //writefln!"state %d letter %d"(q.id, a);

                //auto qc = q.children[a];
                auto pqc = a in q.children;
                if (pqc is null) continue;
                auto qc = *pqc;

                if (a in p.children) {

                    auto pc = p.children[a];

                    if (!fold(pc, qc)) {
                        return false;
                    }


                } else {

                    version (strcmd) {
                        undoList ~= StructCommand(StructCommandType.DelChildStructCommand, this, p, null, a);
                    } else {
                        undoList ~= new DelChildCommand(p, a);
                    }

                    p.children[a] = qc;



                    version (strcmd) {
                        undoList ~= StructCommand(StructCommandType.SetParentStructCommand, this, qc, q);
                    } else {
                        undoList ~= new SetParentCommand(qc, q);
                    }
                    
                    qc.parent = p;



                    version (strcmd) {
                        undoList ~= StructCommand(StructCommandType.SetChildStructCommand, this, q, qc, a);
                    } else {
                        undoList ~= new SetChildCommand(q, a, qc);
                    }                    

                    //q.children[a] = null;

                    q.children.remove(a);

                }

            }


            return true;
        }

        if (!fold(r, b)) {

            foreach_reverse (cmd; undoList) {
                cmd.invoke;
            }

            return false;
        }

        return true;
    }


    void doMergePhase() {


        bool[uint] examined;

        redSet.addState(init);

        foreach (c; init.children.byValue) {
            blueSet.addState(c);
        }


        int steps = 0;

        while (!blueSet.empty) {

            //import core.memory: GC;

            //GC.collect;

            if (++steps % 100 == 0) {
                checkLimits();
            }

            auto b = blueSet.frontState;

            examined[b.id] = true;

            //writefln!"picked %d from blue"(b.id);

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

                foreach (c; b.children.byValue) {

                    if (c.id !in examined && !redSet.hasState(c))
                        blueSet.addState(c);

                }

            } else {

                foreach (r; redSet.treeSet) {
                    foreach (c; r.children.byValue) {
                        if (c.color == Color.white) {
                            blueSet.addState(c);
                        }
                    }
                }


            }


        }

    }

    auto toMoore(bool colorCheck = false)() {

        auto ret = new Moore!(Tin, Tout);


        // do a reachability analysis to identify the states

        bool[uint] visited;

        auto mrInit = new MooreState!(Tin, Tout);

        uint[uint] ptmId2mooreId;

        MooreState!(Tin, Tout)[uint] ptmId2moore;

        uint mrId = 0;


        void dfsIt(typeof(init) ptmStateInit, typeof(mrInit) mrStateInit) {

            import std.container.array: Array;

            enum useBuiltInArray = false;

            static if (useBuiltInArray) {
                typeof(init)[] ptmStack;                
                typeof(mrInit)[] mrStack;
                //uint stackSize = 0;
            } else {
                Array!(typeof(init)) ptmStack;
                Array!(typeof(mrInit)) mrStack;
            }

            ptmStack ~= ptmStateInit;
            mrStack ~= mrStateInit;

            static if (useBuiltInArray) {
                //++stackSize;
            }

            ulong counter = 0;

            while (!ptmStack.empty) {

                if (++counter % 10000 == 0) {
                    checkLimits();
                    //writeln("checking limits inside toMoore...");
                }

                static if (useBuiltInArray) {
                    //auto ptmState = ptmStack[stackSize - 1];
                    //auto mrState = mrStack[stackSize - 1];

                    auto ptmState = ptmStack[$ - 1];
                    auto mrState = mrStack[$ - 1];

                    ptmStack.popBack;
                    mrStack.popBack;

                    ptmStack.assumeSafeAppend;
                    mrStack.assumeSafeAppend;

                    //--stackSize;

                } else  {

                    auto ptmState = ptmStack.back;
                    auto mrState = mrStack.back;

                    ptmStack.removeBack;
                    mrStack.removeBack;
                }


                static if (colorCheck) {
                    if (ptmState.color != Color.red) {
                        writefln!"%d colored reachable state %d..."(ptmState.color, ptmState.id);
                    }

                    assert(ptmState.color == Color.red, "non-red reachable state...");
                }

                //writeln("visiting ", ptmState.id);

                if (ptmState.id in visited) {

                    //writeln("skipping..."); continue;

                    //auto mrId1 = ptmId2mooreId[ptmState.id];
                    //auto mrState1 = ret.states[mrId1];

                    foreach (a; ptmState.children.byKey) {

                        auto ptms = ptmState.children[a];

                        if (ptms.id in visited) {

                            mrState.children[a] = ret.states[ptmId2mooreId[ptms.id]];

                        }
                    }

                    continue;
                }

                visited[ptmState.id] = true;

                //auto mrState = new MooreState!(Tin, Tout);
                
                ptmId2mooreId[ptmState.id] = mrId;

                ptmId2moore[ptmState.id] = mrState;

                mrState.id = mrId ++;

                mrState.value = ptmState.value;

                ret.states[mrState.id] = mrState;

                //typeof(ptmStateInit)[] newPtmStates;
                //typeof(mrStateInit)[] newMrStates;

                foreach (a; ptmState.children.byKey) {

                    auto ptms = ptmState.children[a];

                    if (ptms.id in visited) {

                        //writeln("adjusting child ", a, " of ", mrState.id);
                        mrState.children[a] = ret.states[ptmId2mooreId[ptms.id]];

                    } else {

                        MooreState!(Tin, Tout) mrs;

                        if (ptms.id in ptmId2moore) {
                            //writeln("reusing child ", a, " for ", mrState.id);
                            mrs = ptmId2moore[ptms.id];
                        } else {
                            //writeln("creating child ", a, " for ", mrState.id);
                            mrs = new typeof(mrs);
                            ptmId2moore[ptms.id] = mrs;
                        }
                        
                        mrState.children[a] = mrs;

                        //dfs(ptms, mrs);


                        static if (useBuiltInArray) {

                            //if (ptmStack.length == stackSize) {
                            if (true) {

                                newPtmStates ~= ptms;
                                newMrStates ~= mrs;

                            } else {
                                //ptmStack[stackSize] = ptms;
                                //mrStack[stackSize] = mrs;

                                newPtmStates ~= ptms;
                                newMrStates ~= mrs;

                            }

                            //++stackSize;
                            
                        } else {
                            //newPtmStates ~= ptms;
                            //newMrStates ~= mrs;

                            ptmStack ~= ptms;
                            mrStack  ~= mrs;

                        }

                        
                    }
                }

                //foreach_reverse (q; newPtmStates) { ptmStack ~= q; }
                //foreach_reverse (q; newMrStates ) { mrStack  ~= q; }

            }
        }


        dfsIt(init, mrInit);

        ret.init = mrInit;
        ret.alphaIn = alphaIn;
        ret.alphaOut = alphaOut;

        //writeln(ptmId2mooreId);

        //ret.show;

        return ret;

    }

}


Moore!(Tin, Tout) algorithm1(Tin, Tout = Tin)(Trace!(string)[] sampleStr,
                                              Moore!(Tin, Tout) iface,
                                              double timeoutLimitSeconds,
                                              int stateLimit) {

    writeln("learning with algorithm1...");

    auto sample = strSample2numSample(sampleStr, iface.s2bAlphaMap);

    StopWatch sw;
    sw.start();

    //auto ptm = sample2PTM(sample);

    auto ptm = new PTM!(Tin, Tout);

    ptm.psw = &sw;
    ptm.timeoutLimit = (timeoutLimitSeconds * 1000).to!ulong;
    ptm.stateLimit = stateLimit;//stateLimit.to!ulong * 1024 * 1024;

    ptm.setAlphas(iface.alphaIn, iface.alphaOut);

    ulong traceCount = 0;

    foreach (ref t; sample) {
        ptm.addTrace(t);

        if (++traceCount % 10000 == 0) {
            ptm.checkLimits();
        }
    }

    ptm.assignIds();

    auto moore = ptm.toMoore();

    moore.makeComplete();

    moore.s2bAlphaMap = iface.s2bAlphaMap;
    moore.b2sAlphaMap = iface.b2sAlphaMap;

    return moore;
}


Moore!(Tin, Tout) algorithm2(Tin, Tout = Tin)(Trace!(string)[] sampleStr,
                                              Moore!(Tin, Tout) iface,
                                              double timeoutLimitSeconds,
                                              int stateLimit) {

    writeln("learning with algorithm2...");

    auto sample = strSample2numSample(sampleStr, iface.s2bAlphaMap);


    import std.math;

    // decide how many PTMs you need

    uint ptmCount = (ceil(log2(iface.alphaOut.length + 1)) + 0.1).to!uint;

    if (ptmCount < 1) ptmCount = 1;


    void adjustOutputs(PTM!(Tin, Tout) ptm, uint bitPos) {

        bool[uint] visited;

        void dfs(typeof(ptm.init) node) {

            if (node.id in visited) return;

            visited[node.id] = true;

            node.value = (node.value >> bitPos) & 1u;

            foreach (c; node.children.byValue) {
                dfs(c);
            }

        }

        dfs(ptm.init);

    }


    PTM!(Tin, Tout)[] ptms;

    ptms.length = ptmCount;


    StopWatch sw;
    sw.start();

    foreach (i, ref ptm; ptms) {

        ptm = new PTM!(Tin, Tout);

        writeln("building prefix tree ", i + 1, "..."); stdout.flush;

        ptm.psw = &sw;
        ptm.timeoutLimit = (timeoutLimitSeconds * 1000).to!ulong;
        ptm.stateLimit = stateLimit; //stateLimit.to!ulong * 1024 * 1024;

        writeln("building prefix tree ", i + 1, "..."); stdout.flush;

        ptm.setAlphas(iface.alphaIn, iface.alphaOut);

        ulong traceCount = 0;

        foreach (ref t; sample) {
            ptm.addTrace(t);

            if (++traceCount % 10000 == 0) {
                ptm.checkLimits();
            }
        }

        ptm.assignIds();

        adjustOutputs(ptm, cast(uint) i);

        writeln("beginning merging phase ", i + 1, "..."); stdout.flush;

        ptm.doMergePhase();
    }




    // now, take the product, turn it into a Moore machine, complete it and return it.

    auto product2Moore() {

        auto ret = new Moore!(Tin, Tout);


        // do a reachability analysis to identify the states

        bool[ArrayKey!uint] visited; // this needs to be a tuple of ptmCount ids

        PTMState!(Tin, Tout)[] inits;

        foreach (ptm; ptms) {
            inits ~= ptm.init;
        }

        auto mrInit = new MooreState!(Tin, Tout);

        uint[ArrayKey!uint] arrayId2mooreId;

        MooreState!(Tin, Tout)[ArrayKey!uint] arrayId2moore;

        auto mrId = 0;

        ulong counter = 0;



        void dfsIt(typeof(inits) ptmStatesInit, typeof(mrInit) mrStateInit) {

            import std.container.array: Array;

            const useLibArray = true;

            static if (useLibArray) {
                Array!(typeof(inits)) ptmStack;
                Array!(typeof(mrInit)) mrStack;
            } else {
                typeof(inits)[] ptmStack;
                typeof(mrInit)[] mrStack;
            }

            ptmStack ~= ptmStatesInit;
            mrStack ~= mrStateInit;

            ulong counter = 0;

            while (!ptmStack.empty) {

                static if (false) {
                    writeln("\nptmStack");
                    foreach (e; ptmStack) {
                        writeln("    ", e.map!"a.id".array);
                    }
                    writeln;
                }


                auto ptmStates = ptmStack.back;
                auto mrState = mrStack.back;


                static if (useLibArray) {
                    ptmStack.removeBack;
                    mrStack.removeBack;
                } else {
                    ptmStack.popBack;
                    mrStack.popBack;
                }


                if (++counter % 50000 == 0) {
                    ptms[0].checkLimits();
                    //writeln("checking limits inside product...");

                    writefln!"reached %s states..."(mrId+1); stdout.flush;

                    if (mrId > ptms[0].stateLimit) {
                        throw new MemoryLimitException("memory limit exceeded!");
                    }
                }

                static if (false) {

                    foreach (ptmState; ptmStates) {
                        if (ptmState.color != Color.red) {
                            writefln!"%d colored reachable state %d..."(ptmState.color, ptmState.id);
                        }

                        assert(ptmState.color == Color.red, "non-red reachable state...");
                    }   
                }

                //auto id = ArrayKey!uint(ptmStates.map!"a.id".array);

                ArrayKey!uint id = assumeUnique(ptmStates.map!"a.id".array);

                //writeln(id);

                if (id in visited) continue;

                visited[id] = true;

                //auto mrState = new MooreState!(Tin, Tout);

                arrayId2mooreId[id] = mrId;

                arrayId2moore[id] = mrState;

                mrState.id = mrId ++;

                mrState.value = 0;

                foreach (i, ptmState; ptmStates) {
                    mrState.value |= (ptmState.value << i);
                }

                // NOTE: this fixes invalid codes
                if (mrState.value >= iface.alphaOut.length) {
                    mrState.value = 0;
                }

                ret.states[mrState.id] = mrState;


                //typeof(ptmStates)[] ptmStackNew;
                //typeof(mrState)[] mrStackNew;


                outer:
                foreach (a; iface.alphaIn.byKey) {

                    typeof(ptmStates) nextPtmStates;
                    nextPtmStates.length = ptmCount;

                    foreach (i, ptmState; ptmStates) {
                        if (a !in ptmState.children) {
                            continue outer;
                        } else {
                            nextPtmStates[i] = ptmState.children[a];
                        }
                    }

                    //auto nextId = ArrayKey!uint(nextPtmStates.map!"a.id".array);
                    ArrayKey!uint nextId = assumeUnique(nextPtmStates.map!"a.id".array);

                    //auto ptms = ptmState.children[a];

                    //writeln(nextId, " ", visited.get(nextId, false));

                    if (nextId in visited) {

                        mrState.children[a] = ret.states[arrayId2mooreId[nextId]];

                    } else {

                        MooreState!(Tin, Tout) mrs;

                        if (nextId in arrayId2moore) {
                            mrs = arrayId2moore[nextId];
                        } else {
                            mrs = new typeof(mrs);
                            arrayId2moore[nextId] = mrs;
                        }

                        mrState.children[a] = mrs;

                        
                        //dfs(nextPtmStates, mrs);

                        ptmStack ~= nextPtmStates;
                        mrStack ~= mrs;

                        //ptmStackNew ~= nextPtmStates;
                        //mrStackNew ~= mrs;

                    }

                }

                //foreach_reverse(e; ptmStackNew) { ptmStack ~= e; }
                //foreach_reverse(e; mrStackNew) { mrStack ~= e; }

            }


           


        }



        dfsIt(inits, mrInit);


        ret.init = mrInit;
        ret.alphaIn = iface.alphaIn;
        ret.alphaOut = iface.alphaOut;

        return ret;

    }

    writeln("computing product...");
    stdout.flush;

    auto moore = product2Moore();

    moore.makeComplete();

    moore.s2bAlphaMap = iface.s2bAlphaMap;
    moore.b2sAlphaMap = iface.b2sAlphaMap;

    return moore;
}

/*
Moore!(Tin, Tout) algorithm3(Tin, Tout = Tin)(Trace!(string)[] strSample,
                                              bool[string] strAlphaIn,
                                              bool[string] strAlphaOut) {
//*/

//*
Moore!(Tin, Tout) algorithm3(Tin, Tout = Tin, TrTin, TrTout = TrTin)(
                                              Trace!(TrTin, TrTout)[] sampleStr,
                                              Moore!(Tin, Tout) iface,
                                              double timeoutLimitSeconds,
                                              int stateLimit) {
//*/
    writeln("learning with algorithm3..."); stdout.flush;

    static if (allSameType!(TrTin, TrTout, string)) {
        auto sample = strSample2numSample(sampleStr, iface.s2bAlphaMap);
    } else {
        static assert(allSameType!(Tin, TrTin));
        static assert(allSameType!(Tout, TrTout));
        auto sample = sampleStr;
    }    

    StopWatch sw;
    sw.start();

    writeln("building prefix tree..."); stdout.flush;

    auto ptm = new PTM!(Tin, Tout);

    ptm.psw = &sw;
    ptm.timeoutLimit = (timeoutLimitSeconds * 1000).to!ulong;
    ptm.stateLimit = stateLimit;// stateLimit.to!ulong * 1024 * 1024;

    ptm.setAlphas(iface.alphaIn, iface.alphaOut);

    ulong traceCount = 0;

    foreach (ref t; sample) {
        ptm.addTrace(t);

        if (++traceCount % 10000 == 0) {
            ptm.checkLimits();
        }
    }

    ptm.assignIds();

    //auto ptm = sample2PTM(sample, alphaIn, alphaOut);

    writeln("beginning merging phase..."); stdout.flush;

    ptm.doMergePhase();

    auto moore = ptm.toMoore();

    writeln("learned ", moore.states.length, " states");

    writeln("completing..."); stdout.flush;

    moore.makeComplete();

    moore.s2bAlphaMap = iface.s2bAlphaMap;
    moore.b2sAlphaMap = iface.b2sAlphaMap;

    return moore;
}


auto sample2PTM(Tin, Tout)(const ref Trace!(Tin, Tout)[] sample, bool[Tin] alphaIn, bool[Tout] alphaOut) {

    auto ptm = new PTM!(Tin, Tout);

    ptm.setAlphas(alphaIn, alphaOut);

    foreach (ref t; sample) ptm.addTrace(t);

    ptm.assignIds();

    return ptm;
}




alias ArrayKey(T) = immutable(T)[];



