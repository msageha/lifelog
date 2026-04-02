# Token Expiry Management Design

AUDIT_REPORT #26 対応 — トークン有効期限管理の設計方針

## 1. 現状分析

### 現在のトークンアーキテクチャ

| プラットフォーム | 保存方法 | トークン種別 | 有効期限 | リフレッシュ |
|---|---|---|---|---|
| iPhone | Keychain (`com.recall`) | 静的 Bearer | なし | なし |
| AppleWatch | Keychain (`com.recall.watch`) | 静的 Bearer | なし | なし |
| Chrome 拡張 | `chrome.storage.local` | 静的 Bearer | なし | なし |
| Gateway | OpenClaw config (`gateway.auth.token`) | 静的 Bearer | なし | なし |

### 現在の問題点

1. **トークンに有効期限がない** — 一度漏洩すると無期限に悪用可能
2. **トークンローテーションなし** — 定期的な更新メカニズムが存在しない
3. **401 エラーハンドリングなし** — トークン無効時にユーザーへのフィードバックがない
4. **Chrome 拡張は平文保存** — `chrome.storage.local` は暗号化されない
5. **全エンドポイントが同一トークン** — 権限分離がない

### 現在の認証フロー

```
クライアント → Bearer token → Gateway (auth.ts: timingSafeEqual で比較) → 処理
```

Gateway 側は `verifyAuth()` で OpenClaw config の `gateway.auth.token` と定数時間比較のみ。JWT デコードや有効期限チェックは一切行わない。

---

## 2. トークン種別の設計

### 推奨: 署名付きトークン (Signed Token) 方式

本プロジェクトの特性を踏まえ、**HMAC 署名付きトークン**を推奨する。

#### 選択肢の比較

| 方式 | メリット | デメリット | 本プロジェクトへの適合性 |
|---|---|---|---|
| **静的 Bearer (現状)** | 実装が最も単純 | 有効期限なし、漏洩リスク大 | 不適合 |
| **JWT (RS256/ES256)** | 標準仕様、ライブラリ豊富、クレーム拡張可能 | 鍵管理が複雑、トークンサイズ大 | 過剰 |
| **HMAC 署名付きトークン** | 軽量、有効期限埋め込み可能、サーバ側検証が簡単 | 標準仕様ではない | **最適** |
| **セッショントークン (DB 管理)** | 即時失効可能 | DB 依存、スケーラビリティ低 | 不適合 (DB なし) |

#### 選定理由

- **個人利用アプリ**であり、マルチテナントや権限分離は不要
- Gateway はファイルベースのストレージ（`~/.openclaw/workspace/memory/`）を使用し、**DB を持たない**
- OpenClaw の config からシークレットを取得可能（`gateway.auth.token` を署名鍵として流用）
- バックグラウンドタスク（音声アップロード、位置情報送信）が頻繁にあり、トークン検証は軽量であるべき

### トークン構造

```
base64url(payload) + "." + base64url(hmac_sha256(payload, secret))
```

**Payload:**
```json
{
  "iat": 1743552000,
  "exp": 1743555600,
  "type": "access"
}
```

| フィールド | 説明 |
|---|---|
| `iat` | 発行時刻 (Unix timestamp) |
| `exp` | 有効期限 (Unix timestamp) |
| `type` | `"access"` or `"refresh"` |

---

## 3. 有効期限とリフレッシュ戦略

### トークンライフサイクル

```
[初回設定] → [Access Token 発行] → [API 呼び出し] → [期限切れ]
                                                        ↓
                                              [Refresh Token で更新]
                                                        ↓
                                              [新 Access Token 発行]
```

### 有効期限の設定方針

| トークン種別 | 有効期限 | 根拠 |
|---|---|---|
| **Access Token** | **24 時間** | バックグラウンドタスクの継続性を確保しつつ、漏洩リスクを制限。iOS のバックグラウンド実行は数時間に及ぶため、短すぎると中断が頻発する |
| **Refresh Token** | **90 日** | QR コード再設定の手間を軽減。個人利用アプリのため、長めでもリスクは限定的 |
| **初回設定トークン** | **無期限 (現行互換)** | QR コードで配布する master token。これを使って最初の access/refresh token ペアを取得する |

### リフレッシュフロー

```
クライアント                          Gateway
    |                                   |
    |-- POST /api/auth/refresh -------→ |
    |   { refresh_token: "..." }        |
    |                                   |-- refresh token 検証
    |                                   |-- 新 access token 生成
    |                                   |-- (任意) 新 refresh token 生成
    |←-- { access_token, refresh_token }|
    |                                   |
    |-- 新 token で API 呼び出し ------→ |
```

### プロアクティブリフレッシュ

Access Token の残り有効期限が **20% 以下**（24 時間トークンなら残り約 5 時間以下）になった時点で、バックグラウンドでリフレッシュを試行する。これにより:

- ユーザーに期限切れを意識させない
- バックグラウンドタスクの中断を防ぐ
- ネットワーク一時不通でもリトライの余裕がある

---

## 4. プラットフォーム別実装方針

### 4.1 iPhone (iOS)

**トークン保存:**
- Access Token: Keychain (`bearerToken` キーを継続利用)
- Refresh Token: Keychain (新規キー `refreshToken`)
- 有効期限: Keychain (新規キー `tokenExpiry`) または UserDefaults (非機密情報)

**リフレッシュ戦略:**
- `TelemetryService` / `BackgroundURLSessionManager` の送信前にトークン有効期限をチェック
- 期限切れ間近の場合、送信前にリフレッシュを実行
- リフレッシュ失敗時: リトライキュー に入れ、次回送信時に再試行
- リフレッシュトークンも期限切れの場合: ローカル通知でユーザーに再設定を促す

**バックグラウンド考慮事項:**
- `BGAppRefreshTask` でトークンのプロアクティブリフレッシュをスケジュール
- WebSocket 再接続時にトークン有効性を確認
- Background URLSession のリクエストには現在有効なトークンを使用（期限切れの場合は delegate で検知）

**変更対象ファイル:**
- `KeychainHelper.swift` — refresh token / expiry 保存用キー追加
- `ConfigViewModel.swift` — トークンリフレッシュロジック追加
- `TelemetryService.swift` — 送信前のトークン検証
- `WebSocketClient.swift` — 再接続時のトークン検証
- `BackgroundURLSessionManager.swift` — 401 レスポンスハンドリング

### 4.2 AppleWatch (watchOS)

**トークン保存:**
- iPhone と同じ Keychain パターン (service: `com.recall.watch`)

**リフレッシュ戦略:**
- Watch は独立してリフレッシュを実行する（iPhone との直接的なトークン共有は行わない）
- 現状 App Group UserDefaults にはサーバー URL のみ共有しており、トークンは各デバイスの Keychain に独立保存されている。この設計を維持する
- Watch のバックグラウンド実行は iOS より制限が厳しいため、API 呼び出し時にオンデマンドでリフレッシュ

**変更対象ファイル:**
- `KeychainHelper.swift` (AppleWatch 版)
- `ConfigViewModel.swift` (AppleWatch 版)
- `TelemetryService.swift` (AppleWatch 版)
- `WebSocketClient.swift` (AppleWatch 版)

### 4.3 Chrome 拡張

**トークン保存:**
- Access Token: `chrome.storage.local` (既存の `lifelogSettings.token` を継続利用)
- Refresh Token: `chrome.storage.local` (新規フィールド `lifelogSettings.refreshToken`)
- 有効期限: `chrome.storage.local` (新規フィールド `lifelogSettings.tokenExpiry`)

**セキュリティ注記:**
- `chrome.storage.local` は暗号化されないが、Chrome 拡張のサンドボックス内でのみアクセス可能
- 拡張のマニフェストで `storage` 権限を宣言済み（変更不要）
- 将来的に `chrome.storage.session` (メモリ内、ブラウザ再起動で消去) への移行を検討可能

**リフレッシュ戦略:**
- `background.js` の Service Worker 内で、エントリ送信前にトークン有効期限をチェック
- 期限切れ間近の場合、送信前にリフレッシュ
- リフレッシュ失敗時: エントリをローカルキューに保持し、次回の `alarms` イベントでリトライ
- リフレッシュトークンも期限切れの場合: `chrome.action.setBadgeText` でユーザーに通知

**変更対象ファイル:**
- `lib/api.js` — リフレッシュロジック追加、401 ハンドリング
- `background.js` — トークン有効期限チェック、自動リフレッシュ
- `popup/popup.js` — トークン状態表示 (有効/期限切れ)

### 4.4 Gateway (サーバサイド)

**新規エンドポイント:**

| メソッド | パス | 認証 | 説明 |
|---|---|---|---|
| POST | `/api/auth/token` | Master Token | 初回トークン発行 (access + refresh) |
| POST | `/api/auth/refresh` | Refresh Token | Access Token 更新 |

**トークン検証の変更:**
- 現在の `verifyAuth()` (静的比較) を拡張
- まず署名付きトークンとしてパース → 成功すれば `exp` を検証
- パース失敗の場合、フォールバックとして現行の静的比較 (後方互換性)

**後方互換性:**
- 移行期間中は静的 Bearer トークン (master token) も引き続き受け付ける
- 全クライアントが移行完了後、静的トークンのフォールバックを無効化

**変更対象ファイル:**
- `auth.ts` — 署名付きトークン検証ロジック追加
- `index.ts` — `/api/auth/token`, `/api/auth/refresh` エンドポイント登録
- 新規: `token.ts` — トークン生成・検証ユーティリティ

---

## 5. エラーハンドリングとユーザー体験

### 401 レスポンス時のフロー

```
API 呼び出し → 401 Unauthorized
    ↓
Access Token でリフレッシュ試行
    ↓
  成功 → 新トークンで元のリクエストをリトライ
  失敗 → Refresh Token で再試行
           ↓
         成功 → 新トークンペアで元のリクエストをリトライ
         失敗 → ユーザーに再認証を要求
```

### プラットフォーム別のユーザー通知

| プラットフォーム | 通知方法 |
|---|---|
| iPhone | ローカル通知 + アプリ内バナー |
| AppleWatch | ローカル通知 |
| Chrome 拡張 | バッジテキスト + ポップアップ内メッセージ |

### バックグラウンドタスクの継続性

- **音声チャンクアップロード**: 401 受信時にリフレッシュを試行し、成功したら再送信。リフレッシュ失敗時はチャンクをローカルキューに保持
- **テレメトリバッチ送信**: 同上。バッチはローカルストレージに保持されるため、トークン復旧後に再送信
- **WebSocket 接続**: 切断 → リフレッシュ → 新トークンで再接続

---

## 6. 移行戦略

### フェーズ 1: Gateway にトークン発行・検証機能を追加

1. `token.ts` に HMAC 署名付きトークンの生成・検証ユーティリティを実装
2. `/api/auth/token` エンドポイント追加（master token で access + refresh を発行）
3. `/api/auth/refresh` エンドポイント追加
4. `verifyAuth()` を拡張（署名付きトークン検証 + 静的トークンフォールバック）

### フェーズ 2: クライアント側のリフレッシュ機構

1. Chrome 拡張にリフレッシュロジックを追加（変更範囲が最小のため先行）
2. iPhone アプリにリフレッシュロジックを追加
3. AppleWatch アプリにリフレッシュロジックを追加

### フェーズ 3: 静的トークンの廃止

1. 全クライアントが署名付きトークンに移行完了後、静的トークンフォールバックを無効化
2. QR コード設定フローを更新（master token → 初回トークン交換フローに変更）

---

## 7. 実装優先順位

| 優先度 | 作業 | 理由 | 見積 |
|---|---|---|---|
| **P0** | Gateway: `token.ts` — トークン生成・検証ユーティリティ | 全プラットフォームの前提 | 小 |
| **P0** | Gateway: `auth.ts` 拡張 — 署名付きトークン + フォールバック | 後方互換で安全に導入可能 | 小 |
| **P0** | Gateway: `/api/auth/token`, `/api/auth/refresh` エンドポイント | クライアントがトークンを取得・更新するために必須 | 中 |
| **P1** | Chrome 拡張: リフレッシュロジック | 変更範囲最小、テスト容易 | 小 |
| **P1** | iPhone: リフレッシュロジック + 401 ハンドリング | メインクライアント | 中 |
| **P2** | AppleWatch: リフレッシュロジック | iPhone と同パターン | 小 |
| **P2** | 全クライアント: プロアクティブリフレッシュ | UX 改善 | 中 |
| **P3** | 静的トークンフォールバック廃止 | 全移行完了後 | 小 |

---

## 8. セキュリティ考慮事項

| 項目 | 方針 |
|---|---|
| **署名アルゴリズム** | HMAC-SHA256 (Node.js `crypto.createHmac`) |
| **署名鍵** | OpenClaw config の `gateway.auth.token` を流用 (別途専用鍵の導入も可) |
| **タイミング攻撃対策** | 既存の `timingSafeEqual` を署名比較にも適用 |
| **トークン漏洩時** | Gateway の master token を変更 → 全トークン無効化 |
| **HTTPS 強制** | 既存の ATS 設定で HTTPS を強制済み (`ts.net` のみ例外) |
| **リプレイ攻撃** | Access Token の短寿命 (24h) で軽減。必要に応じて nonce を追加 |

---

## 9. 将来の拡張ポイント

- **JWT への移行**: マルチユーザー対応が必要になった場合、署名付きトークンから JWT (RS256) に移行。トークン構造が類似しているため移行コストは低い
- **スコープベースの権限分離**: `type` フィールドを拡張し、エンドポイント単位のアクセス制御を実装
- **トークン失効リスト (Revocation)**: DB 導入時にブラックリスト方式のトークン失効を追加
- **デバイスバインディング**: トークンにデバイス識別子を含め、デバイス紛失時の個別失効を可能にする
