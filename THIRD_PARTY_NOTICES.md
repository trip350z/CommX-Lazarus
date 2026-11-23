# Third-party notices

## Legacy API attribution

The public API is inspired by **CommX 1.05**, by **エックス (KYY06770)**, dated 2000-01-15 in the supplied Delphi source. This repository contains a new LCL implementation and does not include the original Delphi PAS, DCU, or DCR. No license for that original distribution is asserted here, and the repository's MIT license does not apply to it.

## Synapse / SynaSer

- Upstream: <https://github.com/geby/synapse>
- Files: `vendor/synapse/synaser.pas`, `synafpc.pas`, `synautil.pas`
- Copyright: Lukas Gebauer and the contributors identified in each file.
- Terms: the BSD-style redistribution notices and disclaimers embedded in the source files. A copy of those notices is collected in [LICENSES/Synapse.txt](LICENSES/Synapse.txt).
- Local patch: POSIX `fpOpen` adds `O_NONBLOCK` to avoid waiting for carrier detect before serial configuration. The original notices remain intact.
- Provenance and byte hashes: [UPSTREAM.txt](vendor/synapse/UPSTREAM.txt).

Preserve the upstream notices and include them in documentation accompanying binary distributions, as required by those notices.

## Project JEDI compiler definitions

- File: `vendor/synapse/jedi.inc`
- Initial developer: Project JEDI, <https://www.delphi-jedi.org/>
- Original notice: Mozilla Public License 1.1, with an alternative LGPL grant as stated in the file.
- This repository distributes the unchanged file under the MPL-1.1 option. [The MPL-1.1 text](LICENSES/MPL-1.1.txt) is included; the original alternative-license notice is retained.

The corresponding source is included in this repository. Distributors remain responsible for complying with the applicable terms for the specific files they distribute. This notice does not replace the original file-level notices.
