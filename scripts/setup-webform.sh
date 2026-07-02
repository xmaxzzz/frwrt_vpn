#!/bin/sh
# setup-webform.sh — установить веб-форму «добавить сервер по ссылке»
# на ОТДЕЛЬНЫЙ экземпляр uhttpd, слушающий только LAN.
#
# Запускать из корня репозитория, скопированного на роутер:
#   sh scripts/setup-webform.sh [LAN_IP] [PORT]
# По умолчанию: 192.168.2.1:9080
set -e

LAN_IP="${1:-192.168.2.1}"
PORT="${2:-9080}"
HERE="$(cd "$(dirname "$0")/.." && pwd)"

install -d /www-addnode/cgi-bin
install -m 0755 "$HERE/webform/addnode"      /www-addnode/cgi-bin/addnode
install -m 0644 "$HERE/webform/index.html"   /www-addnode/index.html
sed -i 's/\r$//' /www-addnode/cgi-bin/addnode   # на случай CRLF

uci -q delete uhttpd.addnode
uci set uhttpd.addnode=uhttpd
uci set uhttpd.addnode.listen_http="$LAN_IP:$PORT"
uci set uhttpd.addnode.home='/www-addnode'
uci set uhttpd.addnode.cgi_prefix='/cgi-bin'
uci set uhttpd.addnode.index_page='index.html'
uci set uhttpd.addnode.script_timeout='60'
uci set uhttpd.addnode.no_dirlists='1'
uci commit uhttpd
/etc/init.d/uhttpd reload

echo "Готово. Веб-форма: http://$LAN_IP:$PORT/  (доступна только из LAN)"
echo "Требуется: /etc/nikki/profiles/local.yaml с группой PROXY (см. config/profile.example.yaml)"
