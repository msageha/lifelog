# Lifelog

日常生活のさまざまなデータを自動的に記録・集約するパーソナルライフログプラットフォーム。

iOS / watchOS アプリ (Recall)、Chrome 拡張、OpenClaw Gateway プラグインで構成され、位置情報・ヘルスデータ・モーション・再生中メディア・ブラウザ閲覧履歴・音声文字起こしを継続的にキャプチャし、日次の日記エントリとして自動生成します。

## アーキテクチャ

```
┌─────────────┐  ┌─────────────────┐  ┌──────────────────┐
│  iPhone App  │  │  Apple Watch App │  │ Chrome Extension │
│   (Recall)   │  │    (Recall)      │  │                  │
└──────┬───────┘  └────────┬─────────┘  └────────┬─────────┘
       │                   │                      │
       │    HTTPS / WebSocket (Bearer Token)      │
       └───────────────────┼──────────────────────┘
                           ▼
              ┌─────────────────────────┐
              │  OpenClaw Gateway Plugin │
              │  (TypeScript / Node.js)  │
              └────────────┬────────────┘
                           ▼
              ~/.openclaw/workspace/memory/
               (JSON state + daily diary)
```

## プロジェクト構成

| ディレクトリ | 概要 | 技術スタック |
|---|---|---|
| [`iPhone/`](iPhone/) | iOS アプリ (Recall) | Swift 6, SwiftUI, HealthKit, CoreLocation, CoreMotion |
| [`AppleWatch/`](AppleWatch/) | watchOS アプリ (Recall) | Swift 6, SwiftUI, HealthKit |
| [`chrome/`](chrome/) | Chrome 拡張 | JavaScript (Manifest V3), AES-GCM 暗号化 |
| [`openclaw-gateway-plugin/`](openclaw-gateway-plugin/) | Gateway プラグイン | TypeScript, Node.js 18+ |

## 収集データ

| カテゴリ | ソース | 説明 |
|---|---|---|
| 位置情報 | iPhone | GPS によるバックグラウンド位置追跡 |
| ヘルス | iPhone / Apple Watch | 歩数、心拍数、安静時心拍数、睡眠 |
| モーション | iPhone | 歩行・走行・車両移動などの行動認識 |
| 再生中メディア | iPhone | 現在再生中の曲・ポッドキャスト |
| 閲覧履歴 | Chrome 拡張 | URL、タイトル、滞在時間 |
| 音声文字起こし | iPhone | 録音した音声のテキスト化 |

## 前提条件

- **iOS / watchOS:** Xcode 26+, [XcodeGen](https://github.com/yonaskolb/XcodeGen)
- **Chrome 拡張:** Node.js 18+ (テスト用)
- **Gateway プラグイン:** Node.js 18+, OpenClaw Gateway

## クイックスタート

### Gateway プラグイン

```bash
cd openclaw-gateway-plugin
npm install
make install    # ビルド → OpenClaw 登録 → Gateway 再起動
make verify     # エンドポイント動作確認
```

詳細は [`openclaw-gateway-plugin/README.md`](openclaw-gateway-plugin/README.md) を参照。

### iPhone アプリ

```bash
cd iPhone
make generate   # XcodeGen でプロジェクト生成
make build      # シミュレータ向けビルド
make test       # ユニットテスト実行
```

### watchOS アプリ

```bash
cd AppleWatch
make generate
make build
make test
```

### Chrome 拡張

```bash
cd chrome
npm install
npm test        # Jest テスト実行
```

`chrome://extensions` でデベロッパーモードを有効にし、`chrome/` ディレクトリを読み込みます。

## セットアップフロー

1. Gateway プラグインをインストール・起動
2. iPhone アプリ (Recall) を起動し、QR コードスキャンで Gateway の URL とトークンを設定
3. Chrome 拡張のポップアップから Gateway の URL とトークンを設定
4. データの収集が自動的に開始される

## データ保存先

収集されたデータは `~/.openclaw/workspace/memory/` にファイルベースで保存されます。

| ファイル | 内容 |
|---|---|
| `current-location.json` | 最新の位置情報 |
| `health-state.json` | ヘルスサマリー |
| `motion-state.json` | モーション状態 |
| `now-playing-state.json` | 再生中メディア |
| `web-history-state.json` | 閲覧履歴 |
| `voice-transcript-state.json` | 音声文字起こし |
| `recall-settings.json` | アプリ設定 |
| `YYYY-MM-DD.md` | 日記エントリ (自動生成) |

## ライセンス

Private
