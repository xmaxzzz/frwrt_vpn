# Установка mihomo/nikki на FriendlyWrt (NanoPi R3S) в обход DPI

FriendlyWrt на этом железе — это **OpenWrt 25.12** с пакетным менеджером **apk** (не opkg),
firewall4/nftables, ядро 6.1, TUN встроен. `eth0` по умолчанию WAN, `eth1` — LAN (bridge `br-lan`, 192.168.2.1).

## Почему не «просто opkg install nikki»

Официальный установщик nikki тянет пакеты со своего CDN на `nikkinikki.pages.dev` (Cloudflare Pages),
который **режется DPI** у ряда провайдеров РФ (TLS-handshake не проходит). GitHub при этом доступен —
поэтому ставим из **GitHub-релиза** тарболом с пакетами.

## 1. Установка nikki + mihomo из GitHub-релиза

```sh
cd /tmp
# arch aarch64_generic, ветка openwrt-25.12; версию релиза подставьте актуальную
URL="https://github.com/nikkinikki-org/OpenWrt-nikki/releases/download/v1.26.1/nikki_aarch64_generic-openwrt-25.12.tar.gz"
wget -O nikki.tar.gz "$URL"
mkdir -p nikki-pkg && tar xzf nikki.tar.gz -C nikki-pkg
cd nikki-pkg
# ставим локальные .apk (зависимости kmod-nft-tproxy/yq и т.п. подтянутся из офиц. фида)
apk add --allow-untrusted ./mihomo-meta-*.apk ./nikki-*.apk ./luci-app-nikki-*.apk ./luci-i18n-nikki-ru-*.apk
```

Проверка:
```sh
mihomo -v
apk list -I | grep -iE "nikki|mihomo"
```

Совет: сложите тарбол/`.apk` в персистентный каталог (напр. `/root/nikki-offline/`) — чтобы
переустановка не требовала обхода DPI повторно.

> apk-нюанс (apk-tools 3): архив нужно именно **распаковать**; `apk add ./file.apk` работает по
> путям к распакованным файлам, а `-X <каталог>` ждёт Alpine-`APKINDEX.tar.gz` и не подходит.

## 2. Порты WAN/LAN

Дефолт FriendlyWrt уже верный: `eth0`=WAN (DHCP-клиент), `eth1`=LAN (`br-lan`, 192.168.2.1, DHCP-сервер),
NAT и firewall настроены. Транспарент-прокси в nikki по умолчанию заворачивает зону `lan`
(`nikki.proxy.lan_proxy='1'`, `lan_inbound_interface='lan'`, `tun_enabled='1'`).

## 3. DNS (обязательно) и веб-форма

```sh
sh scripts/setup-nikki-dns.sh     # без этого mihomo не резолвит имена
sh scripts/setup-webform.sh       # форма «добавить сервер по ссылке» (LAN only)
```

## 4. Добавить сервер и включить

* Через веб-форму `http://192.168.2.1:9080/` (вставить `vless://`/`hysteria2://`/`trojan://`), **или**
* вручную в `/etc/nikki/profiles/local.yaml` (см. `config/profile.example.yaml`),
  профиль выбирается как `uci set nikki.config.profile='file:local.yaml'`.

Включить:
```sh
uci set nikki.config.enabled='1'; uci commit nikki
/etc/init.d/nikki enable
/etc/init.d/nikki start
```

## 5. Диагностика

```sh
# что реально сгенерилось (DNS должен содержать nameserver'ы!)
sed -n '/^dns:/,/^[^[:space:]]/p' /etc/nikki/run/config.yaml
# логи ядра
tail -f /var/log/nikki/core.log
# резолвер mihomo через API
curl -s -H "Authorization: Bearer <API_SECRET>" "http://127.0.0.1:9090/dns/query?name=www.google.com&type=A"
```
