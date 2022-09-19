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


QUESTA_BIN = Path('/cae/apps/data/mentor-2022/questasim/bin')
QUESTA_ENV = {
    'MGC_AMS_HOME': '/cae/apps/data/mentor-2022',
    'LM_LICENSE_FILE': '1717@mentor.license.cae.wisc.edu',
    'CALIBRE_SKIP_OS_CHECKS': '1',
    'USE_CALIBRE_VCO': 'aoi',
    'PATH': os.getenv('PATH'),
}

TOOLS = {
    'vcs': {
        'bin': 'vcs',
    },
    'vlog': {
        'bin': QUESTA_BIN/'vlog',
        'env': QUESTA_ENV,
    },
    'vsim': {
        'bin': QUESTA_BIN/'vsim',
        'env': QUESTA_ENV,
    },
    'vcover': {
        'bin': QUESTA_BIN/'vcover',
        'env': QUESTA_ENV,
    },
}

def run_tool(tool, cmdargs, **kwargs):
    return subprocess.run([tool['bin']] + cmdargs,
        env=tool.get('env'),
        check=True,
        **kwargs)

basedir = Path(__file__).parent.resolve()
hwdir = basedir / 'hw'
workdir = basedir / 'xwork'

TESTBENCHES = {
    'tpumac': {
        'files': ['tpumac.sv', 'tpumac_tb.sv'],
        'top': 'tpumac_tb',
    },
    'systolic_array': {
        'files': ['systolic_array.sv', 'systolic_array_tb.sv'],
    },
}

def vcs_run_tb(name, desc):
    print(f'{c.HEADER}== running tb {name} {c.BOLD}[VCS]{c.RESET}{c.HEADER} =={c.RESET}')
    vcs_workdir = workdir/'vcs'/name
    vcs_workdir.mkdir(parents=True, exist_ok=True)
    simv_bin = vcs_workdir/'simv'

    print(f'building simv...')

    cmd = [
        '-full64',
        '-timescale=1ns/10ps',
        '-debug_access+all',
        '-sverilog',
        '+lint=all',
        '-o', str(simv_bin),
    ]
    cmd += [str(hwdir / fname) for fname in desc['files']]
    run_tool(TOOLS['vcs'], cmd)
    print(f'building simv... {c.OKBLUE}DONE{c.RESET}')

    print(f'running simv...')
    run_tool(TOOLS['simv'], [])
    print(f'running simv... {c.OKGREEN}DONE{c.RESET}')

def questa_run_tb(name, desc, record_coverage=False, coverstore=None):
    work = workdir / 'questa' / 'work'
    coverstore = coverstore or workdir / 'questa' / 'coverstore'
    work.mkdir(parents=True, exist_ok=True)

    print(f'running vlog...')
    cmd = [
        '-work', str(work),
        '-timescale=1ns/10ps',
    ]

    if record_coverage:
        print(f'{c.WARNING}building with coverage recording enabled{c.RESET}')
        cmd += ['+cover=bcestf', '-coveropt', '3']

    cmd += [str(hwdir / fname) for fname in desc['files']]
    run_tool(TOOLS['vlog'], cmd)
    print(f'running vlog... {c.OKBLUE}DONE{c.RESET}')

    print(f'running vsim...')
    cmd = [
        '-work', str(work),
        '-vopt', '-voptargs=+acc',
        '-c', '-do', 'run -all',
        f"work.{desc['top']}",
    ]
    if record_coverage:
        print(f'{c.WARNING}running with coverage recording enabled{c.RESET}')
        cmd += [
            '-coverage',
            '-coverstore', str(coverstore),
            '-testname', name,
        ]

    run_tool(TOOLS['vsim'], cmd)
    print(f'running vsim... {c.OKGREEN}DONE{c.RESET}')

def test(args):
    for testbench in args.testbench:
        if args.simulator == 'vcs':
            vcs_run_tb(testbench, TESTBENCHES[testbench])
        elif args.simulator == 'questa':
            questa_run_tb(testbench, TESTBENCHES[testbench], record_coverage=args.cover)

def questa_cover(args):
    print(f'merging coverage databases...')

    # TODO
    ucdb_out = workdir / 'questa' / 'coverout.ucdb'
    coverstore = workdir / 'questa' / 'coverstore'

    cmd = [
        'merge',
        '-out', str(ucdb_out),
        f"{str(coverstore)}:{','.join(args.testbench)}"
    ]
    run_tool(TOOLS['vcover'], cmd)
    print(f'merging coverage databases... {c.OKGREEN}DONE{c.RESET}')

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
    parser_tests.add_argument('-c', '--cover', action='store_true', help='collect coverage data')
    parser_tests.set_defaults(func=test)

    parser_questa_cover = subparsers.add_parser('questa-cover', formatter_class=argparse.ArgumentDefaultsHelpFormatter)
    parser_questa_cover.add_argument('testbench', metavar='TESTBENCH', nargs='+')
    parser_questa_cover.set_defaults(func=questa_cover)

    args = parser.parse_args()
    args.func(args)

if __name__ == '__main__':
    main()
