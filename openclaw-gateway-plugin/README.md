# Lifelog Gateway - OpenClaw Plugin

iOS アプリおよび Chrome 拡張からのテレメトリ・閲覧履歴・音声文字起こしを受信する OpenClaw Gateway プラグイン。

## エンドポイント

| Method | Path | 概要 |
|--------|------|------|
| POST | `/api/telemetry` | 位置情報・ヘルス・モーション・再生中メディア |
| POST | `/api/web-history` | ブラウザ閲覧履歴 |
| GET/POST | `/api/recall-settings` | リアクション設定の取得・更新 |
| POST | `/api/voice-transcript` | 音声文字起こし結果 |

全エンドポイントは OpenClaw Gateway の Bearer トークンで認証されます。

## 前提条件

- Node.js 18+
- OpenClaw Gateway がインストール・稼働中であること
- Python 3 (`make install` / `make verify` で使用)

## セットアップ

```bash
# ビルドのみ
make build

# ビルド + OpenClaw への登録 + Gateway 再起動
make install

# 動作確認
make verify
```

## Makefile コマンド一覧

| コマンド | 説明 |
|----------|------|
| `make build` | TypeScript をコンパイルし `dist/` に出力 |
| `make clean` | `dist/` を削除 |
| `make install` | ビルド → プラグイン登録 → Gateway 再起動 |
| `make register` | ビルド済みファイルを `~/.openclaw/extensions/` にコピーし `openclaw.json` に登録 |
| `make uninstall` | プラグインを削除し `openclaw.json` から登録解除 |
| `make restart` | OpenClaw Gateway を再起動 |
| `make verify` | curl で各エンドポイントの動作を確認 |

## 手動インストール

### 1. ビルド

```bash
npm install
npx tsc
```

### 2. プラグインファイルをコピー

```bash
PLUGIN_DIR=~/.openclaw/extensions/lifelog-gateway
mkdir -p "$PLUGIN_DIR/src" "$PLUGIN_DIR/scripts"
cp dist/index.js dist/index.js.map "$PLUGIN_DIR/"
cp dist/src/*.js dist/src/*.js.map "$PLUGIN_DIR/src/"
cp package.json openclaw.plugin.json "$PLUGIN_DIR/"
cp scripts/cleanup-memory.sh "$PLUGIN_DIR/scripts/"
chmod +x "$PLUGIN_DIR/scripts/cleanup-memory.sh"
```

### 3. プラグインを登録

`~/.openclaw/openclaw.json` に以下を追加:

```json
{
  "plugins": {
    "entries": {
      "lifelog-gateway": {
        "enabled": true
      }
    }
  }
}
```

### 4. Gateway を再起動

```bash
openclaw gateway stop
openclaw gateway start
```

## 動作確認

```bash
# トークンを取得
TOKEN=$(python3 -c "import json; print(json.load(open('$HOME/.openclaw/openclaw.json'))['gateway']['auth']['token'])")

# 位置情報
curl -s -X POST http://localhost:18789/api/telemetry \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"events":[{"type":"location","id":"test-001","timestamp":"2026-01-01T00:00:00Z","data":{"lat":35.6762,"lon":139.6503,"accuracy":10}}]}'
# => {"received":1,"healthReceived":false,"motionReceived":false,"nowPlayingReceived":false,"nextMinIntervalSec":60}

# ヘルスデータ
curl -s -X POST http://localhost:18789/api/telemetry \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"health":{"steps":7000,"heartRateAvg":72}}'
# => {"received":0,"healthReceived":true,...,"nextMinIntervalSec":60}

# Web 履歴
curl -s -X POST http://localhost:18789/api/web-history \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"entries":[{"id":"wh-001","url":"https://example.com","title":"Example","visitedAt":"2026-01-01T00:00:00Z","dwellSeconds":30}]}'
# => {"received":1,"nextMinIntervalSec":60}

# 設定取得
curl -s http://localhost:18789/api/recall-settings \
  -H "Authorization: Bearer $TOKEN"
# => {"webReactionsEnabled":true,...}
```

## データ永続化

| ファイル | 内容 |
|----------|------|
| `~/.openclaw/workspace/memory/current-location.json` | 最新の位置情報 |
| `~/.openclaw/workspace/memory/health-state.json` | 最新のヘルスサマリー |
| `~/.openclaw/workspace/memory/motion-state.json` | 最新のモーション状態 |
| `~/.openclaw/workspace/memory/now-playing-state.json` | 最新の再生中メディア |
| `~/.openclaw/workspace/memory/web-history-state.json` | 最新の閲覧履歴 |
| `~/.openclaw/workspace/memory/web-history-seen.json` | 閲覧履歴の重複排除データ |
| `~/.openclaw/workspace/memory/voice-transcript-state.json` | 最新の文字起こし状態 |
| `~/.openclaw/workspace/memory/recall-settings.json` | リアクション設定 |
| `~/.openclaw/workspace/memory/YYYY-MM-DD.md` | 日記エントリ |

## 日記フォーマット

```
📍 14:00-14:30 集計: 5件/ユニーク3点 | 移動 1.2km | 最終 35.6762, 139.6503 (avg acc 10m)
❤️ 14:30 - 7000 steps | HR 72bpm | RHR 60bpm
🚶 15:00 Motion: walking (high)
🎵 15:05 Now Playing: Song Title — Artist
🌐 16:00 - Article Title (example.com) [45s 📖80%]
🎙 17:00 - [2 speakers, 120s] ja
```

## メモリクリーンアップ

90 日以上前の日記ファイルを削除し、位置履歴を 14 日分にローテーション:

```bash
# プレビュー
./scripts/cleanup-memory.sh --dry-run

# 実行
./scripts/cleanup-memory.sh
```

cron で毎日 4:00 に実行する場合:

```bash
(crontab -l 2>/dev/null; echo "0 4 * * * ~/.openclaw/extensions/lifelog-gateway/scripts/cleanup-memory.sh >> ~/.openclaw/logs/cleanup.log 2>&1") | crontab -
```

## トラブルシューティング

| 症状 | 確認事項 |
|------|----------|
| プラグインが読み込まれない | `~/.openclaw/logs/gateway.log` を確認。`openclaw.json` で `lifelog-gateway` が `enabled: true` になっているか |
| 401 Unauthorized | Bearer トークンが `gateway.auth.token` と一致しているか |
| Connection refused | `openclaw gateway status` で Gateway が稼働中か確認。デフォルトポートは 18789 |

## プロジェクト構成

```
openclaw-gateway-plugin/
├── index.ts                 # プラグインエントリーポイント
├── src/
│   ├── types.ts             # OpenClaw API 型定義
│   ├── http.ts              # HTTP ユーティリティ
│   ├── auth.ts              # Bearer トークン認証
│   ├── store.ts             # テレメトリ用インメモリストア
│   ├── recall-settings.ts   # リアクション設定 読み書き
│   ├── settings-handler.ts  # /api/recall-settings ハンドラ
│   ├── handler.ts           # /api/telemetry ハンドラ
│   ├── web-history-store.ts # 閲覧履歴ストア
│   ├── web-history-handler.ts # /api/web-history ハンドラ
│   └── voice-transcript-handler.ts # /api/voice-transcript ハンドラ
├── dist/                    # tsc 出力 (ビルド生成物)
├── scripts/
│   └── cleanup-memory.sh    # メモリクリーンアップ
├── Makefile
├── package.json
├── tsconfig.json
├── openclaw.plugin.json
└── .env.local.example
```
