import sys

sys.dont_write_bytecode = True

import json

from moore import *

from util import *

import cmd_parse

SILENT = True
OPT_NL = ''

def main():

    optionParameters = {
        
            'description' : '''converts a Moore machine described in the internal binary fromat (compatible 
      with the other scripts), into one described in a human readable json format''',

        'optionFormat' : ['name', 'aliases', 'value', 'description', 'required'],

        'options' : [
            ['--help', ['-h'], None, 'displays this message and exits', 0],
            
            ['--silent', ['-s'], None, 'run silently (do not print anything)', 0],    

            ['--machine-id', ['-mid'], 
            {'type' : str, 'isValid' : lambda _ : True, 'errMsg' : ''},
            'path of the machine to be converted', 1],
            
            ['--output-file', ['-fout'], 
            {'type' : str, 'isValid' : lambda _ : True, 'errMsg' : ''},
            'output json file where the result will be stored', 1],
        ],

        'usageExamples' : '''
    example:

      # convert the binary representation of the Moore machine stored in 'fsm/mr1' 
      # into a (text based) json one, and store the result in 'fsm/mr1.json'

      python moore2json.py -mid fsm/mr1 -fout fsm/mr1.json
    ''',

        'preprocessors' : [
            cmd_parse.genericHelpHandler
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

    if not SILENT:
        print OPT_NL + 'loading Moore machine from...'
        print getPath(args.machine_id)
        
    moore = Moore([], [1], [], 'q0', {}, {})
    moore = moore.loadFromFile('%s' % args.machine_id)

    if not SILENT:
        print OPT_NL + 'converting and storing to...'
        print getPath(args.output_file)

    moore.saveAsJson(args.output_file)

    if not SILENT:
        print OPT_NL + 'done!'


if __name__ == '__main__':

    wrappedMain(main)
        
        