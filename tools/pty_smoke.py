#!/usr/bin/env python3
"""Run the opt-in CommX binary test against a private, temporary socat PTY pair."""
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import time


def main():
    if os.name != 'posix':
        raise SystemExit('PTY tests require Linux or macOS.')
    socat = shutil.which('socat')
    if not socat:
        raise SystemExit('socat is required; install it and rerun the test.')
    root = Path(__file__).resolve().parents[1]
    executable = root / 'tests' / 'CommXSmoke'
    if not executable.is_file():
        raise SystemExit('Build tests/CommXSmoke.lpi before running this helper.')
    with tempfile.TemporaryDirectory(prefix='commx-pty-') as temp:
        a, b = Path(temp) / 'a', Path(temp) / 'b'
        with (Path(temp) / 'socat.log').open('w+') as log:
            peer = subprocess.Popen(
                [socat, '-d', '-d', f'pty,raw,echo=0,link={a}',
                 f'pty,raw,echo=0,link={b}'], stdout=log, stderr=log)
            try:
                deadline = time.monotonic() + 5
                while not (a.exists() and b.exists()):
                    if peer.poll() is not None or time.monotonic() > deadline:
                        raise RuntimeError('socat failed to create the PTY pair')
                    time.sleep(0.05)
                result = subprocess.run([str(executable), str(a), str(b)], timeout=25)
                return result.returncode
            finally:
                if peer.poll() is None:
                    peer.terminate()
                    try:
                        peer.wait(timeout=3)
                    except subprocess.TimeoutExpired:
                        peer.kill()
                        peer.wait()
                log.seek(0)
                print(log.read(), file=sys.stderr, end='')


if __name__ == '__main__':
    sys.exit(main())
