

import util;
import moore;

import std.typecons;

import std.conv;
import std.stdio;

import std.exception;

alias TestRet = Tuple!(uint, uint);

TestRet strongTest(ref Moore!TraceElem moore, Trace!TraceElem trace) {

    auto correct = true;

    auto q = moore.init;

    foreach (i, a; trace.input) {
        
        if (trace.output[i] != q.value) {
            correct = false;
            break;
        }

        //writeln(q.id, " ", a);
        q = q.children[a]; 
    }

    if (trace.output[$ - 1] != q.value) {
        correct = false;
    }

    return correct ? tuple(1u, 1u) : tuple(0u, 1u);
}



TestRet mediumTest(ref Moore!TraceElem moore, Trace!TraceElem trace) {

    uint correct = 0;

    auto q = moore.init;

    foreach (i, a; trace.input) {
        
        if (trace.output[i] != q.value) {
            break;
        }

        ++correct;

        //writeln(q.id, " ", a);
        q = q.children[a]; 
    }

    if (correct == trace.input.length && 
        trace.output[$ - 1] == q.value) {
        ++correct;
    }

    return tuple(correct, trace.output.length.to!uint);
}


TestRet weakTest(ref Moore!TraceElem moore, Trace!TraceElem trace) {

    uint correct = 0;

    auto q = moore.init;

    foreach (i, a; trace.input) {
        
        if (trace.output[i] == q.value) {
            ++correct;
        }
        
        q = q.children[a]; 
    }

    if (trace.output[$ - 1] == q.value) {
        ++correct;
    }

    return tuple(correct, trace.output.length.to!uint);
}


double computeAccuracy(alias aep)(Moore!TraceElem moore, Trace!TraceElem[] sample) {


    int correctCount = 0;
    int totalCount = 0;

    foreach (trace; sample) {
        
        auto ret = aep(moore, trace);

        correctCount += ret[0];
        totalCount += ret[1];
    }

    return correctCount * 100.0 / totalCount;
}

