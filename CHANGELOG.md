# Changelog

## Unreleased

- Validate Windows x64, Linux GTK2, and macOS Intel Cocoa in GitHub Actions; pass binary PTY transfers and reopen tests on Linux/macOS.
- Prepare the standalone public repository, English/Japanese documentation, license scope, and third-party notices.
- Add Windows PowerShell build support, cross-platform build CI, and a temporary-PTY test helper.
- Correct the bundled Darwin purge call to use `TCFlush`, and report test exceptions on stderr instead of opening unattended LCL dialogs.
- Document API differences and separate software testing from physical serial hardware validation.

## 2026-11-02 — Initial LCL compatibility implementation

- Introduce `TCommX` / `TCustomCommX` using bundled SynaSer instead of Windows message-based workers.
- Add explicit `DeviceName` selection for Unix serial devices.
- Add bounded transmit/receive queues, main-thread event delivery, and orderly worker shutdown.
- Add RTS-controlled half duplex, modem signals, directional buffer clearing, and BREAK sending.
- Add a GUI demo, macOS app-bundle project, lifecycle test, and optional binary-transfer test.
- Validate Windows x64 compilation and lifecycle/failed-open cleanup locally.

There is no stable release tag yet. Some legacy behavior differs; review README.md before migrating.
