#!/usr/bin/env python3
"""Query hdc with a managed foreground server when automatic server startup fails."""
import argparse
import json
import os
from pathlib import Path
import socket
import subprocess
import sys
import time

parser = argparse.ArgumentParser()
parser.add_argument('--port', type=int, default=8710)
args = parser.parse_args()
if not 1 <= args.port <= 65535:
    parser.error('port must be in 1..65535')
studio = Path(os.environ.get('DEVECO_STUDIO_HOME', '/Applications/DevEco-Studio.app/Contents'))
hdc = studio / 'sdk/default/openharmony/toolchains/hdc'
address = f'127.0.0.1:{args.port}'
server = None

def port_listening():
    try:
        with socket.create_connection(('127.0.0.1', args.port), timeout=1):
            return True
    except OSError:
        return False

def query():
    # A timeout is an observation failure, never evidence that an existing server stopped.
    result = subprocess.run([str(hdc), '-p', '-s', address, 'list', 'targets', '-v'],
                            capture_output=True, text=True, timeout=15)
    output = result.stdout.strip()
    if result.returncode or 'Connect server failed' in output:
        raise RuntimeError('hdc query failed: ' + (output or result.stderr.strip()))
    return output

try:
    if port_listening():
        output = query()
        mode = 'existing server reused'
    else:
        server = subprocess.Popen([str(hdc), '-m', '-s', address],
                                  stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        deadline = time.monotonic() + 5
        while not port_listening():
            if server.poll() is not None:
                raise RuntimeError('managed hdc server exited before listening')
            if time.monotonic() >= deadline:
                raise RuntimeError('managed hdc server did not begin listening in time')
            time.sleep(0.1)
        output = query()
        mode = 'managed foreground server'
    empty = '[Empty]' in output
    print(json.dumps({'server': mode, 'address': address, 'query': 'list targets -v',
                      'targetsEmpty': empty, 'output': output,
                      'note': 'No device installation, signing, or authorization is performed.'},
                     ensure_ascii=False, indent=2))
except (OSError, RuntimeError, subprocess.TimeoutExpired) as error:
    print(str(error), file=sys.stderr)
    sys.exit(1)
finally:
    # Never stop a server owned by DevEco Studio or another process.
    if server is not None and server.poll() is None:
        server.terminate()
        try:
            server.wait(timeout=5)
        except subprocess.TimeoutExpired:
            server.kill()
            server.wait(timeout=5)
