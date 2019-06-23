import sys

sys.dont_write_bytecode = True

import json

import os

genericErrorMessage = '''
An unexpected error has occurred.
This was likely caused by invalid input passed to the tool
(e.g., wrong trace lengths for learn.py, etc.).
Please make sure the input is valid and try again.
If the error persists, send a bug report to the authors,
with sufficient information to reproduce the error.
'''

def wrappedMain(main):
    main()
    return
    try:
        main()
    except KeyboardInterrupt:
        exit(0)
    except SystemExit:
        exit(1)
    except:
        print genericErrorMessage


def sortedAlphabet(alphabet):

    intLetters = []
    floatLetters = []
    stringLetters = []

    for a in alphabet:

        try:
            intLetters.append(int(a))
        except:
            try:
                floatLetters.append(float(a))
            except:
                stringLetters.append(a)

    ret = []
    ret.extend(map(str, sorted(intLetters)))
    ret.extend(map(str, sorted(floatLetters)))
    ret.extend(sorted(stringLetters))

    return ret



def isConcreteMachine(moore):

    return all([moore.S, moore.O, moore.Q, moore.q0, moore.dDict, moore.gDict])


def getPath(fname):

    return os.path.abspath(fname)


def saveMooreSample(fname, sample):

    with open(fname, 'w') as fout:

        for (wi, wo) in sample:

            print >> fout, '%s -> %s' % (','.join(wi), ','.join(wo))

def saveMooreSampleAsJson(fname, sample):

    with open(fname, 'w') as fout:

        json.dump([
                {'input-word' : wi, 'output-word' : wo} for (wi, wo) in sample
            ], fout, indent = 2)


def loadMooreSample(fname):

    sample = []

    with open(fname) as fin:
        for line in fin:
            line = line.strip()
            if line:
                parts = line.split(' -> ')
                iword, oword = [p.split(',') for p in parts]

                sample.append([iword, oword])

    return sample


def sampleContainsSample(s1, s2):

    def prefixes(w):
        return tuple(w[:i + 1] for i, _ in enumerate(w))

    def sample2dict(s):

        d = {}

        for wi, wo in s:

            k = wi[0]

            for p in prefixes(wi):

                try:
                    d[k].add(p)
                except:
                    d[k] = {p}

        return d

    d1 = sample2dict(s1)
    #d2 = sample2dict(s2)

    total = 0
    contained = 0

    for wi, wo in s2:

        total += 1

        try:
            if wi in d1[wi[0]]:
            #if any(any(wi == pfx for pfx in prefixes(wis)) for wis, _ in s1):
                contained += 1

        except:
            pass



    return contained * 1. / total


def sampleContainsCSParts(sample, shpf, kernel, cond2stuff):

    from pprint import pprint

    '''
    print 'sample'
    pprint(sample)

    print 'shpf'
    pprint(shpf)

    print 'kernel'
    pprint(kernel)

    print 'cond2stuff'
    pprint(cond2stuff)
    '''
    assert sampleContainsSample([(e, e) for e in kernel], [(e, e) for e in shpf]) == 1.0
    #assert sampleContainsSample([(e, e) for e in shpf], [(e, e) for e in kernel]) == 1.0

    #raw_input('\nhit enter to continue...')

    def prefixes(w):
        return tuple(w[:i + 1] for i, _ in enumerate(w))

    def sample2dict(s):

        d = {}

        for wi, wo in s:

            k = wi[0]

            for p in prefixes(wi):

                try:
                    d[k].add(p)
                except:
                    d[k] = {p}

        return d

    d = sample2dict(sample)

    ret = []

    for s2 in [shpf, kernel, cond2stuff]:

        total = 0
        contained = 0

        for wi in s2:

            total += 1

            try:
                if wi in d[wi[0]]:
                #if any(any(wi == pfx for pfx in prefixes(wis)) for wis, _ in sample):
                    contained += 1
            except:
                pass

        if len(s2) == 0:
            ret.append(1.0)
        else:
            ret.append(contained * 1. / total)
            
    return ret


def sampleContainsStatesTransitions(sample, moore):

    visitedStates = {moore.q0}
    takenTransitions = set()

    for wi, wo in sample:

        q = moore.q0

        for a in wi:

            takenTransitions.add((q, a))

            q = moore.dDict[(q, a)]

            visitedStates.add(q)

    return [len(visitedStates) * 1. / len(moore.Q), len(takenTransitions) * 1. / len(moore.dDict)]


import ctypes
import threading

class ThreadWithExc(threading.Thread):

    def raiseExc(self, exctype):

        ctid = ctypes.c_long(self.ident)

        res = ctypes.pythonapi.PyThreadState_SetAsyncExc(ctid, ctypes.py_object(exctype))

        if res == 0:
            raise ValueError("invalid thread id")
        elif res != 1:
            ctypes.pythonapi.PyThreadState_SetAsyncExc(ctid, None)
            raise SystemError("PyThreadState_SetAsyncExc failed")

class TimeoutExc(BaseException):
    pass


    
class NotEquivalent(BaseException):
    pass 


def areEquivalent(moore1, moore2):
    
    assert set(moore1.S) == set(moore2.S)
    
    stack = [(moore1.q0, moore2.q0)]
    
    visited = set()

    try:
        
        while stack:
            node = stack.pop()
            visited.add(node)
            
            q1, q2 = node
            
            if moore1.g(q1) != moore2.g(q2):
                #print 'output mismatch'
                #print q1, moore1.g(q1)
                #print q2, moore2.g(q2)
                raise NotEquivalent
            
            for a in moore1.S:
                q1p = moore1.d(q1, a)
                q2p = moore2.d(q2, a)
                
                nodep = (q1p, q2p)
                
                if nodep not in visited:
                    stack.append(nodep)
                    
    except NotEquivalent:
        return False
    
    return True

    
    
def isMinimal(moore):
    
    from copy import deepcopy
    
    m1 = deepcopy(moore)
    m2 = deepcopy(moore)
    
    for q1 in m1.Q:
        for q2 in m2.Q:
            if q1 < q2:
                
                m1.q0 = q1
                m2.q0 = q2
                
                if areEquivalent(m1, m2):
                    return False
                
    return True

    