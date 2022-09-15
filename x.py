#!/usr/bin/env python3

import os
import shutil
import argparse
import itertools
import subprocess
from pathlib import Path
from collections import namedtuple
from jinja2 import Template

class c:
    HEADER    = '\033[95m'
    OKBLUE    = '\033[94m'
    OKCYAN    = '\033[96m'
    OKGREEN   = '\033[92m'
    WARNING   = '\033[93m'
    FAIL      = '\033[91m'
    RESET     = '\033[0m'
    BOLD      = '\033[1m'
    UNDERLINE = '\033[4m'


TOOLS = {
    'vcs': 'vcs',
}

basedir = Path(__file__).parent.resolve()
hwdir = basedir / 'hw'
workdir = basedir / 'xwork'

TESTBENCHES = {
    'tpumac': {
        'files': ['tpumac.sv', 'tpumac_tb.sv'],
    },
}

def vcs_run_tb(name, desc):
    print(f'{c.HEADER}== running tb {name} {c.BOLD}[VCS]{c.RESET}{c.HEADER} =={c.RESET}')
    vcs_workdir = workdir/'vcs'/name
    vcs_workdir.mkdir(parents=True, exist_ok=True)
    simv_bin = vcs_workdir/'simv'

    print(f'building simv...')

    cmd = [
        TOOLS['vcs'],
        '-full64',
        '-timescale=1ns/10ps',
        '-debug_access+all',
        '-sverilog',
        '+lint=all',
        '-o', str(simv_bin),
    ]
    cmd.extend([str(hwdir / fname) for fname in desc['files']])
    subprocess.run(cmd, check=True)
    print(f'building simv... {c.OKBLUE}DONE{c.RESET}')

    print(f'running simv...')
    cmd = [
        str(simv_bin),
    ]
    subprocess.run(cmd, check=True)
    print(f'running simv... {c.OKGREEN}DONE{c.RESET}')

def test(args):
    for testbench in args.testbench:
        if args.simulator == 'vcs':
            vcs_run_tb(testbench, TESTBENCHES[testbench])
        elif args.simulator == 'questa':
            questa_run_tb(testbench, TESTBENCHES[testbench])

def main():
    parser = argparse.ArgumentParser(description='ad hoc lil buildsystem :>')
    subparsers = parser.add_subparsers(title='subcommands',
                                       description='tasks',
                                       dest='command')
    subparsers.required = True

    parser_tests = subparsers.add_parser('test', formatter_class=argparse.ArgumentDefaultsHelpFormatter)
    parser_tests.add_argument('testbench', metavar='TESTBENCH', nargs='+')
    parser_tests.add_argument('-s', '--simulator',
        choices=['vcs', 'questa'],
        default='vcs',
        help='simulator used to run testbench')
    parser_tests.set_defaults(func=test)

    args = parser.parse_args()
    args.func(args)

if __name__ == '__main__':
    main()
