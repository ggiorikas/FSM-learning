import sys

sys.dont_write_bytecode = True

from itertools import product, izip
import math
import cPickle
import gzip
import json
import zlib

class Moore:

    def __init__(self, S, O, Q, q0, dDict, gDict):
        #assert type(Q) is set
        self.S = S
        self.O = O
        self.Q = Q
        self.q0 = q0
        self.q = q0
        self.o = ''
        self.dDict = dDict
        self.gDict = gDict

        lg = math.log(len(O), 2)
        lgi = int(lg)

        self.Onbits = lgi if lgi == lg else lgi + 1

        if self.Onbits < 1: self.Onbits = 1

        self.O2bits = dict(izip(self.O, product([0, 1], repeat = self.Onbits)))
        self.bits2O = {v: k for k, v in self.O2bits.iteritems()}

        self.reset()


    def d(self, q, a):
        return self.dDict.get((q, a))

    def ds(self, q, w):

        ret = q
        for a in w:
            ret = self.d(ret, a)
            #print ret

        return ret

    def g(self, q):
        return self.gDict.get(q)

    def reset(self, q = None):

        q = q or self.q0

        self.q = q
        self.o = self.g(q)

    def step(self, a):

        #print a

        #if a != '' and a != self.e:
        if a and a not in ('.l',):
            self.q = self.d(self.q, a)
            self.o = self.g(self.q)


    def transduce(self, w):

        #print 'transducing', w

        q = self.q0

        ret = [self.g(q)]

        for a in w:
            q = self.d(q, a)
            ret.append(self.g(q))


        return tuple(ret)

    def outputOn(self, w):

        #if w == '.l':
        if w == self.e:
            return self.o

        q = self.q

        self.reset()

        ret = self.o

        for a in w:
            self.step(a)
            ret = self.o

        self.reset(q)

        return ret

    def bitOutputOn(self, w):

        ret = self.outputOn(w)

        return self.O2bits[ret]

    def show(self):

        print '=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-='
        print 'input alphabet:', sorted(self.S)
        print 'output alphabet:', sorted(self.O)
        print '\nstates:', sorted(self.Q)
        print '\ninit:', self.q0

        print '\ntransitions:'
        for s in sorted(self.Q):
            for a in self.S:
                self.reset(s)
                self.step(a)
                print (s, a), '->', self.q

        print '\noutputs:'
        for s in sorted(self.Q):
            self.reset(s)
            print s, '->', self.o
        print '=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-='


    def toGraphStr(self, nidOffset = 0):

        lines = []

        def pq(q):
            if q.startswith('('):
                #print 'tuple!'
                #return '(%s)' % ', '.join(eval(q))
                return '%s' % eval(q)[0].replace("'", '').replace(',)',')')
            return q

        for i, q in enumerate(sorted(self.Q), nidOffset):
            fill = list('999')
            if q == self.q0:
                fill[1] = 'f'
            if fill == list('999'):
                fill = list('fff')

            lines.append( '%s [label="%s" style="fill: #%s"];' % (i, '%s | %s' % (pq(q), self.g(q)), ''.join(fill)) )

        lines.append('\n')

        sQ = sorted(self.Q)
        for i, s in enumerate(sorted(self.Q), nidOffset):
            for a in self.S:
                self.reset(s)
                self.step(a)

                lines.append( '%s -> %s [labelType = "html" label="<div style=\'min-width:20px; min-height:20px; background-color:white; z-index:100; border: 1.5px solid black; text-align: center; border-radius: 10px;\'>%s</div>" lineInterpolate=""]' % (i, sQ.index(self.q) + nidOffset, a) )

            lines.append('\n')

        return '\n'.join(lines)


    def encryptHeader(self, fname):

        GARBAGE_BYTES = map(ord, '!*&@l$"-qw(2V=f-_;pd|{12]~1]7U[Zc<.cv>a,#^0+q`/B')

        with open(fname, 'r+b') as f:

            bs = [ord(c) for c in f.read(len(GARBAGE_BYTES))]

            for i, b in enumerate(bs):
                bs[i] = b ^ GARBAGE_BYTES[i]

            sbs = ''.join(map(chr, bs))

            f.seek(0)
            f.write(sbs)

    def decryptHeader(self, fname):

        self.encryptHeader(fname)



    def saveToFile(self, fname):

        with gzip.open(fname, 'wb') as fout:

            cPickle.dump(self, fout, 2)

        self.encryptHeader(fname)


    def saveAsJson(self, fname):

        with open(fname, 'w') as fout:

            jdDict = {}

            for q in self.Q:

                jdDict[str(q)] = {}

                for a in self.S:
                    jdDict[str(q)][a] = str(self.dDict[(q, a)])

            jgDict = {}

            for q in self.Q:

                jgDict[str(q)] = self.gDict[q]

            json.dump({
                    'input-alphabet' : sorted(self.S),
                    'output-alphabet' : sorted(self.O),
                    'states' : sorted(map(str, self.Q)),
                    'initial-state' : str(self.q0),
                    'output-function' : jgDict,
                    'transition-function' : jdDict,
                }, fout, indent = 2)


    def loadFromEncryptedFile(self, fname):

        mustEncrypt = False

        self.decryptHeader(fname)

        mustEncrypt = True

        try:

            with gzip.open(fname, 'rb') as fin:

                ret = cPickle.load(fin)
        finally:

            if mustEncrypt:
                self.encryptHeader(fname)

        return ret


    def loadFromFile(self, fname):

        try:

            with gzip.open(fname, 'rb') as fin:

                ret = cPickle.load(fin)

                return ret

        except IOError:

            return self.loadFromEncryptedFile(fname)



    def makeComplete(self):


        #self.Q = set(self.Q)
        assert type(self.Q) is set

        o = min(self.O)

        Q = self.Q
        S = self.S
        O = self.O
        gDict = self.gDict
        dDict = self.dDict

        for q in Q:

            for a in S:
                qa = dDict.get((q, a))
                #if qa not in Q:
                if qa is None: #None in qa:
                    #print qa
                    #assert None in qa
                    #print 'completed trans'
                    dDict[(q, a)] = q

        return self


    def fixInvalidCodes(self):

        #self.Q = set(self.Q)
        assert type(self.Q) is set

        o = min(self.O)

        Q = self.Q
        S = self.S
        O = self.O
        gDict = self.gDict
        dDict = self.dDict

        for q in Q:

            oq = gDict.get(q)
            #if oq not in O:
            if oq == None:
                #assert oq == None
                #print 'completed out'
                gDict[q] = o

        return self
