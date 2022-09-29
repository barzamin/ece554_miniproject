#!/usr/bin/env python3

import os
import click
import subprocess
import logging
from pathlib import Path

logger = logging.getLogger(__name__)

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

with open(hwdir / 'filelist_test.txt') as f:
    FILELIST = [hwdir / x.strip() for x in f.read().strip().split()]
TESTBENCHES = {
    'fifo': {
        'top': 'fifo_tb',
    },
    'tpumac': {
        'top': 'tpumac_tb',
    },
    'systolic_array': {
        'top': 'systolic_array_tb',
    },
    'memAB': {
        'top': 'memAB_tb',
    },
    'tpuv1_integration': {
        'top': 'tpuv1_integration_tb',
    }
}

def vcs_run_tb(name, desc):
    logging.info(f"running tb {name} [in VCS]")
    vcs_workdir = workdir/'vcs'/name
    vcs_workdir.mkdir(parents=True, exist_ok=True)
    simv_bin = vcs_workdir/'simv'

    cmd = [
        '-full64',
        '-timescale=1ns/10ps',
        '-debug_access+all',
        '-sverilog',
        f'+incdir+{str(hwdir)}',
        '+lint=all',
        '-o', str(simv_bin),
    ]
    cmd += [str(hwdir / fname) for fname in desc['files']]
    run_tool(TOOLS['vcs'], cmd)
    logging.info(f"built simv from sources for {name}")

    logging.info("running simv")
    cmd = [
        str(simv_bin),
    ]
    subprocess.run(cmd, check=True)
    logging.info("simv done")

def questa_run_tb(name, desc, record_coverage=False, coverstore=None):
    logging.info(f"running tb {name} [in questa]")

    work = workdir / 'questa' / 'work'
    wlf = workdir / 'questa' / f"{desc['top']}.wlf"
    coverstore = coverstore or workdir / 'questa' / 'coverstore'
    work.mkdir(parents=True, exist_ok=True)

    cmd = [
        '-work', str(work),
        '-timescale=1ns/10ps',
    ]

    if record_coverage:
        logging.warning(f"building {name} with coverage recording enabled")
        cmd += ['+cover=bcestf', '-coveropt', '3']

    # cmd += [str(hwdir / fname) for fname in desc['files']]
    cmd += [str(x) for x in FILELIST]
    run_tool(TOOLS['vlog'], cmd, cwd=workdir/'questa')
    logging.info(f"built workdir from sources for {name}")

    logging.info("running vsim...")
    cmd = [
        '-work', str(work),
        '-wlf', str(wlf),
        '-vopt', '-voptargs=+acc',
        # TODO: switch
        # '-novopt', '-suppress', '12110',
        '-logfile', str(workdir / 'questa' / f"{desc['top']}.log"),
        '-c', '-do', 'add wave -r tpuv1_integration_tb/DUT/* ; run -all',
        f"work.{desc['top']}",
    ]
    if record_coverage:
        logging.warning(f"running {name} with coverage recording enabled")
        cmd += [
            '-coverage',
            '-coverstore', str(coverstore),
            '-testname', name,
        ]

    run_tool(TOOLS['vsim'], cmd, cwd=workdir/'questa')
    logging.info(f"vsim for {name} done!")

@click.group()
def cli():
    """ad hoc lil buildsystem :>"""

@cli.command()
@click.argument('testbenches', nargs=-1)
@click.option('-s', '--simulator', type=click.Choice(['vcs', 'questa']), default='questa', help='simulator used to execute testbench', show_default=True)
@click.option('-c', '--cover', is_flag=True, help='collect coverage data')
def test(testbenches, simulator, cover):
    """run given testbench(es)"""

    for testbench in testbenches:
        if simulator == 'vcs':
            vcs_run_tb(testbench, TESTBENCHES[testbench])
        elif simulator == 'questa':
            questa_run_tb(testbench, TESTBENCHES[testbench], record_coverage=cover)

@cli.command()
@click.argument('testbenches', nargs=-1)
def questa_cover(testbenches):
    """generate coverage report for a questasim ucdb"""

    logging.info("merging coverage databases...")

    # TODO
    ucdb_out = workdir / 'questa' / 'coverout.ucdb'
    coverstore = workdir / 'questa' / 'coverstore'

    cmd = [
        'merge',
        '-out', str(ucdb_out),
        f"{str(coverstore)}:{','.join(testbenches)}"
    ]
    run_tool(TOOLS['vcover'], cmd)
    logging.info("merged coverage databases")

@cli.command()
@click.argument('testbench')
# @click.option('--waves')
def waves(testbench):
    desc = TESTBENCHES[testbench]
    wlf = workdir / 'questa' / f"{desc['top']}.wlf"
    env = os.environ.copy()
    env.update(QUESTA_ENV)
    subprocess.run([TOOLS['vsim']['bin'],
        '-view', str(wlf), '-do',
        'add wave -r tpuv1_integration_tb/DUT/*'],
        env=env,
    )
 
if __name__ == '__main__':
    logging.basicConfig(level='NOTSET')

    cli()
