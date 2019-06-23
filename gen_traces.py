# coding: utf-8

import sys

sys.dont_write_bytecode = True



from itertools import product, izip
from copy import deepcopy
from functools import total_ordering
import random
import math

import cmd_parse
import json

from moore import Moore
from util import *

SILENT = True
OPT_NL = ''


def rand():
    return random.random()


def generateCS(moore, cspc = None):

    #print 'cspc:', cspc

    if not cspc:
        cspc = 100

    if type(cspc) is int:
        cspc = cspc / 100.0
    
    
    assert isMinimal(moore)
    #print "it's minimal"
    
    S = sorted(moore.S)
    
    SpNlAll = 2

    #random.seed(machineId)
    
    #if type(percent) is int:
    #    percent /= 100.0

    sampleInputs = {}
    
    def addToSI(w):
    
        wlen = len(w)
    
        try:
        
            sampleInputs[wlen].add(w)    
        
        except:
            
            sampleInputs[wlen] = {w}
                        

    # find shortest prefix for each state
    
    shpf = {}
    
    stack = [(moore.q0, ('.l',))]
    
    #print moore.S
    
    while stack:
        #print 'stack:', stack
        q, w = stack[0]
        stack.pop(0)
        if q not in shpf:
            shpf[q] = w
            
            for a in S:
                q1 = moore.d(q, a)
                w1 = w + (a,)
                if q1 not in shpf:
                    #print 'adding', q1, w1
                    stack.append( (q1, w1) )

    #print 'shortest prefixes:'
    #print shpf
        
    # compute kernel
    
    kernel = {('.l',)}
    
    for sp in shpf.itervalues():
        
        for a in S:
            kernel.add(sp + (a,))
            
    #print 'kernel:'
    #print kernel
    
    for w in kernel:
        if w == ('.l',): continue
        
        if SpNlAll == 0: continue
        
        #sampleInputs.add(w[1:])
        addToSI(w[1:])     
                
    cond2stuff = set()
    
    for u in shpf.itervalues():
    
        #if u == ('.l',): continue
    
        #'''
        if SpNlAll < 2:
            if SpNlAll == 0:
                addToSI(u[1:])
            continue
        #'''
        
        for v in kernel:

            #if v == ('.l',): continue
            #if u == v: continue
        
            qu = moore.ds(moore.q0, u[1:])
            qv = moore.ds(moore.q0, v[1:])

            if qu != qv:
                
                # try to find a distinguishing suffix
                # but the generated machine may not be minimal
                # so, stop after some iterations to prevent 
                # looping for ever
                
                stack = [(a,) for a in S]
                
                if moore.g(qu) != moore.g(qv):
                    addToSI(u[1:])
                    addToSI(v[1:])
                    continue
                
                i = 0

                while stack:
                    
                    #print stack
                    #raw_input()

                    i += 1
                    

                    w = stack[0]
                    stack.pop(0)
                    

                    if moore.g(moore.ds(qu, w)) != moore.g(moore.ds(qv, w)):
                        # found it!
                        
                        
                        #print 'found distinguishing suffix %s for words %s, %s' % (w, u, v)
                        
                        #print len(w),
                        
                        addToSI(u[1:] + w)
                        addToSI(v[1:] + w)
                        
                        cond2stuff.add(u[1:] + w)
                        cond2stuff.add(v[1:] + w)
                        
                        break
                         
                    for a in S:
                        
                        stack.append(w + (a,))

    # remove redundant elements
    
    #'''
    for i in sorted(sampleInputs):
        ip1 = i + 1
        
        if ip1 in sampleInputs:
            
            for s1 in set(sampleInputs[i]):
                if any(s1 == s2[:-1] for s2 in sampleInputs[ip1]):
                    sampleInputs[i].remove(s1)
    #'''

    sample = []
    #for si in sorted(sampleInputs, key = lambda w: (len(w), w)):
    for i in sampleInputs:
        if i == 0: continue
        for si in sampleInputs[i]:
            #print si, moore.transduce(si)
            sample.append((si, moore.transduce(si)))
        
    #for s in sample:
    #    print s          
        
    #print len(sample)    
    
    reducedSample = []
    
    maxTrainLen = 0

    for e in sample:
        wlen = len(e[0])
        if maxTrainLen < wlen:
            maxTrainLen = wlen
        #if True: 
        if rand() <= cspc:
            reducedSample.append(e)
            

    #return reducedSample, maxTrainLen
    return reducedSample, ({w[1:] for w in shpf.itervalues() if w != ('.l',)}, {w[1:] for w in kernel if w != ('.l',)}, cond2stuff)


def generateTrainingSample(moore, config):
    
    useCS = config.get('characteristic_sample')
    totalLen = config.get('total_length')    
    rseed = config.get('random_seed')
    cspc = config.get('cs_percentage')
    
    #print 'generating train set with:', ', '.join('%s -> %s' % (k, v) for k, v in config.iteritems())
    
    
    if useCS:
        pass
        # use cs function from this file, return the resulting set, don't store to file
        
        sample, maxTrainLen = generateCS(moore, cspc)
        
        return sample
        
    else:
        pass
        # use the tree train gen function from the simulink experiments. again, just return the result
        
        sample = generateRandomTree(moore, totalLen, rseed)
        
        return sample
    
    pass


def generateTestingSample(moore, config):
    
    testSize = config.get('size')
    wordLen = config.get('word_length')
    rseed = config.get('random_seed') 
    
    #print 'generating test set with:', ', '.join('%s -> %s' % (k, v) for k, v in config.iteritems())
    
    # use the function is this file, return the resulting test set
    
    Nq = len(moore.Q)
    Ni = len(moore.S)
    No = len(moore.O)

    testWords = set()

    random.seed(rseed)

    listS = list(moore.S)
    
    for i in xrange(testSize):
        
        newGenFailCount = 0
        
        while True:
        
            word = tuple([random.choice(listS) for _ in range(wordLen)])
            
            if word not in testWords:
                break
            
            if newGenFailCount > 100:
                raise Exception("can't generate more unique words")
                print "can't generate more unique words"
                testSet = [(wi, moore.transduce(wi)) for wi in testWords]
                return testSet
            
            newGenFailCount += 1
            
        testWords.add(word)

    testSet = [(wi, moore.transduce(wi)) for wi in testWords]
    
    return testSet


def main():
    
    
    '''
    
    args: machine-id traces-id cs/tree/fixlen
    
    if cs:
        cspc
    if tree:
        total length            
    if fixlen:
        word count
        word len
    
    '''
        
    def validator(parsedOpts, optParams):

        subCommandCount = sum(1 for e in [parsedOpts.cs, parsedOpts.tree, parsedOpts.fixlen] if e)

        if subCommandCount != 1:

            return 'error: exactly one of cs, tree, fixlen must be selected'        
        
        if parsedOpts.cs or parsedOpts.tree:
            
            setattr(parsedOpts, 'train_or_test', 'train')            
                        
            if parsedOpts.size != None:
                return 'error: -sz/--size option can only be used with fixlen'
            
            if parsedOpts.word_length != None:
                return 'error: -wlen/--word-length option can only be used with fixlen'
            
            if parsedOpts.cs:
                
                setattr(parsedOpts, 'cs_or_random', 'cs')
                
                if parsedOpts.total_length != None:
                    return 'error: -tlen/--total-length option can only be used with tree'
                
                if parsedOpts.random_seed != None:
                    return 'error: -rs/--random-seed option cannot be used with cs'
                
                for opt in optParams['options']:
                    if opt[optParams['optionFormat'].index('name')] == '--random-seed':
                        opt[optParams['optionFormat'].index('required')] = 0
                
            else:
                
                setattr(parsedOpts, 'cs_or_random', 'random')

                if parsedOpts.cs_percentage != None:
                    return 'error: -cspc/--cs-percentage option can only be used with cs'
                
                for opt in optParams['options']:
                    if opt[optParams['optionFormat'].index('name')] == '--total-length':
                        opt[optParams['optionFormat'].index('required')] = 1
            
        else:
            
            setattr(parsedOpts, 'train_or_test', 'test')
                        
            if parsedOpts.total_length != None:
                return 'error: -tlen/--total-length option can only be used with tree'

            if parsedOpts.cs_percentage != None:
                return 'error: -cspc/--cs-percentage option can only be used with cs'
            
            for opt in optParams['options']:
                if opt[optParams['optionFormat'].index('name')] in ['--size', '--word-length']:
                    opt[optParams['optionFormat'].index('required')] = 1
            
        
        
    
    optionParameters = {
        
        'description' : 'generates input-output traces from a given Moore machine',
        
        'optionFormat' : ['name', 'aliases', 'value', 'description', 'required'],
        
        'options' : [
            ['--help', ['-h'], None, 'displays this message and exits', 0],
            
            ['--silent', ['-s'], None, 'run silently (do not print anything)', 0],

            ['--machine-id', ['-mid'], 
            {'type' : str, 'isValid' : lambda _ : True, 'errMsg' : ''},
            'path of the machine that will generate the traces', 1],
            
            ['--traces-id', ['-tid'], 
            {'type' : str, 'isValid' : lambda _ : True, 'errMsg' : ''},
            'file where the generated traces will be stored', 1],
            
            ['--random-seed', ['-rs'], 
            {'type' : int, 'isValid' : lambda _ : True, 
             'errMsg' : 'error: -rs/--random-seed must be an integer'},
            'random seed that will be used to generate the traces (use with tree / fixlen)', 1],
                        
            ['cs', [], None, 'generates characteristic sample', 0],

            ['--cs-percentage', ['-cspc'], 
            {'type' : int, 'isValid' : (lambda x : 1 <= x <= 100), 'errMsg' : ''},
            'percentage of the characteristic sample to be generated (use with cs)', 0],
            
            ['tree', [], None, 'generates random tree of words', 0],
            
            ['--total-length', ['-tlen'], 
            {'type' : int, 'isValid' : lambda n : n > 0, 
             'errMsg' : 'error: -tlen/--total-length must be a positive integer'},
            'total length of generated input traces in letters (use with tree)', 0],            
            
            ['fixlen', [], None, 'generates words of fixed length', 0],
            
            ['--size', ['-sz'], 
            {'type' : int, 'isValid' : lambda n : n > 0, 
             'errMsg' : 'error: -sz/--size must be a positive integer'},
            'input-output pair count in generated traces (use with fixlen)', 0],
            
            ['--word-length', ['-wlen'], 
            {'type' : int, 'isValid' : lambda n : n > 0, 
             'errMsg' : 'error: -wlen/--word-length must be a positive integer'},
            'input word length in generated traces (use with fixlen)', 0],
            
        ],

        'usageExamples' : '''
examples:

  # generate a characteristic sample of the (minimal) machine
  # stored in the 'moore1' file inside the 'fsm' folder and
  # save it in the 'cs1' file inside the 'tr' folder

  python gen_traces.py -mid fsm/moore1 -tid tr/cs1 cs
  
  
  # same as above but instead of a characteristic sample we generate a
  # tree of words of total input length 1337, using a random seed of 42

  python gen_traces.py -mid fsm/moore1 -tid tr/tree1 tree -rs 42 -tlen 1337
  
  
  # generate a set of 1337 input-output pairs, 
  # with each input word consisting of 128 letters
  
  python gen_traces.py -mid fsm/moore1 -tid tr/fixlen1 fixlen -rs 42 -sz 1337 -wlen 128
''',

        'preprocessors' : [
            cmd_parse.genericHelpHandler,
            validator
        ],
        
        'postprocessors' : [
            
        ]
    }
    
    args = sys.argv[1:]
    
    if not args:
        args = ['-h']
        
    args = cmd_parse.parse(args, optionParameters)
    
    if args == None:
        exit()
    
    global SILENT
    
    if args.silent:
        SILENT = True
    else:
        SILENT = False
    
    #print args

    # load moore machine

    if not SILENT:
        print OPT_NL + 'loading Moore machine from...'
        print getPath(args.machine_id)
    
    moore = Moore([], [1], [], 'q0', {}, {})
    #moore = moore.loadFromFile('out/%s' % args.machine_id)
    moore = moore.loadFromFile('%s' % args.machine_id)
    
    if args.train_or_test == 'train':
        
        config = ({'characteristic_sample' : True, 'cs_percentage' : args.cs_percentage} if args.cs_or_random == 'cs' 
                  else {'total_length' : args.total_length, 
                        'random_seed' : args.random_seed})
        
        if not SILENT: print OPT_NL + 'generating traces...'
        trainSample = generateTrainingSample(moore, config)
                
        #'''
        cs, csParts = generateCS(moore, 100)
        print OPT_NL + 'generated sample contains %s %% of CS(%s)' % (round(100 * sampleContainsSample(trainSample, cs), 2), len(cs))
        print OPT_NL + 'generated sample contains %s %% %s %% %s %% of shpf(%s), kernel(%s), cond2stuff(%s)' % tuple(
            [round(100 * e, 2) for e in sampleContainsCSParts(trainSample, *csParts)] + [len(e) for e in csParts])
        print OPT_NL + 'generated sample contains %s %% %s %% of states(%s), transitions(%s)' % tuple(
            [round(100 * e, 2) for e in sampleContainsStatesTransitions(trainSample, moore)] + [len(moore.Q), len(moore.dDict)])
        #'''
        
        if not SILENT: 
            print OPT_NL + 'storing %s traces to...' % len(trainSample)
            print getPath(args.traces_id)
        #saveMooreSample('out/%s' % args.traces_id, trainSample)
        #from pprint import pprint
        #pprint(trainSample)
        saveMooreSample('%s' % args.traces_id, trainSample)

        #saveMooreSampleAsJson('out/%s.json' % args.traces_id, trainSample)

    else:
        
        if not SILENT: print OPT_NL + 'generating traces...'
        testSample = generateTestingSample(moore, {'size' : args.size, 
                                  'word_length' : args.word_length,
                                  'random_seed' : args.random_seed})
        
        #'''
        cs, csParts = generateCS(moore, 100)
        print OPT_NL + 'generated sample contains %s %% of CS(%s)' % (round(100 * sampleContainsSample(testSample, cs), 2), len(cs))
        print OPT_NL + 'generated sample contains %s %% %s %% %s %% of shpf(%s), kernel(%s), cond2stuff(%s)' % tuple(
            [round(100 * e, 2) for e in sampleContainsCSParts(testSample, *csParts)] + [len(e) for e in csParts])
        print OPT_NL + 'generated sample contains %s %% %s %% of states(%s), transitions(%s)' % tuple(
            [round(100 * e, 2) for e in sampleContainsStatesTransitions(testSample, moore)] + [len(moore.Q), len(moore.dDict)])
        #'''
        
        if not SILENT: 
            print OPT_NL + 'storing %s traces to...' % len(testSample)
            print getPath(args.traces_id)
        #saveMooreSample('out/%s' % args.traces_id, testSample)
        saveMooreSample('%s' % args.traces_id, testSample)

        #saveMooreSampleAsJson('out/%s.json' % args.traces_id, testSample)

    if not SILENT: print OPT_NL + 'done!'


if __name__ == "__main__":
    
    wrappedMain(main)
