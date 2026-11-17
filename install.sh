#!/bin/sh
# pomera-btkbd のインストール。Debian化したPomera DM250上で `sudo sh install.sh` で実行する。
set -eu

[ "$(id -u)" -eq 0 ] || { echo "sudo sh $0 で実行してください" >&2; exit 1; }
cd "$(dirname "$0")"
USER_NAME=${SUDO_USER:-}

install -m 755 pomera-btkbd /usr/local/sbin/pomera-btkbd
install -m 755 btkbd /usr/local/bin/btkbd
install -m 644 pomera-btkbd.service /etc/systemd/system/pomera-btkbd.service

# bluetoothd: HIDの受け口を空け、音声系の機能を止める
install -d /etc/systemd/system/bluetooth.service.d
install -m 644 config/bluetooth-override.conf /etc/systemd/system/bluetooth.service.d/pomera-btkbd.conf

# 機器クラスをキーボード(周辺機器)にする
if ! grep -q '^Class = 0x002540' /etc/bluetooth/main.conf; then
    cp -p /etc/bluetooth/main.conf /etc/bluetooth/main.conf.orig
    sed -i 's/^\[General\]$/[General]\nClass = 0x002540/' /etc/bluetooth/main.conf
fi

# BT音声(ハンズフリー等)を止める(ログインユーザーのwireplumber)
if [ -n "$USER_NAME" ]; then
    home=$(getent passwd "$USER_NAME" | cut -d: -f6)
    install -d -o "$USER_NAME" -g "$USER_NAME" "$home/.config/wireplumber/wireplumber.conf.d"
    install -m 644 -o "$USER_NAME" -g "$USER_NAME" config/wireplumber-no-bluetooth.conf \
        "$home/.config/wireplumber/wireplumber.conf.d/80-pomera-no-bluetooth.conf"
fi

# keydの無変換レイヤーに操作キーを追加
KEYD=/etc/keyd/pomera.conf
if [ -f "$KEYD" ] && grep -q '^\[navigation\]' "$KEYD" && ! grep -q 'btkbd' "$KEYD"; then
    cp -p "$KEYD" "$KEYD.orig"
    sed -i '/^\[navigation\]$/r config/keyd-navigation.conf' "$KEYD"
    keyd.rvaiya reload 2>/dev/null || keyd reload 2>/dev/null || true
else
    echo "注意: $KEYD の [navigation] に config/keyd-navigation.conf の内容を手で追加してください"
fi

systemctl daemon-reload
systemctl restart bluetooth
sleep 2
systemctl enable --now pomera-btkbd
echo "インストール完了。無変換+F9でペアリング待ち、無変換+F10で送信先の切り替えです。"
