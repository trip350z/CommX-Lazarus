# CommX for Lazarus

[日本語](README.ja.md) · [Build and test status](https://github.com/trip350z/CommX-Lazarus/actions/workflows/build.yml)

A serial-port component for Lazarus/LCL with a CommX-compatible API and a bundled SynaSer transport. Includes a GUI terminal, lifecycle tests, and optional bidirectional binary-transfer tests.

This is a new LCL compatibility implementation inspired by CommX 1.05 by エックス (KYY06770). It replaces the Windows message/thread implementation. Original Delphi PAS/DCU/DCR files are not distributed here. It is **not a drop-in replacement for every legacy behavior**; review the differences below before migrating an application.

## Platform status

| Platform | Widget set | Project | Validation |
| --- | --- | --- | --- |
| Windows x64 | `win32` | `demo/CommXDemo.lpi` | Local package/demo builds and lifecycle tests passed |
| Linux x64 | `gtk2` (also targets Qt5/Qt6) | `demo/CommXDemo.lpi` | CI builds and PTY tests configured |
| macOS Intel | `cocoa` | `demo/CommXDemoMac.lpi` | CI builds and PTY tests configured |
| macOS Apple Silicon | `cocoa` | `demo/CommXDemoMac.lpi` | Targeted by source; not yet validated |

The Actions results report the latest automated validation. PTYs test byte transport, not physical modem lines, USB timing, parity errors, or real hardware. Qt5/Qt6 and IDE installation are not covered by the workflow.

## Install

1. Clone or download the **whole repository**, including `vendor/synapse`.
2. In Lazarus, choose **Package → Open package file** and open `commxlcl.lpk`.
3. Compile, then choose **Use → Install** and rebuild the IDE.
4. Find `TCommX` on the **LIB-X** component palette.

For runtime-only use, add the repository root and `vendor/synapse` to the project's unit search path, and `vendor/synapse` to its include search path. Add `CommX` to `uses`.

The local Windows baseline is Free Pascal 3.2.2. Install Lazarus/LCL and a compiler for your target CPU, plus the development libraries required by the widget set. On macOS, also install the Xcode Command Line Tools/SDK. Unix programs must load `cthreads` before `Interfaces`; the supplied programs do this.

## Build and run

From Lazarus, open the project in the platform table and build it. CLI examples from the repository root:

```sh
# Linux: GTK2 is the default. Qt5/Qt6 require their matching LCL bindings.
sh build.sh gtk2
./demo/CommXDemo

# macOS: builds a Cocoa .app bundle.
sh build.sh cocoa
open demo/CommXDemo.app
```

On Windows, use Lazarus or PowerShell:

```powershell
./build.ps1 -WidgetSet win32
./tests/CommXSmoke.exe
```

On Ubuntu/Debian, include `fp-units-misc` with Lazarus/LCL; the clipboard units need its CHM parser even in a serial-only application.

Put `lazbuild` on PATH, or pass `-LazBuild 'E:\path\to\lazbuild.exe'` to `build.ps1`. Build outputs are separated by CPU, OS, and widget set. These commands are native builds, not cross-compiler installers.

The demo opens a device **only when Open is clicked**, and sends only when Send is clicked. Defaults: **9600 baud, 8N1, no flow control**. Receive data is displayed as hex.

## Choose a device

| OS | `DeviceName` example | When omitted |
| --- | --- | --- |
| Windows | `COM3` | `PortNo = 3` selects `COM3` |
| Linux | `/dev/ttyUSB0`, `/dev/ttyACM0` | `PortNo = 1` selects `/dev/ttyS0` |
| macOS | `/dev/cu.usbserial-actual-id` | Opening raises an error; specify a real device |

`DeviceName` takes precedence over `PortNo`. Ensure your user can read and write the device. Unix lock files are disabled; do not share a port with another process. Adapters may require OS-specific drivers.

```pascal
// Comm is a field of your form. Create it once and close/free it with the form.
Comm := TCommX.Create(Self);
Comm.DeviceName := '/dev/ttyUSB0'; // COM3 on Windows; an actual /dev/cu.* on macOS
Comm.BitRate := 9600;
Comm.FlowCtrl := cfcNone;          // must match the peer's specification
Comm.OnReceive := @CommReceive;
Comm.PortOpen;
if not Comm.TransString('Hello') then
  ShowMessage('Closed, faulted, or transmit queue full');
```

A receive handler consumes available bytes. The following assumes `Comm: TCommX` is a form field:

```pascal
procedure TMyForm.CommReceive(Sender: TObject; ReceiveSize: Integer);
var
  Data: RawByteString;
  Count: Integer;
begin
  SetLength(Data, ReceiveSize);
  Count := Comm.ReceiveBlock(PChar(Data), Length(Data));
  SetLength(Data, Count);
  // Parse or store Data as bytes. Do not assume a complete protocol frame.
end;
```

`TransString` sends the string's bytes unchanged; it appends no CR/LF or NUL. Lazarus strings are normally UTF-8. Encode explicitly for equipment expecting Shift-JIS or another encoding. Use `TransBlock`/`ReceiveBlock` for binary protocols.

## Migration and limitations

- `TCommX`, `TCustomCommX`, the main methods, events, and enum names are retained. Windows-specific internals and the old worker classes are not.
- Call component methods and change settings on the **LCL main thread**. Close the port before changing settings. `PortClose` waits for the worker to finish and discards queued data.
- `TransBlock` copies the entire request into the bounded application queue or returns `False`; split requests larger than `BufLenTrans`. `True` confirms queuing, not delivery. `GetTransLength = 0` does not mean the OS/adapter has finished transmitting.
- Receive calls are nonblocking: `ReceiveChar` returns `-1` with no data; `ReceiveBlock` returns `0`. `TimeOutReceive` is retained for form compatibility but is not used; manage protocol deadlines in the application.
- `OnReceive` runs on the main thread about every 20 ms while bytes remain queued. Consume them in the handler. `OnError` reports `-1` and `LastErrorText`; legacy Windows `CE_*` masks are not reproduced. Close/reopen after a worker fault.
- RTS/CTS, XON/XOFF, manual RTS/DTR, modem status, and sending BREAK depend on driver support. `cfcHalfHigh`/`cfcHalfLow` use RTS, an output-queue wait, and `HoffDelay`; physical timing needs hardware verification.
- **Automatic DTR/DSR flow control and 1.5 stop bits are Windows-only.** POSIX rejects these settings instead of substituting another mode.
- **Received BREAK notifications (`OnBreak`) are not implemented.** Detailed parity/framing/overrun reporting and disconnect detection are not consistent across the three platforms.
- `BufLenTrans`/`BufLenReceive` are application-queue capacities, not OS-buffer sizes. Keeping a full receive queue can eventually cause data loss in the OS queue.

See [the Japanese guide](README.ja.md#互換性制限) for more detail.

## Tests

```sh
# Lifecycle and failed-open cleanup; does not open a real port.
./tests/CommXSmoke

# Opt-in: two connected test ports; sends all byte values in both directions.
./tests/CommXSmoke /dev/ttyUSB0 /dev/ttyUSB1

# POSIX: create a temporary PTY pair using socat and run the binary test.
python3 tools/pty_smoke.py
```

Build `tests/CommXSmoke.lpi` first. GTK tests need a display; a headless Linux environment can use `xvfb-run -a`. The PTY helper requires `socat`, creates its own temporary devices, and terminates its child process on exit. Physical-line and USB-adapter testing remain manual.

## License and credits

New compatibility implementation, examples, tests, and documentation: [MIT](LICENSE). This grant does not relicense the original Delphi CommX, which is not included. Legacy API attribution: **エックス (KYY06770), CommX 1.05**.

Bundled Synapse/SynaSer sources retain their BSD-style notices; `jedi.inc` retains its MPL-1.1/LGPL alternative notice. See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md), [LICENSES](LICENSES), and [the source manifest](vendor/synapse/UPSTREAM.txt). The component makes no claim of endorsement by the original authors.

Bug reports and contributions: [CONTRIBUTING.md](CONTRIBUTING.md). Changes: [CHANGELOG.md](CHANGELOG.md).
