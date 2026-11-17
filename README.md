# pomera-btkbd

Debian化した **KING JIM ポメラ DM250** を、iPadなどにつなげる **Bluetoothキーボード** にする常駐プログラムです。

ポメラ側の [keyd](https://github.com/rvaiya/keyd) で入れ替えたキー配列(大西配列など)を**そのまま**送るので、相手の端末側では配列の設定をしなくても同じ配列で打てます。

## できること

- クラシックBluetoothのHIDキーボードとして、iPad・Mac・Windows・Androidなどにつながる
- 送信中はポメラ自身のターミナルに文字が入らない(入力デバイスを独占)
- 送信中は**画面(バックライト)とWi-Fiを自動で切って**電池を節約。ポメラに戻すと復帰
- 右シフトと左Alt(DM250ではキーボード本体ではなく gpio-keys から来る)も送る
- 日本語入力の切り替え用に **iPadの地球儀キー** を送る
- 最後につないだ相手に、こちらから自動で再接続する(送信モード中は5秒ごとに再試行)

## 操作

| 操作 | キー |
|---|---|
| ペアリング待ち(2分間) | `無変換` + `F9` |
| 相手に送る ⇔ ポメラで使う | `無変換` + `F10` |
| 地球儀キー(英字⇔日本語) | `無変換`(単独)／`変換`／`カタカナひらがな` |

コマンドでも操作できます: `btkbd pair` / `btkbd toggle` / `btkbd remote` / `btkbd local` / `btkbd status`

`btkbd status` の結果(`BT:-`、`BT:ペアリング待ち`、`BT:送信中`、`BT:接続待ち` など)は `/run/pomera-btkbd/state` にあるので、GNU screen のステータス行などに出せます。

```
backtick 3 2 2 /usr/local/bin/btkbd status
```

## 前提

- [EKESETE さんの DM250 用 Debian イメージ](https://www.ekesete.net/log/?p=9565)(20261010版、Debian 13 / Linux 6.18)で確認
- keyd が動いていて、`/etc/keyd/pomera.conf` に `無変換` の `[navigation]` レイヤーがあること(上記イメージの標準設定)
- python3-dbus、python3-gi、hciconfig(bluez)

## インストール

```sh
sudo sh install.sh
```

次のことを行います。

- `pomera-btkbd`(本体)、`btkbd`(操作コマンド)、systemdサービスの設置
- bluetoothd の `input` プラグインを無効化(HIDの受け口 PSM 17/19 をこのプログラムが使うため)
- bluetoothd の `a2dp`、`avrcp`、`sap`、`midi` と wireplumber の Bluetooth を無効化(相手にスピーカーやヘッドセットと誤認されないため)
- 機器クラスをキーボード(`0x002540`)に設定
- keyd の `[navigation]` に `F9`／`F10` の操作を追加

## 相手の端末での設定

- キーボードの配列設定は **英語(US)** にしてください。ポメラは US 配列として送ります。
- iPad では、日本語入力を使うなら「日本語 - ローマ字入力」キーボードを追加しておいてください。

## 制限

- **ポメラ側で Bluetooth のキーボード・マウス・オーディオは使えなくなります。**
- iPad の Termius は、外付けキーボードからの日本語(未確定文字)入力に対応していないため、アルファベットしか入りません(アプリ側の制限)。メモなど通常のアプリでは日本語を入力できます。
- 英数／かなキー(HID の LANG2/LANG1)は、配列を US に設定した iPad では無視されたため、地球儀キー方式にしています。
- HID の仕様(ディスクリプタ)を変更した場合は、相手の端末でいったん登録を解除してペアリングし直す必要があります。

## 仕組み

- BlueZ の `ProfileManager1` に HID の SDP レコードを登録し、L2CAP の PSM 17(制御)と 19(割り込み)を自前で待ち受けます。
- 入力は `keyd virtual keyboard`(keyd で入れ替えた後のキー)を `EVIOCGRAB` で独占して読み、HID のキーボードレポート(レポートID 1)に変換して送ります。地球儀キーは Consumer Control(レポートID 2、Usage `0x029D`)です。
- ペアリングは NoInputNoOutput のエージェントで自動承認します(ペアリング待ちの2分間のみ検出可能)。

## デバッグ

`sudo touch /run/pomera-btkbd/debug` で、送ったキーを journal に記録し、送信中も Wi-Fi を切らなくなります(SSH で様子を見るため)。

```sh
sudo journalctl -u pomera-btkbd -f
```

## ライセンス

MIT
