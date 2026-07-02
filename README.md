# frwrt_vpn — FriendlyWrt + mihomo VPN-шлюз с добавлением серверов по ссылке

Набор наработок для превращения мини-роутера **NanoPi R3S LTS** (Rockchip RK3566, 2 порта Ethernet)
на **FriendlyWrt (OpenWrt 25.12, apk)** в прозрачный VPN-шлюз на **mihomo/nikki**:

* `eth0` = **WAN** (DHCP, обычный интернет)
* `eth1` = **LAN** — весь трафик клиентов заворачивается в прокси (hysteria2/vless/trojan) через TUN
* **веб-форма** для LAN, где сервер добавляется одной ссылкой `vless://` / `hysteria2://` / `trojan://`
  (без Sub-Store / Node / Docker — просто CGI на uhttpd)

> Собрано и проверено на реальном железе. Ориентировано на работу из РФ, где часть источников
> (Cloudflare Pages и т.п.) режется DPI — поэтому пакеты ставятся из GitHub-релизов, а не с CDN.

## Архитектура

```
[интернет] ──▶ eth0 (WAN, DHCP)
                    │
              ┌─────┴─────┐
              │  mihomo   │  TUN + fake-ip, транспарент-прокси
              │  (nikki)  │  ← профиль /etc/nikki/profiles/local.yaml
              └─────┬─────┘
                    │
   eth1 (LAN 192.168.2.1) ──▶ клиенты — весь трафик через VPN

  Веб-форма «добавить сервер по ссылке»:
  http://192.168.2.1:9080/  (отдельный uhttpd, только LAN)  ──▶ дописывает узел в local.yaml
```

## Состав репозитория

| Путь | Что это |
|------|---------|
| `webform/addnode` | CGI-скрипт (bash): парсит share-ссылку → YAML-узел mihomo, дописывает в профиль, релоадит nikki |
| `webform/index.html` | редирект на форму |
| `scripts/setup-webform.sh` | ставит форму на отдельный LAN-only экземпляр uhttpd |
| `scripts/setup-nikki-dns.sh` | чинит DNS-резолверы nikki (иначе `dns resolve failed`) |
| `config/profile.example.yaml` | пример локального профиля nikki (плейсхолдеры, без секретов) |
| `install/INSTALL.md` | полная установка: nikki из GitHub-релиза (обход DPI) + настройка WAN/LAN |

## Быстрый старт (кратко)

1. Прошить microSD официальным образом **FriendlyWrt для NanoPi R3S** (Balena Etcher), загрузиться.
2. Поставить mihomo/nikki из GitHub-релиза — см. [`install/INSTALL.md`](install/INSTALL.md).
3. Скопировать этот репозиторий на роутер и выполнить:
   ```sh
   sh scripts/setup-nikki-dns.sh          # DNS-резолверы
   sh scripts/setup-webform.sh            # веб-форма на http://192.168.2.1:9080/
   ```
4. Открыть с LAN `http://192.168.2.1:9080/`, вставить ссылку сервера — готово.

## Два подводных камня (важно)

Оба лечатся скриптами/формой из репозитория; описаны, чтобы понимать «почему».

1. **Пустые DNS-резолверы у nikki.** По умолчанию `nikki.mixin.dns_nameserver='0'`, и генератор
   (`/etc/nikki/ucode/mixin.uc`) **не пишет в конфиг mihomo ни одного nameserver** → любое имя не
   резолвится (`dns resolve failed: couldn't find ip`). Лечит `scripts/setup-nikki-dns.sh`.

2. **Резолв домена самого прокси-сервера.** mihomo зацикливается, пытаясь отрезолвить *домен*
   прокси-сервера через ещё не поднятый туннель. Решение — использовать **IP** сервера
   (`server: <IP>`) и оставить домен в `sni:`. Веб-форма делает это автоматически (резолвит домен
   в IP при добавлении и подставляет `sni`).

## Проверка

```sh
# статус узла и выход
curl -s -H "Authorization: Bearer <API_SECRET>" \
  "http://127.0.0.1:9090/proxies/<NODE>/delay?timeout=8000&url=http://cp.cloudflare.com/generate_204"
# внешний IP через прокси (порт mixed, если включена авторизация — user:pass)
curl -x http://<user>:<pass>@127.0.0.1:7890 -s https://api.ipify.org
```

## Безопасность

* Веб-форма слушает **только LAN** и работает от root — не выставляйте её на WAN.
* Реальные конфиги с паролями (`/etc/nikki/profiles/local.yaml`, `api_secret`, пароль формы)
  **в репозиторий не коммитятся** (см. `.gitignore`). Здесь только шаблоны с плейсхолдерами.
