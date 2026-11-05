#!/bin/bash
# ngan-watchdog: tự chăm sóc OpenClaw (gateway + telegram) và alert qua bot media_download
export PATH="$HOME/.local/bin:$HOME/.npm-global/bin:/snap/bin:$PATH"
CHAT="${NGAN_OWNER_CHAT_ID:?set owner chat id}"
TOKEN=$(grep -oP '^TELEGRAM_BOT_TOKEN=\K.*' "$HOME/media_download/.env" 2>/dev/null | head -1)
STATE=/tmp/ngan-watchdog.state
RSTATE=/tmp/ngan-watchdog.reset
alert() {
  [ -n "$TOKEN" ] && curl -s --max-time 10 "https://api.telegram.org/bot$TOKEN/sendMessage" \
    --data-urlencode "chat_id=$CHAT" --data-urlencode "text=$1" >/dev/null 2>&1
  logger -t ngan-watchdog "$1"
}
FIXED=0
GW=$(systemctl --user is-active openclaw-gateway.service)
if [ "$GW" != "active" ]; then
  systemctl --user start openclaw-gateway.service
  sleep 20
  GW=$(systemctl --user is-active openclaw-gateway.service)
  if [ "$GW" = "active" ]; then alert "🛡 Ngan bị dừng — đã tự khởi động lại gateway ✅"; FIXED=1
  else alert "🛡⚠️ Ngan KHÔNG khởi động được (status=$GW) — cần kiểm tra tay!"; fi
fi
if [ "$GW" = "active" ]; then
  J=$(journalctl --user -u openclaw-gateway.service --since '-10 min' --no-pager 2>/dev/null)
  if echo "$J" | grep -q 'refusing automatic start for telegram'; then
    openclaw gateway call channels.start --params '{"channel":"telegram"}' >/dev/null 2>&1
    alert "🛡 Kênh Telegram của Ngan bị breaker chặn — đã tự bật lại ✅"
    FIXED=1
  fi
  ERRS=$(echo "$J" | grep -cE 'Unknown model:|authentication failed, HTTP 401')
  if [ "${ERRS:-0}" -ge 5 ]; then
    NOW=$(date +%s); LAST=$(cat "$STATE" 2>/dev/null || echo 0)
    if [ $((NOW - LAST)) -gt 1800 ]; then
      echo "$NOW" > "$STATE"
      systemctl --user restart openclaw-gateway.service
      sleep 15
      openclaw gateway call channels.start --params '{"channel":"telegram"}' >/dev/null 2>&1
      alert "🛡⚠️ Ngan có $ERRS lỗi model/auth trong 10 phút — đã restart gateway + nối lại kênh. Nếu lặp lại thì cần xử lý gốc (key hết hạn / catalog)."
    fi
  fi
  # Cuộc hội thoại CLI (agy) hỏng → mọi lượt resume trả 400 → tự /new
  NOW=$(date +%s); LASTR=$(cat "$RSTATE" 2>/dev/null || echo 0)
  SINCE=$((NOW - 10800)); [ "$LASTR" -gt "$SINCE" ] && SINCE=$LASTR
  BAD=$(journalctl --user -u openclaw-gateway.service --since "@$SINCE" --no-pager 2>/dev/null \
    | grep 'cli terminal failure' | grep -c 'INVALID_ARGUMENT (code 400)')
  if [ "${BAD:-0}" -ge 2 ]; then
    echo "$NOW" > "$RSTATE"
    if openclaw gateway call sessions.reset --params '{"key":"agent:main:main"}' >/dev/null 2>&1; then
      alert "🛡 Phiên chat của Ngan bị hỏng ($BAD lượt lỗi 400 INVALID_ARGUMENT) — đã tự /new ✅. Ngan quên ngữ cảnh chat gần đây; việc đang dở thì anh nhắc lại nhé."
    else
      alert "🛡⚠️ Phiên chat của Ngan bị hỏng (lỗi 400) nhưng tự /new THẤT BẠI — anh gõ /new trong chat Ngan giúp em."
    fi
  fi
fi
exit 0
