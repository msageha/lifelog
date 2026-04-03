# AUDIT_REPORT_V2.md — Lifelog プラットフォーム統合監査レポート

**監査日:** 2026-04-02
**対象プラットフォーム:** iPhone / AppleWatch / Gateway (openclaw-gateway-plugin) / Chrome Extension
**監査基準:** セキュリティ・安定性・品質・運用リスク

---

## 1. エグゼクティブサマリー

### 全体健全性評価

| プラットフォーム | 新規 High+ | 新規 Medium | 新規 Low | 前回修正済み（マージ待ち） | 総合評価 |
|-----------------|-----------|------------|---------|------------------------|---------|
| iPhone          | 3         | 8          | 3       | 多数（詳細は §2）       | 要対応   |
| AppleWatch      | 4         | 4          | 3       | 多数（詳細は §2）       | 要対応   |
| Gateway         | 0         | 4          | 5       | 多数（詳細は §2）       | 中程度   |
| Chrome          | 1         | 5          | 4       | 多数（詳細は §2）       | 中程度   |
| **合計**        | **8**     | **21**     | **15**  |                        |         |

**Critical 該当なし。** High 8件は主にクラッシュ原因となる force unwrap、未実装の重要機能、スタックオーバーフローリスクに集中。前回コマンド（cmd_1775134445）で修正済みの多数の問題が publish 失敗により main 未反映のため、早期マージが最優先事項。

---

## 2. 前回修正のマージ状況

### 背景

前回コマンド `cmd_1775134445` で以下の修正が完了したが、publish（main へのマージ）が失敗し、修正が main ブランチに未反映。**これらは全て「修正済み・マージ待ち」であり、新規対応は不要。再 publish が必要。**

### 修正済み・マージ待ち項目一覧

#### Gateway（修正済み・マージ待ち）
| 項目 | 内容 |
|------|------|
| crypto.timingSafeEqual() | タイミング攻撃対策 |
| RateLimiter 統合 | レートリミット機能 |
| 認証必須化 | 全エンドポイントの認証チェック |
| ボディサイズ制限 | リクエストサイズの上限設定 |
| FileWriteQueue | ファイル書き込みキュー |
| ファイルパーミッション 0o600/0o700 | 設定ファイルのアクセス権限 |

#### Chrome Extension（修正済み・マージ待ち）
| 項目 | 内容 |
|------|------|
| crypto.js (AES-GCM 暗号化) | データ暗号化実装 |
| CSP 定義 | Content Security Policy |
| sender.id 検証 | メッセージ送信元の検証 |

#### iPhone（修正済み・マージ待ち）
| 項目 | 内容 |
|------|------|
| VADProcessor CoreML 実装 | 音声活動検出 |
| RecordingViewModel 録音制御 | 録音状態管理 |
| AudioSessionManager マイク認可+割り込み | オーディオセッション管理 |
| AgentViewModel WS 接続 | WebSocket 接続管理 |
| AgentMessageReceiver / SpatialAudioPlayer 実装 | エージェント通信 |
| ChunkUploader 認証+force unwrap 修正 | アップロード安全性 |
| WebSocketClient リトライ上限 | 再接続制限 |
| LocationTracker 実装 | 位置情報追跡 |
| ModelContainerSetup throws 修正 | モデル初期化エラーハンドリング |
| UploadViewModel 全メソッド | アップロード UI |
| ATS 修正 | App Transport Security |
| BGTask 宣言削除 | 不要なバックグラウンドタスク宣言 |

#### AppleWatch（修正済み・マージ待ち）
| 項目 | 内容 |
|------|------|
| LaunchSequence 全7ステップ実装 | 起動シーケンス |
| ATS 修正 | App Transport Security |
| ModelContainerSetup throws 修正 | モデル初期化エラーハンドリング |

---

## 3. 新規発見の問題一覧

### 重大度別サマリー

| 重大度 | 件数 | 主な問題カテゴリ |
|--------|------|-----------------|
| Critical | 0 | — |
| High | 8 | force unwrap クラッシュ、未実装機能、スタックオーバーフロー |
| Medium | 21 | メモリリーク、スレッド安全性、過剰権限、デッドコード |
| Low | 15 | コード品質、命名不統一、冗長性 |

---

## 4. プラットフォーム別詳細

---

### 4.1 iPhone

#### High

| ID | 問題 | ファイル | 行番号 | 説明 | 修正方針 |
|----|------|---------|--------|------|---------|
| iPh-H1 | QRScannerView AVCaptureSession 未実装 | `Recall/Views/Config/QRScannerView.swift` | 7-11 | QR スキャナ画面が AVCaptureSession を使用しておらず、カメラ経由の QR 読み取りが機能しない。TODO コメントのみ残存。 | AVCaptureSession + AVCaptureMetadataOutput を実装し、QR コードのキャプチャ・デコードを行う。カメラ権限の要求処理も追加。 |
| iPh-H2 | BackgroundURLSessionManager delegate 未設定・重複セッション生成 | `Recall/Services/Network/BackgroundURLSessionManager.swift` | 13-31 | バックグラウンドセッションの delegate が未設定のため、バックグラウンド転送完了時のコールバックが受け取れない。また `allocateUninitializedSession()` で重複セッションが生成される可能性。 | delegate を self に設定。セッション生成を lazy 初期化に変更し、重複生成を防止。 |
| iPh-H3 | AudioRecordingEngine AVAudioFormat force unwrap | `Recall/Services/Audio/AudioRecordingEngine.swift` | 37 | AVAudioFormat の初期化結果を force unwrap (`!`) しており、サポート外のフォーマットでクラッシュする。 | guard let + エラーハンドリングに変更。フォーマット生成失敗時は呼び出し元にエラーを伝播。 |

#### Medium

| ID | 問題 | ファイル | 行番号 | 説明 | 修正方針 |
|----|------|---------|--------|------|---------|
| iPh-M1 | MotionActivityDetector メインスレッドコールバック | `Recall/Services/Motion/MotionActivityDetector.swift` | 21 | `startActivityUpdates(to: .main)` でメインスレッドにコールバックしており、UI スレッドをブロックするリスク。 | バックグラウンドキュー（OperationQueue）を使用し、UI 更新が必要な箇所のみ MainActor に切り替え。 |
| iPh-M2 | BackgroundLocationSession LaunchSequence から未呼出 | `Recall/Services/Location/BackgroundLocationSession.swift` | — | 定義されているが LaunchSequence から呼び出されておらず、バックグラウンド位置情報取得が起動時に初期化されない。 | LaunchSequence に BackgroundLocationSession の初期化ステップを追加。 |
| iPh-M3 | HealthBackgroundDelivery LaunchSequence から未呼出 | `Recall/Services/Health/HealthBackgroundDelivery.swift` | — | 定義されているが LaunchSequence から呼び出されておらず、HealthKit バックグラウンドデリバリが有効化されない。 | LaunchSequence に HealthBackgroundDelivery の登録ステップを追加。 |
| iPh-M4 | ChunkUploader.startProcessing() 実処理未接続 | `Recall/Services/Network/ChunkUploader.swift` | 11 | startProcessing() が定義されているが、実際のチャンク処理ロジックへの接続が不完全。 | 処理キューからのチャンク取得・アップロード実行のフローを接続。 |
| iPh-M5 | TelemetryService.flushBatch() オフライン時送信試行 | `Recall/Services/Network/TelemetryService.swift` | 51 | ネットワーク接続状態を確認せずに送信を試行するため、オフライン時に不要なリクエストとエラーが発生。 | NWPathMonitor 等でネットワーク状態を確認し、オフライン時はフラッシュをスキップまたはキューイング。 |
| iPh-M6 | ChunkUploader.uploadWithRetry() 失敗状態未更新 | `Recall/Services/Network/ChunkUploader.swift` | 64 | リトライ上限到達後にチャンクの状態が「失敗」に更新されず、永続的にリトライ対象として残る可能性。 | リトライ上限到達時にチャンクステータスを `.failed` に更新し、再処理対象から除外。 |
| iPh-M7 | ActivityLogger.cleanOldLogs() force unwrap | `Recall/Services/Logging/ActivityLogger.swift` | 79 | `Calendar.current.date(byAdding:)` の結果を force unwrap しており、理論上 nil を返す可能性は低いが安全でない。 | guard let に変更。 |
| iPh-M8 | HealthKitCollector.querySleepAnalysis() force unwrap | `Recall/Services/Health/HealthKitCollector.swift` | 117 | `calendar.date(byAdding:)` の結果を force unwrap。 | guard let に変更。 |

#### Low

| ID | 問題 | ファイル | 行番号 | 説明 | 修正方針 |
|----|------|---------|--------|------|---------|
| iPh-L1 | OpusEncoder.writeSamples() baseAddress force unwrap | `Recall/Services/Audio/OpusEncoder.swift` | 134 | `basePtr.baseAddress!` の force unwrap。バッファが空でない限り nil にはならないが、防御的コーディングとして安全でない。 | guard let で保護し、nil 時は早期リターン。 |
| iPh-L2 | Constants.Network パス不統一 | `Recall/Utilities/Constants.swift` | 32-36 | `ingestEndpoint = "/ingest"` と `telemetryEndpoint = "/api/telemetry"` でパスのプレフィックスが不統一（`/api/` 有無）。 | エンドポイントのパス命名規則を統一。 |
| iPh-L3 | ConfigViewModel bearerToken メモリ保持 | `Recall/ViewModels/ConfigViewModel.swift` | 15 | Bearer Token を平文の String プロパティとして保持。メモリダンプで漏洩リスク。 | Keychain に保存し、必要時のみ取得する方式に変更。 |

---

### 4.2 AppleWatch

#### High

| ID | 問題 | ファイル | 行番号 | 説明 | 修正方針 |
|----|------|---------|--------|------|---------|
| AW-H1 | ConnectivityMonitor / TelemetryService に shared シングルトン不在 | `RecallWatch/Services/Network/ConnectivityMonitor.swift`, `RecallWatch/Services/Network/TelemetryService.swift` | — | ConnectivityMonitor は @Observable @MainActor クラス、TelemetryService は actor だが、いずれも shared シングルトンパターンがない。複数インスタンス生成によるリソース競合リスク。 | `static let shared` パターンを追加し、単一インスタンスを保証。または SwiftUI の @Environment 経由で注入を統一。 |
| AW-H2 | WebSocketClient 再帰的 receiveLoop スタックオーバーフロー | `RecallWatch/Services/Network/WebSocketClient.swift` | 34, 45-50 | receiveLoop() が再帰的に自身を呼び出す構造。長時間接続でスタックが積み上がりクラッシュの可能性。 | while ループベースの実装に変更し、再帰を排除。Task 内での while true + await パターンを使用。 |
| AW-H3 | AudioRecordingEngine AVAudioFormat force unwrap | `RecallWatch/Services/Audio/AudioRecordingEngine.swift` | 37 | iPhone と同一の問題。AVAudioFormat の初期化結果を force unwrap。 | guard let + エラーハンドリングに変更。 |
| AW-H4 | Info.plist ts.net ATS 例外 | `RecallWatch/Resources/Info.plist` | 29-35 | ts.net ドメインに対する ATS 例外（NSExceptionAllowsInsecureHTTPLoads）が設定されており、HTTP 通信を許可。本番環境でのセキュリティリスク。 | 本番ビルドでは ATS 例外を削除し、HTTPS を強制。開発用途であれば Debug 構成のみに限定。 |

#### Medium

| ID | 問題 | ファイル | 行番号 | 説明 | 修正方針 |
|----|------|---------|--------|------|---------|
| AW-M1 | AudioSessionManager NotificationCenter observer リーク | `RecallWatch/Services/Audio/AudioSessionManager.swift` | 14-28 | NotificationCenter.addObserver で登録した observer の解除処理がなく、インスタンス破棄後もリークする。 | deinit で removeObserver を呼ぶか、Combine の sink + AnyCancellable で自動解除。 |
| AW-M2 | WatchAppDelegate ライフサイクルメソッド空 | `RecallWatch/App/WatchAppDelegate.swift` | 4-14 | applicationDidFinishLaunching, applicationDidBecomeActive, applicationWillResignActive が空実装。初期化処理が行われない。 | 必要な初期化処理（サービス起動、状態復元等）を実装。不要であればメソッド自体を削除。 |
| AW-M3 | TelemetryService 非 Sendable URLSession.shared | `RecallWatch/Services/Network/TelemetryService.swift` | 110 | actor 内で `URLSession.shared`（非 Sendable）を使用。Swift 6 の strict concurrency で警告/エラーとなる。 | actor 内で専用の URLSession インスタンスを保持するか、Sendable 準拠のラッパーを使用。 |
| AW-M4 | BackgroundURLSessionManager nonisolated(unsafe) | `RecallWatch/Services/Network/BackgroundURLSessionManager.swift` | 45 | `nonisolated(unsafe) var handlers` でデータ競合保護をコンパイラに無視させている。実行時にデータ競合が発生する可能性。 | DispatchQueue でのシリアルアクセスか、actor に変更してスレッド安全性を保証。 |

#### Low

| ID | 問題 | ファイル | 行番号 | 説明 | 修正方針 |
|----|------|---------|--------|------|---------|
| AW-L1 | Constants.Network.ingestEndpoint 相対パス不統一 | `RecallWatch/Utilities/Constants.swift` | 35 | iPhone と同様のパス不統一問題。 | iPhone と合わせてパス命名規則を統一。 |
| AW-L2 | RecordingState.listening 未使用 | `Shared/RecordingState.swift` | 5 | `.listening` ケースが定義されているが、コードベース内で使用箇所がない。 | 使用予定がなければ削除。今後の機能で必要であればコメントで意図を記載。 |
| AW-L3 | ConfigViewModel bearerToken 平文保持 | `RecallWatch/ViewModels/ConfigViewModel.swift` | 15 | iPhone と同一の問題。Bearer Token を平文 String で保持。 | Keychain に保存する方式に変更。 |

---

### 4.3 Gateway (openclaw-gateway-plugin)

#### Medium

| ID | 問題 | ファイル | 行番号 | 説明 | 修正方針 |
|----|------|---------|--------|------|---------|
| GW-M1 | store.ts setInterval unref 漏れ | `src/store.ts` | 77 | setInterval で定期クリーンアップを実行しているが、`.unref()` が呼ばれていないため、このタイマーだけで Node.js プロセスが終了しない。 | `setInterval(...).unref()` を呼び出し、プロセス終了を妨げないようにする。 |
| GW-M2 | rate-limiter.ts timestamps Map クリーンアップ不在 | `src/rate-limiter.ts` | 9 | `timestamps` Map のエントリは `isAllowed()` で古いタイムスタンプがフィルタされるが、キー自体の削除処理がない。長時間稼働でメモリが徐々に増加。 | 定期的に空エントリ（タイムスタンプ配列が空のキー）を削除するクリーンアップ処理を追加。 |
| GW-M3 | voice-transcript-handler.ts recentTranscripts 上限なし | `src/voice-transcript-handler.ts` | 50 | `recentTranscripts` 配列にサイズ上限がなく、大量のトランスクリプトでメモリが際限なく増加する可能性。 | 最大件数（例: 1000件）を設定し、古いエントリを自動削除。 |
| GW-M4 | RateLimiter 定義済み未使用（デッドコード） | `src/rate-limiter.ts` | 全体 | RateLimiter クラスがエクスポートされているが、プロジェクト内で import・使用されていない。前回修正で統合予定だったが未反映。 | 前回修正のマージ後に不要であれば削除。マージ後に統合されるなら対応不要。 |

#### Low

| ID | 問題 | ファイル | 行番号 | 説明 | 修正方針 |
|----|------|---------|--------|------|---------|
| GW-L1 | store.ts isDuplicate 空文字列挙動 | `src/store.ts` | 84 | `isDuplicate("")` は `if (!id) return false` で false を返すが、空文字列を「重複なし」として扱う挙動が意図的か不明。 | 空文字列の扱いをドキュメント化するか、空文字列は無効な ID としてエラーにする。 |
| GW-L2 | recall-settings.ts writeFile 非アトミック | `src/recall-settings.ts` | 61 | `fs.writeFile` で直接書き込みしており、書き込み中のクラッシュでファイルが破損する可能性。 | 一時ファイルに書き込み後 rename する（write-then-rename パターン）アトミック書き込みに変更。 |
| GW-L3 | formatJstTime / formatJstDate 重複定義 | `src/handler.ts` (56,65), `src/voice-transcript-handler.ts` (98,107), `src/web-history-handler.ts` (26,35) | 複数 | 同一関数が3ファイルに重複定義されている。変更時の同期漏れリスク。 | 共通ユーティリティモジュールに抽出し、各ファイルから import。 |
| GW-L4 | index signature [key: string]: unknown 型安全性低下 | `src/store.ts` (15,45,53,62), `src/web-history-store.ts` (24) | 複数 | インターフェースに `[key: string]: unknown` を付与しており、任意のプロパティアクセスが型チェックをバイパスする。 | index signature を削除し、必要なプロパティを明示的に定義。拡張が必要な場合は別途 `metadata` フィールドを設ける。 |
| GW-L5 | handler.ts ログに機密データ可能性 | `src/handler.ts` | 421 | `JSON.stringify(event).slice(0, 100)` でイベントデータをログ出力。位置情報等の機密データが含まれる可能性。 | ログ出力をイベントタイプと ID のみに制限し、ペイロードの出力を除外。 |

---

### 4.4 Chrome Extension

#### High

| ID | 問題 | ファイル | 行番号 | 説明 | 修正方針 |
|----|------|---------|--------|------|---------|
| Ch-H1 | Service Worker setTimeout でフラッシュ消失 | `background.js` | 89 | `setTimeout(flushSessionState, SESSION_FLUSH_DELAY_MS)` を使用しているが、Service Worker は非アクティブ時に終了されるため、タイマーが発火せずセッション状態がフラッシュされない。 | `chrome.alarms` API に置き換え。Service Worker の再起動後もアラームは維持される。 |

#### Medium

| ID | 問題 | ファイル | 行番号 | 説明 | 修正方針 |
|----|------|---------|--------|------|---------|
| Ch-M1 | serializeState エラーハンドラ二重実行 | `background.js` | 79 | `stateChain = stateChain.then(fn, fn)` パターンで、前の Promise が reject された場合に fn が二重実行される可能性。 | `.then(fn).catch(errorHandler)` パターンに変更し、成功・失敗の処理を分離。 |
| Ch-M2 | host_permissions \<all_urls\> 過剰 | `manifest.json` | 7 | `"host_permissions": ["<all_urls>"]` で全 URL へのアクセス権限を要求。Chrome Web Store の審査で拒否される可能性があり、セキュリティ上も過剰。 | 必要なドメインのみに制限（例: `"*://api.example.com/*"`）。 |
| Ch-M3 | IndexedDB open 失敗時リカバリ不能 | `lib/queue.js` | 35 | IndexedDB のオープン失敗時に reject するのみで、リカバリ処理がない。DB 破損時にキュー機能が永続的に停止。 | リトライロジックを追加。DB 破損時は `indexedDB.deleteDatabase()` で再作成を試みる。 |
| Ch-M4 | Service Worker 再起動時タイマー未復元 | `background.js` | 89 | Ch-H1 と関連。Service Worker 再起動時にフラッシュタイマーが復元されず、未フラッシュのセッション状態が失われる。 | `chrome.alarms` + `chrome.alarms.onAlarm` リスナーで永続的なスケジューリングを実装。 |
| Ch-M5 | innerHTML 使用 | `popup/popup.js` (147,151), `content.js` (227) | 複数 | innerHTML に動的データを挿入しており、XSS 脆弱性のリスク。popup.js はユーザーデータ、content.js は通知内容を挿入。 | DOM API（createElement, textContent）を使用するか、テンプレートリテラル使用時はエスケープ処理を実施。 |

#### Low

| ID | 問題 | ファイル | 行番号 | 説明 | 修正方針 |
|----|------|---------|--------|------|---------|
| Ch-L1 | content.js onMessage undefined 返り値 | `content.js` | 215 | `chrome.runtime.onMessage` リスナーが未処理メッセージで `undefined` を返す。非同期レスポンスが必要な場合に問題となる。 | 未処理メッセージでは明示的に `false` を返す。 |
| Ch-L2 | dedup map 肥大化 | `background.js` | 8, 34-52 | 6時間 TTL で dedup map をクリーンアップしているが、大量イベント時に chrome.storage.local のストレージを圧迫する可能性。 | TTL を短縮するか、最大エントリ数を設定。 |
| Ch-L3 | 空 catch 多用 | 複数ファイル | — | try-catch で catch ブロックが空のパターンが複数存在。エラーが無視されデバッグが困難。 | 最低限 console.error でログ出力。重要な処理ではエラーを上位に伝播。 |
| Ch-L4 | popup.js dragSrcIndex グローバル変数 | `popup/popup.js` | 263 | ドラッグ＆ドロップのインデックスをモジュールスコープの `let` で管理。複数のドラッグ操作が競合する可能性。 | ドラッグイベントの dataTransfer を使用してインデックスを伝搬。 |
| Ch-L5 | permissions activeTab 冗長 | `manifest.json` | 6 | `<all_urls>` の host_permissions が既にあるため、`activeTab` パーミッションは冗長。 | host_permissions を適切なスコープに変更した上で activeTab を保持するか、`<all_urls>` を削除して activeTab に統一。 |

---

## 5. 推奨対応優先順位

### 最優先: 前回修正の再 publish

前回コマンド `cmd_1775134445` の修正を main にマージする。これにより多数のセキュリティ・安定性問題が解消される。

### 優先度 1: High（クラッシュ・セキュリティリスク — 即座に対応）

| 優先順 | ID | 問題 | 影響 |
|--------|-----|------|------|
| 1 | iPh-H3, AW-H3 | AudioRecordingEngine AVAudioFormat force unwrap | 録音開始時にクラッシュする可能性（iPhone/AppleWatch 共通） |
| 2 | AW-H2 | WebSocketClient 再帰的 receiveLoop | 長時間接続でスタックオーバーフロー→クラッシュ |
| 3 | Ch-H1 | Service Worker setTimeout | セッション状態のフラッシュが失われる（データ損失） |
| 4 | iPh-H2 | BackgroundURLSessionManager delegate 未設定 | バックグラウンド転送が完了通知を受け取れない |
| 5 | iPh-H1 | QRScannerView AVCaptureSession 未実装 | QR スキャン機能が動作しない |
| 6 | AW-H4 | Info.plist ts.net ATS 例外 | HTTP 通信によるセキュリティリスク |
| 7 | AW-H1 | ConnectivityMonitor/TelemetryService シングルトン不在 | リソース競合・データ不整合 |

### 優先度 2: Medium（安定性・品質リスク — 次スプリントで対応）

| カテゴリ | 対象 ID | 概要 |
|---------|---------|------|
| メモリリーク・リソース管理 | GW-M2, GW-M3, AW-M1 | Map/配列の無制限増加、observer リーク |
| スレッド安全性・並行性 | iPh-M1, AW-M3, AW-M4 | メインスレッドブロック、非 Sendable、nonisolated(unsafe) |
| 未接続・未使用機能 | iPh-M2, iPh-M3, iPh-M4, AW-M2, GW-M4 | LaunchSequence 未呼出、空実装、デッドコード |
| データ整合性 | iPh-M5, iPh-M6, Ch-M1, Ch-M3, Ch-M4 | オフライン送信、失敗状態未更新、DB リカバリ |
| セキュリティ | Ch-M2, Ch-M5 | 過剰権限、innerHTML XSS |
| Force unwrap | iPh-M7, iPh-M8 | Calendar.date force unwrap |

### 優先度 3: Low（コード品質 — 余裕のあるタイミングで対応）

| カテゴリ | 対象 ID | 概要 |
|---------|---------|------|
| セキュリティ改善 | iPh-L3, AW-L3, GW-L5 | bearerToken 平文保持、ログの機密データ |
| コード品質 | GW-L3, GW-L4, Ch-L3, Ch-L4 | 重複定義、型安全性、空 catch、グローバル変数 |
| 防御的コーディング | iPh-L1, iPh-L2, AW-L1 | force unwrap、パス不統一 |
| 軽微な改善 | GW-L1, GW-L2, AW-L2, Ch-L1, Ch-L2, Ch-L5 | 空文字列挙動、非アトミック書き込み、冗長権限 |

---

## 付録: 問題 ID クロスリファレンス

| ID | プラットフォーム | 重大度 | セクション |
|----|-----------------|--------|-----------|
| iPh-H1 ~ iPh-H3 | iPhone | High | §4.1 |
| iPh-M1 ~ iPh-M8 | iPhone | Medium | §4.1 |
| iPh-L1 ~ iPh-L3 | iPhone | Low | §4.1 |
| AW-H1 ~ AW-H4 | AppleWatch | High | §4.2 |
| AW-M1 ~ AW-M4 | AppleWatch | Medium | §4.2 |
| AW-L1 ~ AW-L3 | AppleWatch | Low | §4.2 |
| GW-M1 ~ GW-M4 | Gateway | Medium | §4.3 |
| GW-L1 ~ GW-L5 | Gateway | Low | §4.3 |
| Ch-H1 | Chrome | High | §4.4 |
| Ch-M1 ~ Ch-M5 | Chrome | Medium | §4.4 |
| Ch-L1 ~ Ch-L5 | Chrome | Low | §4.4 |
