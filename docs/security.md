# 院内ローカルLLM 監視・自動化・遠隔管理 設計書
**作成日**: 2026-02-28
**対象**: Mac mini 2018（DMZ内 LLMサーバー）

---

## 全体構成

```
Mac mini（DMZ内）
  ├── Netdata（監視ダッシュボード） ← ブラウザで管理者全員が見える
  ├── launchd（Ollama自動再起動）
  ├── 異常検知スクリプト（5分ごと自動実行）
  ├── iMessage自動アラート → 管理者全員に通知
  └── Tailscale SSH（システム管理者のみ遠隔停止可能）
```

---

## 1. 遠隔アクセス：Tailscale（VPNハッキング対策済み）

### 従来VPN vs Tailscale

| | 従来VPN | Tailscale |
|:|:--------|:----------|
| プロトコル | OpenVPN・IPSec（古い） | WireGuard（最新・最小） |
| ポート公開 | インターネットに開放 ❌ | **開放ポートゼロ** ✅ |
| 認証 | ID/パスワード | Google/AppleID（2FA必須） |
| ハッキング事例 | 病院被害多数 | 事例ほぼなし |
| iPhone対応 | △ 設定が複雑 | ✅ アプリ1つ |
| 料金 | 有料が多い | ✅ 個人無料 |

### セットアップ手順

```bash
# Mac mini側
brew install tailscale
sudo tailscale up
tailscale ip   # → IPアドレスをメモ（例: 100.64.x.x）
```

iPhone：App Store → 「Tailscale」インストール → 同じGoogleアカウントでログイン

SSH接続（iPhoneアプリ「Termius」または「ShellFish」）：
```
ホスト: 100.64.x.x
ポート: 22
認証:   鍵認証（パスワード認証は無効化）
```

### パスワード認証の無効化（必須）

```bash
sudo nano /etc/ssh/sshd_config
# 以下に変更：
PasswordAuthentication no
PubkeyAuthentication yes
PermitRootLogin no

sudo launchctl kickstart -k system/com.openssh.sshd
```

### DMZで必要な通信許可（IT担当者へ依頼）

```
送信先: *.tailscale.com
ポート: TCP 443 / UDP 41641（送信のみ・受信不要）
```

---

## 2. ホワイトリスト（ネットワーク設計）

| 方向 | 送信元 | 宛先ポート | 許可/拒否 | 理由 |
|:-----|:-------|:---------|:---------|:-----|
| 受信 | 管理者PC（固定IP） | 22（SSH） | ✅ 許可 | 監視・メンテ |
| 受信 | 使用端末（固定IP） | 11434（Ollama API） | ✅ 許可 | LLM呼び出し |
| 受信 | 19999（Netdata） | 院内LAN全体 | ✅ 許可 | ダッシュボード閲覧 |
| 受信 | その他すべて | 全ポート | ❌ 拒否 | |
| 送信 | Mac mini | 全て（Tailscale以外） | ❌ 拒否 | 完全閉域 |

### macOSファイアウォール設定

```bash
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --add /usr/local/bin/ollama
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --unblockapp /usr/local/bin/ollama
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --list
```

---

## 3. 監視ダッシュボード：Netdata

### インストール（1行）

```bash
brew install netdata
brew services start netdata
```

### 閲覧URL（管理者全員に共有）

```
http://100.64.x.x:19999
```

アプリ不要・ログイン不要でブラウザから誰でも見える。

### 表示内容

- CPU・メモリ・ディスク使用率（リアルタイム）
- ネットワークトラフィック（in/out）
- プロセス一覧（Ollamaが動いているか）
- 異常なスパイクの履歴

---

## 4. Ollama自動再起動（launchd）

`/Library/LaunchDaemons/com.hospital.ollama.plist` を作成：

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.hospital.ollama</string>
  <key>ProgramArguments</key>
  <array>
    <string>/usr/local/bin/ollama</string>
    <string>serve</string>
  </array>
  <key>KeepAlive</key>
  <true/>
  <key>RunAtLoad</key>
  <true/>
  <key>StandardOutPath</key>
  <string>/var/log/ollama.log</string>
  <key>StandardErrorPath</key>
  <string>/var/log/ollama_error.log</string>
</dict>
</plist>
```

```bash
sudo launchctl load /Library/LaunchDaemons/com.hospital.ollama.plist
```

---

## 5. 異常検知 → iMessage自動アラート

`/usr/local/bin/monitor.sh` として保存：

```bash
#!/bin/bash

ADMINS=("09066984668" "管理者2の番号" "管理者3の番号")
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
  MSG="⚠️ [院内LLM] $DATE
Ollamaが停止しています。自動再起動を試みます。"
  send_imessage "$MSG"
  echo "$DATE | ERROR: Ollama stopped" >> $LOG
fi

# メモリ使用率90%超
MEM_USED=$(vm_stat | awk '/Pages active/{a=$3} /Pages wired/{w=$4} END{print a+w}' | tr -d '.')
MEM_TOTAL=$(sysctl -n hw.memsize)
MEM_PCT=$(echo "scale=0; $MEM_USED * 16384 * 100 / $MEM_TOTAL" | bc)

if [ "$MEM_PCT" -gt 90 ]; then
  MSG="⚠️ [院内LLM] $DATE
メモリ使用率が${MEM_PCT}%です。確認してください。"
  send_imessage "$MSG"
  echo "$DATE | WARNING: Memory ${MEM_PCT}%" >> $LOG
fi

# 異常な外部通信を検知
EXTERNAL=$(sudo lsof -i -n -P | grep ESTABLISHED \
  | grep -v "100\.64\." \
  | grep -v "127\.0\.0\.1" \
  | grep -v "192\.168\.")
if [ -n "$EXTERNAL" ]; then
  MSG="🚨 [院内LLM] $DATE
不審な外部通信を検知しました！
$EXTERNAL
即座に確認してください。"
  send_imessage "$MSG"
  echo "$DATE | CRITICAL: External connection detected" >> $LOG
fi

echo "$DATE | OK" >> $LOG
```

```bash
chmod +x /usr/local/bin/monitor.sh

# 5分ごとに自動実行
crontab -e
# 以下を追加：
*/5 * * * * /usr/local/bin/monitor.sh
```

---

## 6. 異常パケット自動遮断

`/usr/local/bin/block_suspicious.sh`：

```bash
#!/bin/bash
ALLOWED_PREFIXES=("100.64." "192.168." "127.0.0.1")

sudo lsof -i -n -P | grep ESTABLISHED | while read line; do
  IP=$(echo $line | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | tail -1)
  ALLOWED=false
  for prefix in "${ALLOWED_PREFIXES[@]}"; do
    if [[ "$IP" == $prefix* ]]; then
      ALLOWED=true; break
    fi
  done
  if [ "$ALLOWED" = false ] && [ -n "$IP" ]; then
    sudo /sbin/pfctl -t blocked -T add "$IP"
    echo "$(date) | BLOCKED: $IP" >> /var/log/blocked_ips.log
  fi
done
```

---

## 7. アラートレベルの定義

| レベル | 条件 | 自動対応 | 通知 |
|:-------|:-----|:---------|:-----|
| 🟢 正常 | 全項目問題なし | なし | なし |
| 🟡 警告 | メモリ80%超・CPU高負荷 | ログ記録 | iMessage |
| 🔴 異常 | Ollama停止・外部通信 | 自動再起動 | iMessage全員 |
| 🚨 緊急 | 不審パケット多数検知 | 自動遮断 | iMessage全員＋ログ |

---

## 8. 遠隔停止（緊急時）

iPhoneのTermiusアプリからSSH接続後：

```bash
# Ollamaだけ停止
pkill ollama

# ネットワーク遮断
sudo pfctl -e -f /etc/pf.conf

# Mac mini完全シャットダウン
sudo shutdown -h now
```

---

## 9. 管理者ごとの権限設計

| 役割 | アクセス手段 | できること |
|:-----|:-----------|:---------|
| システム管理者 | Tailscale SSH | 全操作・緊急停止 |
| 事務長・管理者 | Netdashボード（URL） | 状態閲覧のみ |
| 全員 | iMessageアラート | 異常通知の受信 |

---

## 10. 導入ステップ（推奨順序）

| 順序 | 作業 | 難易度 |
|:-----|:-----|:-------|
| ① | Tailscaleインストール・SSH設定 | ★★☆ |
| ② | launchd でOllama自動起動設定 | ★★☆ |
| ③ | Netdataインストール・URL共有 | ★☆☆ |
| ④ | monitor.sh 作成・cron設定 | ★★★ |
| ⑤ | block_suspicious.sh 設定 | ★★★ |

---

*このドキュメントはClaude Codeが作成（2026-02-28）*
