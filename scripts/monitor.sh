#!/bin/bash
# 院内LLM監視スクリプト
# crontab: */5 * * * * /usr/local/bin/monitor.sh

ADMINS=("管理者1の電話番号" "管理者2の電話番号")
LOG="/var/log/llm_monitor.log"
DATE=$(date '+%Y-%m-%d %H:%M:%S')

send_imessage() {
  local msg="$1"
  for num in "${ADMINS[@]}"; do
    osascript -e "tell application \"Messages\"
      set s to 1st service whose service type = iMessage
      set b to buddy \"$num\" of s
      send \"$msg\" to b
    end tell"
  done
}

# Ollama死活確認
if ! pgrep -x "ollama" > /dev/null; then
  send_imessage "⚠️ [院内LLM] ${DATE} Ollamaが停止しています。自動再起動を試みます。"
  echo "$DATE | ERROR: Ollama stopped" >> $LOG
fi

# メモリ使用率90%超
MEM_USED=$(vm_stat | awk '/Pages active/{a=$3} /Pages wired/{w=$4} END{print a+w}' | tr -d '.')
MEM_TOTAL=$(sysctl -n hw.memsize)
MEM_PCT=$(echo "scale=0; $MEM_USED * 16384 * 100 / $MEM_TOTAL" | bc)
if [ "$MEM_PCT" -gt 90 ]; then
  send_imessage "⚠️ [院内LLM] ${DATE} メモリ使用率${MEM_PCT}%。確認してください。"
  echo "$DATE | WARNING: Memory ${MEM_PCT}%" >> $LOG
fi

# 異常な外部通信を検知
EXTERNAL=$(sudo lsof -i -n -P | grep ESTABLISHED \
  | grep -v "100\.64\." \
  | grep -v "127\.0\.0\.1" \
  | grep -v "192\.168\.")
if [ -n "$EXTERNAL" ]; then
  send_imessage "🚨 [院内LLM] ${DATE} 不審な外部通信を検知！即座に確認してください。"
  echo "$DATE | CRITICAL: External connection detected" >> $LOG
fi

echo "$DATE | OK" >> $LOG
