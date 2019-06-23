import sys

sys.dont_write_bytecode = True

from pprint import pprint
from itertools import izip

import re


class ArgDict(dict):
    
    def __init__(self, *args):
        dict.__init__(self, *args)
        
        for k, v in self.iteritems():
            self[k] = v

    def __setitem__(self, k, v):
        
        dict.__setitem__(self, k, v)
        
        if k.startswith('--'):
            k = k[2:]
        
        k = re.sub('[^a-zA-Z0-9]', '_', k)
        
        #print k
        
        setattr(self, k, v)
        


type2str = {
    str : 'string',
    int : 'integer',
    float : 'real'        
}


def genericHelpHandler(parsedOpts, optParams):
    
    import os
    import __main__
    
    options = [
        dict(izip(optParams['optionFormat'], opt)) 
        for opt in optParams['options']
    ]    

    if parsedOpts.help:
        
        optRows = []
        
        for opt in options:
            
            optRows.append(
                '  %s%s ' % (
                    ', '.join(opt['aliases'] + [opt['name']]), 
                    ' <%s> ' % type2str[opt['value']['type']] if opt['value'] else '')
            )

        maxLen = max(map(len, optRows))
        
        for i, optr in enumerate(optRows):
            optRows[i] += ' ' * (maxLen - len(optr)) + options[i]['description']

        fname = os.path.basename(__main__.__file__)

        return '\n%s\n' % ('''
%s:
  
  %s
  
  
usage: 

  python %s [options]


options: 

%s

%s
''' % (fname, optParams['description'], fname, '\n'.join(optRows), optParams['usageExamples'])).strip()


def versionHandler(parsedOpts, optParams):

    if parsedOpts.version:
        return 'cmd parser v0.1'


optionParameters = {
    
    'optionFormat' : ['name', 'aliases', 'value', 'description', 'required'],
    
    'options' : [
        ['--help', ['-h'], None, 'displays this message and exits', 0],
        
        ['--version', ['-v'], None, 'displays tool version and exits', 0],
        
        ['--input-file', ['-fin', '-in'], 
         {'type' : str, 'isValid' : lambda _ : True, 'errMsg' : ''},
         'path to the input file', 1],
        
        ['--output-file', ['-fout', '-out'], 
         {'type' : str, 'isValid' : lambda _ : True, 'errMsg' : ''},
         'path to the output file', 1],

        ['--algorithm-id', ['-aid', '-algo'], 
         {'type' : int, 'isValid' : lambda n : n in [1, 2, 3], 
          'errMsg' : 'error: -aid/-algo/--algorithm-id must be 1, 2 or 3'},
         'algorithm to be used (1, 2 or 3)', 1]
    ],
         
    'usageExamples' : '''
examples:

  # display help message
  python cmd_parse.py -h
  
  # use algorithm 3 on dir1/file1 and stores the result on dir2/file2
  python cmd_parse.py -fin dir1/file1 -fout dir2/file2 -algo 3
''',

    'preprocessors' : [
        genericHelpHandler,
        versionHandler,
    ],

    'postprocessors' : [
        
    ]

}


def parse(args, optionParameters):
    
    options = {
        opt[optionParameters['optionFormat'].index('name')] : 
            dict(izip(optionParameters['optionFormat'], opt)) 
        for opt in optionParameters['options']
    }

    aliases2names = {opt : opt for opt in options}
    
    for optName, optInfo in options.iteritems():
        for alias in optInfo['aliases']:
            aliases2names[alias] = optName
    
    ret = ArgDict({opt : None for opt in options})

    i = 0

    while i < len(args):

        opt = args[i]

        i += 1

        if opt not in aliases2names:
            print 'error: unrecognized option %s' % opt
            return None        
        else:
            optName = aliases2names[opt]
            optVal = options[optName]['value']

            if optVal:
                if i >= len(args):
                    print 'error: missing value for option %s' % '/'.join(options[optName]['aliases'] + [optName])
                    return None
                else:
                    
                    try:
                        ret[optName] = optVal['type'](args[i])
                        i += 1

                    except:
                        print optVal['errMsg']
                        return None

                    if not optVal['isValid'](ret[optName]):
                        print optVal['errMsg']
                        return None

            else:
                ret[optName] = True

    for op in optionParameters['preprocessors']:

        msg = op(ret, optionParameters)

        if msg:
            print msg
            return None
        
    for opt in optionParameters['options']:
        
        optName = opt[optionParameters['optionFormat'].index('name')]
        optReq = opt[optionParameters['optionFormat'].index('required')]
        
        if optReq and ret[optName] == None:
            print 'error: %s is a required option' % '/'.join(options[optName]['aliases'] + [optName])
            return None

    for op in optionParameters['postprocessors']:

        msg = op(ret, optionParameters)

        if msg:
            print msg
            return None

    return ret


if __name__ == '__main__':
    
    args = sys.argv[1:] 
    
    print args
    
    pprint(parse(args, optionParameters))
    
