# Medical AI Makers — medical-local-ai

**病院のデータを外に出さずにAIを使う**
医療従事者が自分たちで作り、保守するオープンソース院内AIシステム

[![Discord](https://img.shields.io/badge/Discord-Medical_AI_Makers-5865F2?logo=discord)](https://discord.gg/bCkMtK6Xy)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

---

## このプロジェクトについて

日本の医療機関の多くは、セキュリティ上の理由からChatGPT等のクラウドAIを使えない。

このプロジェクトは、**完全オンプレミス（院内完結）** で動くAI医療記録支援システムを、医療従事者が自分たちで構築・保守するためのドキュメントとスクリプトを提供する。

コストはほぼゼロ。使うのはすべてオープンソースのソフトウェア。

---

## できること

```
① 診察・処置後に音声で話す
② 院内サーバーのAIが自動でカルテ形式に整形
③ 確認して電子カルテに貼り付ける
```

患者情報は院外に一切出ない。

---

## システム構成

```
AmiVoice（音声認識・院内導入済みのケースが多い）
    ↓ テキスト出力
ローカルLLM（Ollama + gemma3:4b）
    ↓ SOAP形式に整形
電子カルテへ貼り付け（手動）
```

**動作環境**：Mac mini 2018以降 / RAM 16GB以上 / macOS

---

## ドキュメント

| ファイル | 内容 |
|:--------|:-----|
| [docs/setup.md](docs/setup.md) | インストール・セットアップ手順 |
| [docs/security.md](docs/security.md) | セキュリティ設計・監視・遠隔管理 |
| [docs/manual.md](docs/manual.md) | 緊急時対応マニュアル |
| [docs/prompts.md](docs/prompts.md) | 医療特化プロンプト集 |
| [proposals/事務長提案書テンプレート.md](proposals/事務長提案書テンプレート.md) | 院内導入時の提案書テンプレート |

---

## クイックスタート

```bash
# 1. Ollamaをインストール
brew install ollama

# 2. 日本語対応モデルをダウンロード
ollama pull gemma3:4b

# 3. 動作確認
ollama run gemma3:4b
```

詳細は [docs/setup.md](docs/setup.md) を参照。

---

## コミュニティ

**Discord**：https://discord.gg/bCkMtK6Xy

- 導入報告・質問・情報交換の場
- 各施設が自己保守する設計
- 日々の運営は参加者で回す

---

## 発起人

**sudoK** / K病院勤務の内科・外科医（麻酔標榜医）

> 私はプログラマーではなく、臨床医です。
> AIツールの助けを借りながらこのシステムを作りました。
> 完成品ではありません。一緒に育てていきましょう。

---

## ライセンス

MIT License — 自由に使用・改変・再配布可能。
医療記録への適用は必ず担当者が確認の上、自己責任で行ってください。

---

## 免責事項

- 本システムはPOC（実証実験）段階です
- AIの出力は必ず医療者が確認してから使用してください
- 電子カルテへの記載責任は医療者が負います
- 導入・運用は各施設の責任において行ってください
