# CommX Lazarus / LCL版

[English](README.md) · [GitHub](https://github.com/trip350z/CommX-Lazarus) · [ビルド状況](https://github.com/trip350z/CommX-Lazarus/actions/workflows/build.yml)

Delphi用CommX 1.05（原作者: エックス / KYY06770）のAPIに合わせて新たに実装したLCL互換コンポーネントです。通信処理はSynaSerを使用します。旧Delphi版のPAS / DCU / DCRはこのリポジトリに含めません。
Windows・Linux・macOSでビルドするソース構成を用意しています。CIではWindows x64、Linux GTK2、macOS Intel Cocoaのビルドとテストを実行します。実機通信とApple Siliconでの検証状況は別です。最新の結果は上の「ビルド状況」を確認してください。

## インストール

1. このCommXフォルダー全体をコピーします。vendor/synapseも必要です。
2. Lazarusの「パッケージ → パッケージファイルを開く」でcommxlcl.lpkを開きます。
3. コンパイルし、「使用 → インストール」でIDEを再構築します。
4. LIB-XパレットにTCommXが追加されます。

WindowsではPowerShellから `./build.ps1 -WidgetSet win32` でも一式をビルドできます。lazbuildがPATHにない場合は `-LazBuild` で実行ファイルを指定します。

IDEへの登録なしでも使えます。CommXフォルダーとvendor/synapseをプロジェクトのユニット検索パスに、vendor/synapseをインクルード検索パスに追加してください。
DCUは流用せずPASからビルドします。DCRのアイコンは使用していません。
同梱SynaSerのソース・ライセンス表記はvendor/synapse内に保持し、取得元とSHA-256をUPSTREAM.txtに記録しています。POSIXでオープン時のキャリア待ちを防ぐため、SynaSerのfpOpenにO_NONBLOCKを追加する最小修正を加えています。

## OS別のポート指定

| OS | DeviceNameの例 | 未指定の場合 |
| --- | --- | --- |
| Windows | COM3 | PortNo=3ならCOM3 |
| Linux | /dev/ttyUSB0、/dev/ttyACM0 | PortNo=1なら/dev/ttyS0 |
| macOS | /dev/cu.usbserial-実際の識別子 | エラー。明示指定が必要 |

DeviceNameを指定した場合はPortNoより優先します。
Linuxではデバイスに読み書きできるユーザー権限が必要です。所属グループなどはディストリビューションの設定を確認してください。
macOSでは実在する/dev/cu.*を指定し、アダプターに必要なドライバーを用意します。
SynaSerの/var/lockによるロックは無効化しています。特にPOSIXでは他のアプリと同じポートを同時に開かないでください。

```pascal
uses CommX;

// フォームのフィールドとして保持する例
Comm := TCommX.Create(Self);
Comm.DeviceName := '/dev/ttyUSB0'; // Windows: COM3 / macOS: /dev/cu.*
Comm.BitRate := 9600;
Comm.FlowCtrl := cfcNone; // 相手機器の仕様に合わせる
Comm.OnReceive := @CommReceive;
Comm.PortOpen;
if not Comm.TransString('Hello') then
  ShowMessage('ポート未接続・エラー状態・送信キュー満杯のいずれかです');
```

OnReceiveではReceiveSizeを上限にバッファを確保し、ReceiveBlockで取り出します。
バイナリにはTransBlock / ReceiveBlockを使ってください。サンプルの受信表示は16進数です。
TransStringは文字コードを変換しません。LazarusのUTF-8文字列をそのまま送るため、Shift-JISの機器には呼び出し側で変換が必要です。
文字列末尾にCR/LFやNULを自動追加しません。

## ビルドとサンプル

| OS | 対象 | プロジェクト |
| --- | --- | --- |
| Windows | win32（64bitアプリでもこのウィジェット名） | demo/CommXDemo.lpi |
| Linux | gtk2 / qt5 / qt6 | demo/CommXDemo.lpi |
| macOS | cocoa | demo/CommXDemoMac.lpi |

各OS・CPU向けのLazarus / FPC、対象ウィジェットセットのLCLと開発用ライブラリを用意します。
Qt版には対応するQtバインディングも必要です。macOSではXcode Command Line Tools / macOS SDKが必要です。
Apple SiliconとIntelは、それぞれのCPU向け環境で別々にビルドします。
ソースのファイル名の大文字・小文字を保持してください。

Linux（CommXフォルダー内）:

```sh
sh build.sh gtk2
# または sh build.sh qt5 / sh build.sh qt6
./demo/CommXDemo
```

macOS:

```sh
sh build.sh cocoa
open demo/CommXDemo.app
```

lazbuildがPATHにない場合はLazarusのインストール先をPATHに追加します。
スクリプトは各OS上のネイティブビルド用です。署名・公証やクロスコンパイラの導入は行いません。
サンプルはOpenボタンを押したときだけ指定ポートを開き、Sendボタンで入力文字列をそのまま送ります。初期設定は9600 / 8N1 / フロー制御なしです。

## 互換性・制限

| 機能 | 実装 |
| --- | --- |
| TCommX / TCustomCommX、主要メソッド・列挙型 | 名前を維持 |
| PortOpen / PortClose | 送受信ワーカーを開始・停止。PortCloseは繰り返し呼び出し可 |
| TransChar / TransString / TransBlock | 非同期キューへのコピー。Trueは受付成功で、相手への到達確認ではない |
| ReceiveChar / ReceiveBlock | 内部受信キューから即時取得。データなしは-1 / 0 |
| OnReceive / OnError | LCLのメインスレッドで通知 |
| RTS/CTS、XON/XOFF、制御なし | 各OSのドライバーを利用 |
| 手動RTS/DTR、CTS/DSR/RING/RLSD照会 | OS API経由。機器・ドライバーが未対応ならエラーになる場合あり |
| cfcHalfHigh / cfcHalfLow | RTSで方向切り替え、OS送信キュー排出待ち＋HoffDelay後に復帰 |
| cfcDtrDsr | Windowsのみ。Linux/macOSではPortOpenで例外 |
| csb1p5 | Windowsのみ。POSIXで1.5ビットを2ビットに置換しないため例外 |
| SendBreak | 約300msのBREAK送出をOSに要求 |
| OnBreak | フォーム互換用に保持。受信BREAK通知は未実装 |

元実装からの動作変更:

- 設定プロパティはポートを閉じてから変更します。開いたままの変更は例外になります。
- BufLenTrans / BufLenReceiveは移植版の内部キュー容量です。OSのバッファ容量指定とは異なります。
- TransBlockはキュー容量を超える要求をFalseで返します。部分的に受け付けません。大きなデータは呼び出し側で分割し、GetTransLengthなどで空きを確認します。
- GetTransLengthはアプリ内の送信待ちバイト数です。0でもOS・USBアダプターにデータが残る可能性があります。
- TimeOutTransはワーカーの送信進行・半二重排出待ちのタイムアウトです。送信エラー時はワーカーを停止し、未送信分を保持します。復旧はPortClose → PortOpenで行います。既に送信された範囲が不明な機器では、プロトコル側で再送を判断します。
- TimeOutReceiveは既存フォームの読み込み用に保持しますが、即時取得型の受信では使用しません。フレームの受信期限は呼び出し側で管理してください。
- OnReceiveは受信キューにデータがある間、約20msごとに通知します。ハンドラーで受信データを消費してください。
- OnErrorのErrorStateは移植版では-1（通信ワーカー停止）です。説明はLastErrorTextで確認します。元のWindows CE_*ビットマスクとは互換ではありません。
- パリティ・フレーミング・BREAK受信の詳細な検出は3OS共通では実装していません。物理切断やOS受信バッファのオーバーフローも全ケースで検出できるとは限りません。
- ClearTransBuf / ClearReceiveBufは対応する方向のキューだけを消去します。送信済みのバイトは取り消せません。
- クローズや信号操作は進行中のI/Oの終了待ちになることがあります。通信設定と全コンポーネントメソッドはLCLメインスレッドから呼び出してください。
- 受信キューが満杯の場合、ワーカーはOS側にデータを残して待ちます。アプリ側で受信を放置するとOS側で欠落する可能性があります。
- 半二重の切り替え時刻はリアルタイム保証ではありません。USB変換器の末尾バイト送出時間を考慮してHoffDelayを調整し、実機で確認してください。RTSを制御できないアダプターでは使用できません。
- 旧版の送受信スレッドクラスとWindows固有のprotectedフィールドは移植対象外です。Handleは実行時の読み取り専用プロパティです。

## 検証

Windows x64 / Free Pascal 3.2.2で、LazarusパッケージとGUIサンプル・テストのコンパイルを実施しています。
実ポートを使わないテスト（生成・破棄、閉じたポートでの操作、存在しないデバイスへの接続失敗を繰り返した後の後始末）はPASSです。
同梱SynaSerには既存の非推奨シンボル警告が3件あります。
公開準備時点のローカル検証はWindowsです。Linux・macOSはGitHub Actionsで検証します。IDEへのインストールと実機シリアル通信は未検証です。CIのPTY試験は物理RTS/DTRやUSBタイミングを保証するものではありません。

テストはtests/CommXSmoke.lpiからビルドできます。引数なしでは実在するポートに接続しません。
2つの引数に接続済みのポート対を指定すると、全256バイト値の双方向転送と再オープンも検証します。
試験ポートの先には試験用ケーブルまたは仮想ポート対を使用してください。

```sh
./tests/CommXSmoke
./tests/CommXSmoke /dev/ttyUSB0 /dev/ttyUSB1
```

Linux/macOSでは `python3 tools/pty_smoke.py` で一時的なPTY対を自動作成して試験できます（要socat）。GTKのヘッドレス環境では `xvfb-run -a python3 tools/pty_smoke.py` を使用します。

手動でsocatのPTY対を作って基本送受信を検証することもできます（RTS/DTRなどの物理制御の検証には使えません）。

```sh
socat -d -d pty,raw,echo=0 pty,raw,echo=0
# 表示された2つのPTY名を指定
./tests/CommXSmoke /dev/pts/3 /dev/pts/4
```

最終確認では接続先に合わせたボーレート・パリティ・ストップビット、USBアダプターでのRTS/DTR、抜き差し、連続受信、送受信中のクローズを各OSで確認してください。

通信バックエンドの対応環境とAPIは[SynaSer公式ソース](https://github.com/geby/synapse/blob/master/synaser.pas)に基づいています。

## 公開ライセンスとクレジット

今回新規に作成したLCL互換実装、サンプル、テスト、ビルドスクリプト、説明書は[MITライセンス](LICENSE)です。この許諾は旧Delphi版CommXの再ライセンスを意味しません。
APIの出典としてエックス（KYY06770）氏のCommX 1.05を記載しています。
同梱SynaSer/Synapseは各ファイルのBSD系条件、jedi.incは元のMPL-1.1/LGPL選択条項を保持しています。この配布ではMPL-1.1側でjedi.incを同梱します。
詳細は[第三者ライセンス表記](THIRD_PARTY_NOTICES.md)と[LICENSES](LICENSES)を参照してください。

不具合報告・開発への参加方法は[CONTRIBUTING.md](CONTRIBUTING.md)、変更履歴は[CHANGELOG.md](CHANGELOG.md)にまとめています。
