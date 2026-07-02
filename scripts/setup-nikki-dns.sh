#!/bin/sh
# setup-nikki-dns.sh — задать DNS-резолверы nikki.
#
# Зачем: по умолчанию nikki.mixin.dns_nameserver='0', и генератор конфига
# (/etc/nikki/ucode/mixin.uc) НЕ пишет в mihomo ни одного nameserver → всё
# резолвится с ошибкой "dns resolve failed: couldn't find ip".
#
# Индексы @nameserver[N] соответствуют дефолтным секциям nikki:
#   [0]=default-nameserver  [1]=proxy-server-nameserver
#   [2]=direct-nameserver   [3]=nameserver
# Резолверы подобраны под РФ (Яндекс/Google доступны напрямую); основной — DoH.
set -e

uci set nikki.mixin.dns_nameserver='1'

# default-nameserver (bootstrap, plain UDP)
uci set nikki.@nameserver[0].enabled='1'
uci -q delete nikki.@nameserver[0].nameserver
uci add_list nikki.@nameserver[0].nameserver='77.88.8.8'
uci add_list nikki.@nameserver[0].nameserver='8.8.8.8'

# proxy-server-nameserver (резолв хоста самого прокси-сервера, напрямую)
uci set nikki.@nameserver[1].enabled='1'
uci -q delete nikki.@nameserver[1].nameserver
uci add_list nikki.@nameserver[1].nameserver='77.88.8.8'
uci add_list nikki.@nameserver[1].nameserver='8.8.8.8'

# nameserver (основной, DoH)
uci set nikki.@nameserver[3].enabled='1'
uci -q delete nikki.@nameserver[3].nameserver
uci add_list nikki.@nameserver[3].nameserver='https://1.1.1.1/dns-query'
uci add_list nikki.@nameserver[3].nameserver='https://8.8.8.8/dns-query'

uci commit nikki
/etc/init.d/nikki reload 2>/dev/null || true

echo "DNS настроен. Проверка сгенерированного конфига:"
echo "  sed -n '/^dns:/,/^[^[:space:]]/p' /etc/nikki/run/config.yaml"
