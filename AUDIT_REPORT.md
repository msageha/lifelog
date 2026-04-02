# Lifelog プロジェクト 品質監査レポート

**日付**: 2026-04-02
**対象**: iPhone/, AppleWatch/, chrome/, openclaw-gateway-plugin/

---

## 概要

全4コンポーネントを対象に、実装完全性・バグ・セキュリティ・プラットフォーム固有問題・堅牢性の5観点で網羅的に調査を実施。Critical 14件、High 12件、Medium 7件、Low 3件の問題を検出。

---

## Critical（即時対応必要）— 14件

### 実装 TODO 残存

| # | 問題 | ファイル | 詳細 |
|---|------|---------|------|
| 1 | iPhone VADProcessor 未実装 | `iPhone/Recall/Services/Audio/VADProcessor.swift:13,18` | CoreMLモデルロード・推論が TODO。常に 0.0 を返却し音声検出が機能しない |
| 2 | RecordingViewModel 録音開始/停止 TODO | `iPhone/Recall/ViewModels/RecordingViewModel.swift:14,19` | AudioRecordingEngine の start/stop が未接続 |
| 3 | AgentViewModel WS接続 TODO | `iPhone/Recall/ViewModels/AgentViewModel.swift:13,17` | WebSocketClient の connect/disconnect が未実装 |
| 4 | AgentMessageReceiver / SpatialAudioPlayer 未実装 | `iPhone/Recall/Services/Agent/` 全ファイル | JSONパース、Opusデコード、空間オーディオ再生が全て TODO |
| 5 | AppleWatch LaunchSequence 全7ステップ TODO | `AppleWatch/RecallWatch/App/LaunchSequence.swift:18-42` | サービスが一切初期化されない |
| 6 | LocationTracker 未実装 | `iPhone/Recall/Services/Location/LocationTracker.swift:11-17` | CLLocationManager 未設定。Info.plist で location モード宣言済みのため App Store 審査リジェクトリスク |

### プラットフォーム問題

| # | 問題 | ファイル | 詳細 |
|---|------|---------|------|
| 7 | マイク認可フロー未実装 | `iPhone/Recall/Services/Audio/AudioSessionManager.swift:8-16` | AVAudioSession.requestRecordPermission() 呼び出しなし。許可なしで録音開始するとクラッシュ |
| 8 | UIBackgroundModes fetch/processing 未使用宣言 | `iPhone/Recall/Resources/Info.plist:52-58` | BGTaskScheduler 実装なし。審査リジェクト対象 |
| 9 | ModelContainerSetup fatalError | `iPhone/Recall/Models/ModelContainerSetup.swift:20-21` | SwiftData 初期化失敗時にクラッシュ。エラー UI へのフォールバックが必要 |

### セキュリティ

| # | 問題 | ファイル | 詳細 |
|---|------|---------|------|
| 10 | ATS HTTP例外（平文通信） | `iPhone/Recall/Resources/Info.plist:25-37`, `AppleWatch/RecallWatch/Resources/Info.plist:25-37` | ts.net ドメインで平文 HTTP 通信を許可。Bearer token や健康データが傍受可能。修正: NSExceptionAllowsInsecureHTTPLoads を false にするか ATS 例外を削除 |
| 11 | ChunkUploader 認証ヘッダー欠落 | `iPhone/Recall/Services/Network/ChunkUploader.swift:35` | 音声チャンクアップロードに Authorization header が設定されていない。修正: Bearer token を request header に追加 |
| 12 | Gateway RateLimiter 実装済みだが未使用 | `openclaw-gateway-plugin/src/rate-limiter.ts` | 全エンドポイントで未使用。DoS 攻撃に脆弱。修正: 全ハンドラにレート制限ミドルウェアを統合 |
| 13 | Gateway タイミング攻撃脆弱性 | `openclaw-gateway-plugin/src/auth.ts:17` | トークン比較が `!==`（非定時間比較）。修正: `crypto.timingSafeEqual()` を使用 |
| 14 | Chrome トークン・閲覧データ平文保存 | `chrome/background.js:54-61, 191-213, 534-545` | chrome.storage.local にトークン、URL、ページコンテンツが暗号化なしで保存。修正: WebCrypto API で暗号化 |

---

## High（早期対応推奨）— 12件

### 実装 TODO 残存

| # | 問題 | ファイル | 詳細 |
|---|------|---------|------|
| 15 | UploadViewModel 全メソッド TODO | `iPhone/Recall/ViewModels/UploadViewModel.swift:13,17,21` | ChunkUploader 開始、失敗リトライ、スタック復旧が未実装 |
| 16 | AudioSessionManager 割り込み/経路変更未対応 | `iPhone/Recall/Services/Audio/AudioSessionManager.swift:45,48,60` | 録音一時停止/再開、ヘッドフォン/Bluetooth 切断対応が TODO |

### 堅牢性

| # | 問題 | ファイル | 詳細 |
|---|------|---------|------|
| 17 | Gateway ファイル I/O 競合 | `openclaw-gateway-plugin/src/handler.ts:127-149`, `web-history-handler.ts:142` | 複数ハンドラが同一日記ファイルに fs.appendFile() で同時書き込み。ロック機構なし。修正: 書き込みキューまたはファイルロック導入 |
| 18 | Gateway FD 枯渇リスク | `openclaw-gateway-plugin/src/handler.ts:426-457` | 同時ファイル操作に上限なし。.catch(()=>{}) でエラー黙殺。修正: 書き込みバッチ処理またはセマフォ導入 |
| 19 | ChunkUploader force unwrap | `iPhone/Recall/Services/Network/ChunkUploader.swift:35` | `URL(string: endpoint)!` で不正 endpoint 時にクラッシュ。修正: `guard let` でアンラップ |
| 20 | WebSocketClient 無限リトライ | `iPhone/Recall/Services/Network/WebSocketClient.swift` | 最大リトライ回数の制限なし。修正: maxRetryCount 導入（例: 50回） |

### セキュリティ

| # | 問題 | ファイル | 詳細 |
|---|------|---------|------|
| 21 | Gateway 認証オプション | `openclaw-gateway-plugin/src/handler.ts:368` | gatewayToken 未設定時に全リクエスト許可。修正: トークン必須化、未設定時はサーバ起動拒否 |
| 22 | Gateway リクエストボディサイズ無制限 | `openclaw-gateway-plugin/src/http.ts:3-9` | readBody() にサイズ上限なし。メモリ枯渇 DoS 可能。修正: 最大ペイロードサイズ（例: 1MB）を強制 |
| 23 | Chrome CSP 未定義 | `chrome/manifest.json` | Content Security Policy なし。修正: strict CSP を追加 |
| 24 | Chrome メッセージ送信元検証なし | `chrome/background.js:783-809` | chrome.runtime.onMessage で sender origin を検証していない。修正: `sender.id === chrome.runtime.id` を検証 |
| 25 | Gateway ファイルパーミッション不適切 | `openclaw-gateway-plugin/src/handler.ts:127` | デフォルト umask で機密ファイル作成。修正: ファイル 0o600、ディレクトリ 0o700 |
| 26 | トークン有効期限管理なし | 全コンポーネント | トークンは無期限で保存。漏洩時に永続アクセス可能。修正: トークン TTL + リフレッシュメカニズム実装 |

---

## Medium（改善推奨）— 7件

| # | 問題 | ファイル | 詳細 |
|---|------|---------|------|
| 27 | 証明書ピンニングなし | iPhone/AppleWatch URLSession | MITM 攻撃リスク。修正: TrustKit 等で証明書ピンニング実装 |
| 28 | サーバ URL バリデーション不足 | `iPhone/Recall/ViewModels/ConfigViewModel.swift:30-38` | QR コードからの URL 入力に HTTPS 検証なし。修正: HTTPS スキーム強制 + URL 形式バリデーション |
| 29 | Chrome `<all_urls>` 権限過剰 | `chrome/manifest.json:7, 12-17` | 全サイトにコンテンツスクリプト注入。修正: optional_permissions への移行検討 |
| 30 | データ削除 UI/API なし | 全コンポーネント | ユーザがデータ削除する手段がない。GDPR 等のプライバシー規制リスク。修正: 削除 UI (iPhone/Watch)、DELETE API (Gateway) 実装 |
| 31 | 同意取得フローなし | `iPhone/Recall/Views/Config/ConfigView.swift:33-38` | プライバシーポリシー同意 UI なし。データ収集トグルはデフォルト ON。修正: 初回起動時に同意画面表示 |
| 32 | Gateway デバッグログに機密データ | `openclaw-gateway-plugin/src/handler.ts:421` | 緯度経度がログに含まれる可能性。修正: 機密フィールドをマスク |
| 33 | Gateway globalThis に機密データ公開 | `openclaw-gateway-plugin/src/store.ts:107,126,136,145` | __recallLatestLocation 等がグローバル変数。修正: モジュールエクスポートに変更 |

---

## Low（品質向上）— 3件

| # | 問題 | ファイル | 詳細 |
|---|------|---------|------|
| 34 | Force unwrap クラッシュリスク | `iPhone/Recall/Services/Network/ChunkUploader.swift:35` | URL(string:)! で無効 URL 時にクラッシュ。修正: guard let + エラーハンドリング |
| 35 | Chrome ブロックサイトでもスクリプト実行 | `chrome/manifest.json:14` | フィルタリング前に DOM クエリが実行される。修正: dynamic content scripts への移行 |
| 36 | Gateway RateLimiter Map 無制限 | `openclaw-gateway-plugin/src/rate-limiter.ts:9` | クライアント別タイムスタンプ Map にクリーンアップなし |

---

## データフロー断絶

| パイプライン | 状態 | 詳細 |
|-------------|------|------|
| **音声** | 断絶あり | サービス内部は実装済みだが、LaunchSequence → AudioRecordingEngine の生成・依存チェーン（VADProcessor, ChunkManager, OpusEncoder, EngineWatchdog）が未インスタンス化 |
| **テレメトリ** | 断絶あり | LocationTracker(CLLocationManager 未設定) / HealthKitCollector(定期呼出なし) / MotionActivityDetector(telemetryService 引数欠落) → TelemetryService が未接続 |
| **エージェント** | 断絶あり | WebSocket 未インスタンス化 → AgentMessageReceiver(JSON パース TODO) → SpatialAudioPlayer(Opus デコード/再生 TODO) |

---

## TODO/FIXME 残存一覧（全29件）

### iPhone — Critical（10件）

| ファイル | 行 | 内容 |
|---------|-----|------|
| `Services/Audio/VADProcessor.swift` | 13 | Load SileroVAD.mlmodel |
| `Services/Audio/VADProcessor.swift` | 18 | Run CoreML inference |
| `ViewModels/RecordingViewModel.swift` | 14 | Start AudioRecordingEngine |
| `ViewModels/RecordingViewModel.swift` | 19 | Stop AudioRecordingEngine |
| `ViewModels/AgentViewModel.swift` | 13 | Connect WebSocketClient |
| `ViewModels/AgentViewModel.swift` | 17 | Disconnect WebSocketClient |
| `Services/Agent/AgentMessageReceiver.swift` | 11 | Parse JSON, create AgentMessage |
| `Services/Agent/AgentMessageReceiver.swift` | 16 | Decode Opus audio |
| `Services/Agent/SpatialAudioPlayer.swift` | 22 | Connect audio graph |
| `Services/Agent/SpatialAudioPlayer.swift` | 29 | Decode Opus and schedule playback |

### iPhone — High（9件）

| ファイル | 行 | 内容 |
|---------|-----|------|
| `Services/Audio/AudioSessionManager.swift` | 45 | Pause recording |
| `Services/Audio/AudioSessionManager.swift` | 48 | Resume recording |
| `Services/Audio/AudioSessionManager.swift` | 60 | Handle headphone/Bluetooth disconnect |
| `ViewModels/UploadViewModel.swift` | 13 | Start ChunkUploader |
| `ViewModels/UploadViewModel.swift` | 17 | Reset failed chunks |
| `ViewModels/UploadViewModel.swift` | 21 | Reset stuck uploading state |
| `Services/Location/LocationTracker.swift` | 12 | Configure CLLocationManager |
| `ViewModels/AgentViewModel.swift` | 21 | Update SpatialAudioPlayer parameters |
| `Services/Agent/SpatialAudioPlayer.swift` | 36 | Update listener/source position |

### iPhone — Medium（2件）

| ファイル | 行 | 内容 |
|---------|-----|------|
| `ViewModels/ConfigViewModel.swift` | 27 | Persist server URLs |
| `Views/Config/QRScannerView.swift` | 11 | Implement QR scanner |

### AppleWatch — Critical（7件）

| ファイル | 行 | 内容 |
|---------|-----|------|
| `App/LaunchSequence.swift` | 18 | ExtendedRuntimeSessionManager.start() |
| `App/LaunchSequence.swift` | 22 | recording.startEngine() |
| `App/LaunchSequence.swift` | 26 | upload.recoverStuckUploads() |
| `App/LaunchSequence.swift` | 30 | upload.startProcessing() |
| `App/LaunchSequence.swift` | 34 | ConnectivityMonitor.shared.start() |
| `App/LaunchSequence.swift` | 38 | TelemetryService.shared.start() |
| `App/LaunchSequence.swift` | 42 | agent.connectWebSocket() |

### AppleWatch — その他（8件）

iPhone と同等の TODO（AudioSessionManager, RecordingViewModel, AgentViewModel, ConfigViewModel, UploadViewModel, LocationTracker, AgentMessageReceiver, AudioPlayer）

---

## グレースフルデグラデーション評価

| シナリオ | iPhone | AppleWatch | Chrome | Gateway |
|---------|--------|------------|--------|---------|
| HealthKit 拒否 | 部分動作（ゼロ値送信） | 同左 | N/A | N/A |
| 位置情報拒否 | 未実装 | 未実装 | N/A | N/A |
| マイク拒否 | クラッシュリスク | 同左 | N/A | N/A |
| ネットワーク不通 | LocationQueue 保存 ○ | 同左 | IndexedDB 保存 ○ | N/A |
| Gateway ダウン | リトライ + キュー ○ | 同左 | キュー + 再送 ○ | N/A |

---

## 推奨対応優先順位

### 第1優先: Critical 実装 TODO 解消
1. iPhone VADProcessor 実装（AppleWatch 版は実装済み）
2. RecordingViewModel / UploadViewModel / AgentViewModel の TODO 実装
3. LocationTracker の CLLocationManager 実装
4. AppleWatch LaunchSequence 全ステップ実装
5. マイク認可フロー追加
6. UIBackgroundModes 未使用宣言の削除

### 第2優先: Critical セキュリティ修正
7. ChunkUploader に認証ヘッダー追加
8. Gateway RateLimiter をハンドラに統合
9. Gateway auth.ts にタイミングセーフ比較導入
10. ModelContainerSetup の fatalError をエラーハンドリングに変更

### 第3優先: High 修正
11. force unwrap の安全なアンラップへの置換
12. WebSocketClient に最大リトライ回数追加
13. Gateway ファイル I/O 競合対策
14. Gateway リクエストボディサイズ制限
15. Chrome CSP 定義追加
16. AudioSessionManager 割り込み対応
