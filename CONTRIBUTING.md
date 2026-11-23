# Contributing

For a bug report, include the OS and CPU, Lazarus/FPC versions, LCL widget set, serial-adapter model/driver, communication settings, reproduction steps, and whether the problem also occurs with a PTY pair. Remove credentials, private device payloads, and personal identifiers from logs.

Build the package, demo, and smoke test using `build.sh` or `build.ps1`. Run the no-argument smoke test; on Linux/macOS also run `python3 tools/pty_smoke.py` when socat is available. Describe the checks you actually ran and the hardware behavior you could not validate.

Keep changes focused. Preserve public names unless an intentional compatibility change is documented. Keep LCL callbacks on the main thread, bound queues, and avoid indefinite waits during shutdown. Changes to worker ownership, buffer lifetime, and timeout behavior should include a regression test.

The newly written project code is MIT-licensed. Contributions to that code are submitted under the same license. Preserve third-party notices and explain any change under `vendor/synapse`; do not replace its licenses with MIT.

Only maintainers publish tags/releases. A successful PTY test does not establish hardware flow-control or USB timing compatibility.
