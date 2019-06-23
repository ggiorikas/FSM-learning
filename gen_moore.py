import sys

sys.dont_write_bytecode = True

from itertools import product, izip
from copy import deepcopy
import random
import math


#import argparse
import cmd_parse

from moore import Moore

from util import *

SILENT = True
OPT_NL = ''

def rand():
    return random.random()
 
   
def makeRandomMoore(rseed, sCount, aSize, oSize):
    
    if not SILENT:
        if sCount < oSize:
            print OPT_NL + 'state count less than output alphabet size -- truncating the latter...'
    
    oSize = min(oSize, sCount)
    
    random.seed(rseed)
    

    inAlphabet = [str(i) for i in range(aSize)]
    outAlphabet = [str(i) for i in range(oSize)]
    
    #print inAlphabet
    #print outAlphabet

    if not SILENT:
        print OPT_NL + 'generating states...'
        
    states = ['q_%s' % i for i in range(sCount)]
    
    #print states
    
    init = states[0]
    
    #print init
    
    if not SILENT:
        print OPT_NL + 'assigning outputs...'
    
    gDict = {}
    
    for q in states:
        gDict[q] = outAlphabet[random.randint(0, oSize - 1)]
        
    shuffledStateIds = range(0, sCount)
    random.shuffle(shuffledStateIds)
    for (qid, o) in zip(shuffledStateIds, outAlphabet):
        gDict['q_%s' % qid] = o


    if not SILENT:
        print OPT_NL + 'adding transitions...'
            
    dDict = {}
    
    for q in states:
        for a in inAlphabet:
            dDict[(q, a)] = states[random.randint(0, sCount - 1)]
            
    stateIdChain = range(1, sCount)
    random.shuffle(stateIdChain)
    stateIdChain = [0] + stateIdChain + [0]
    
    for i in range(len(stateIdChain) - 1):
        a = inAlphabet[random.randint(0, aSize - 1)]
        q1 = 'q_%s' % stateIdChain[i]
        q2 = 'q_%s' % stateIdChain[i + 1]
        dDict[(q1, a)] = q2
        #print '(%s, %s) -> %s' % (q1, a, q2)
    
    ret = Moore(inAlphabet, outAlphabet, states, init, dDict, gDict)
    
    #assert isMinimal(ret)
    
    return ret


def main():
    
    global SILENT
    SILENT = False
    

    
    optionParameters = {
        
        'description' : 'generates a random Moore machine',
        
        'optionFormat' : ['name', 'aliases', 'value', 'description', 'required'],
        
        'options' : [
            ['--help', ['-h'], None, 'displays this message and exits', 0],
            
            ['--silent', ['-s'], None, 'run silently (do not print anything)', 0],
            
            ['--machine-id', ['-mid'], 
            {'type' : str, 'isValid' : lambda _ : True, 'errMsg' : ''},
            'file where the generated machine will be stored', 1],
            
            ['--random-seed', ['-rs'], 
            {'type' : int, 'isValid' : lambda _ : True, 
             'errMsg' : 'error: -rs/--random-seed must be an integer'},
            'random seed that will be used to generate the machine', 1],

            ['--state-count', ['-nq'], 
            {'type' : int, 'isValid' : lambda n : n > 0, 
             'errMsg' : 'error: -nq/--state-count must be a positive integer'},
            'number of states in the generated machine', 1],
            
            ['--input-count', ['-ni'], 
            {'type' : int, 'isValid' : lambda n : n > 0, 
             'errMsg' : 'error: -ni/--input-count must be a positive integer'},
            'size of the input alphabet of the generated machine', 1],
            
            ['--output-count', ['-no'], 
            {'type' : int, 'isValid' : lambda n : n > 0, 
             'errMsg' : 'error: -no/--output-count must be a positive integer'},
            'size of the output alphabet of the generated machine', 1]
        ],

        'usageExamples' : '''
example:

  # generate a machine with 5 states, 2 input symbols 
  # and 3 output symbols, using 1337 as the random seed,
  # and store it in the 'moore1' file inside the 'out' folder

  python gen_moore.py -mid out/moore1 -rs 1337 -nq 5 -ni 2 -no 3
''',

        'preprocessors' : [
            cmd_parse.genericHelpHandler,
        ],
        
        'postprocessors' : []
    }
        
    args = sys.argv[1:]
    if not args:
        args = ['-h']
        
    args = cmd_parse.parse(args, optionParameters)
    
    if args == None:
        exit()
        
    if args.silent:
        SILENT = True

    Nq, Ni, No = args.state_count, args.input_count, args.output_count

    moore = makeRandomMoore(args.random_seed, Nq, Ni, No)
        
    
    if not SILENT:
        print OPT_NL + 'storing generated machine to...'
        print getPath(args.machine_id)
    
    moore.saveToFile('%s' % args.machine_id)

    
    if not SILENT:
        print OPT_NL + 'done!'

if __name__ == "__main__":

    wrappedMain(main)
    

