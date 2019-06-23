
module isotest_impl;

import moore;
import util;

import std.stdio;
import std.container.array: Array;
import std.typecons;

class NotIsomorphicException : Exception {

    this(string msg, string file = __FILE__, size_t line = __LINE__) {
        super(msg, file, line);
    }
}


auto findIsomorphismMappings(Moore!(TraceElem) moore1, Moore!(TraceElem) moore2) {

    //writeln("iostest...");
    //moore1.show;
    //moore2.show;
    //stdout.flush;

    uint[uint] one2two;
    uint[uint] two2one;

    Nullable!(typeof(tuple(one2two, two2one))) ret;


    try {

        if (moore1.states.length != moore2.states.length) {
            throw new NotIsomorphicException("state count mismatch");
        }

        // assume the alphabets are the same

        
        Array!(Tuple!(uint, uint)) stack;

        stack ~= tuple(moore1.init.id, moore2.init.id);

        while (!stack.empty) {
                

            auto node = stack.back;
            stack.removeBack;

            auto q1 = moore1.states[node[0]];
            auto q2 = moore2.states[node[1]];

            if (q1.value != q2.value) {
                throw new NotIsomorphicException("output mismatch");
            }

            if ( 
                (q1.id in one2two && one2two[q1.id] != q2.id) ||
                (q2.id in two2one && two2one[q2.id] != q1.id)
            ) {
                throw new NotIsomorphicException("state mismatch");
            }


            one2two[q1.id] = q2.id;
            two2one[q2.id] = q1.id;

            foreach (a; moore1.alphaIn.byKey) {

                auto q1p = q1.children[a];
                auto q2p = q2.children[a];

                if (q1p.id in one2two && q2p.id in two2one) {

                    if (one2two[q1p.id] != q2p.id || two2one[q2p.id] != q1p.id) {
                        throw new NotIsomorphicException("state mismatch");
                    }

                } else {

                    auto nodep = tuple(q1p.id, q2p.id);
                    stack ~= nodep;
                }            
            }
        }

        ret = tuple(one2two, two2one);

    } catch (NotIsomorphicException e) {
        
        writeln(e.msg);
        ret.nullify;
    }

    
    return ret;
}
