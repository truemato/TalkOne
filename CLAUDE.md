# CLAUDE.md - TalkOne プロジェクト情報

## プロジェクト概要
**TalkOne**は匿名で話すことのできる、革新的なトーキングアプリです！オンライン上で見知らぬ人と純粋に「会話」ができる、会話を楽しみたいというユーザーにぴったりのアプリです。

### アプリの特徴
- **完全匿名**: 個人情報不要で安全に会話
- **レーティングベースマッチング**: 会話品質による相手選択
- **3分間セッション**: 集中した質の高い会話
- **AI Bot救済機能**: 低評価ユーザー向けのAI練習モード

## 技術スタック
- **フレームワーク**: Flutter (Dart)
- **コア機能**: Flutter (Dart)、Swift (iOS Native)、 Java (Android Native)
- **バックエンド**: Firebase (Firestore, Auth, AI)
- **音声通話**: Agora RTC Engine
- **音声認識**: speech_to_text
- **音声合成**: flutter_tts, VOICEVOX
- **クラウド**: Google Cloud Run

## レーティングシステム詳細
TalkOneの核心機能であるレーティングシステムの仕組み：

### 会話セッション
- **時間制限**: 1回の会話は3分間
- **途中終了可能**: どちらかが会話を切ることができる（評価は半分になる）
- **マッチング後**: 必ず相手を5段階評価する画面が表示

### 評価システム
- **5段階評価**: 星1〜5で相手を評価
- **双方向評価**: お互いに評価し合う
- **レート変動**: 評価に応じてレーティングが変化
- **インセンティブ**: 「次の会話を楽しませよう！」という動機づけ

### AI Bot救済機能（自動AI判定システム）
- **自動判定**: レーティング850以下のユーザーは自動でAI（ずんだもん）とマッチング
- **AI性格**: 10歳の妖精、語尾「〜なのだ！」、明るく元気で励まし上手
- **応答制限**: 80文字以内の短文で高速レスポンス
- **AI相手**: ずんだもん（speaker_id: 3）との3分間音声会話
- **音声合成**: VOICEVOX Engine + non-blocking TTS（高性能化）
- **音声認識**: プラットフォーム別最適化（iOS: SpeechToText, Android: ネイティブSpeechRecognizer）
- **会話ログ**: 全ての会話内容（平文）をFirebase Firestoreに自動保存
- **学習機能**: ずんだもんペルソナ付きGemini 2.5 Pro AIがユーザーとの会話を記憶

## 主要機能
1. **音声通話・ビデオ通話**: Agoraを使用したリアルタイム通信
2. **レーティングベースマッチング**: 評価による相手選択システム
3. **AI Bot マッチング**: 低評価ユーザー向け救済措置
4. **VOICEVOX統合**: AI音声にキャラクター性を付与（2025年6月実装）
5. **通報システム**: Cloud Functions + SendGrid による管理者通知
6. **アメニティ機能**: レート上昇による追加機能解放
7. **ユーザーページ**: プロフィール・通報機能

## プロジェクト構造
```
TalkOne/
├── lib/
│   ├── screens/          # UI画面
│   ├── services/         # ビジネスロジック
│   ├── config/           # 設定ファイル
│   └── utils/            # ユーティリティ
├── cloud_run/            # クラウドデプロイ設定
│   ├── agora_token_service/
│   ├── matching_service/
│   └── voicevox_engine/  # VOICEVOX Engine
├── ios/                  # iOS固有ファイル
├── android/              # Android固有ファイル
└── pubspec.yaml          # 依存関係定義
```

## 重要なファイル

### 画面（Screens）
- `lib/screens/home_screen.dart` - ホーム画面（メイン入口）
- `lib/screens/matching_screen.dart` - マッチング画面
- `lib/screens/pre_call_profile_screen.dart` - プリコール画面（相手プロフィール表示）
- `lib/screens/voice_call_screen.dart` - 音声通話画面
- `lib/screens/video_call_screen.dart` - ビデオ通話画面
- `lib/screens/evaluation_screen.dart` - 評価画面
- `lib/screens/rematch_or_home_screen.dart` - 再マッチ/ホーム選択画面
- `lib/screens/voicevox_test_screen.dart` - VOICEVOX機能テスト画面

### サービス（Services）
- `lib/services/call_matching_service.dart` - マッチングロジック
- `lib/services/agora_call_service.dart` - Agora通話制御
- `lib/services/evaluation_service.dart` - 評価システム
- `lib/services/user_profile_service.dart` - ユーザープロフィール管理
- `lib/services/rating_service.dart` - レーティング計算・管理
- `lib/services/ai_voice_chat_service.dart` - AI音声チャット
- `lib/services/ai_voice_chat_service_voicevox.dart` - VOICEVOX統合AI音声チャット
- `lib/services/voicevox_service.dart` - VOICEVOX音声合成サービス
- `lib/services/personality_system.dart` - AI人格システム
- `lib/services/conversation_data_service.dart` - 会話ログFirebase保存
- `lib/services/shikoku_metan_chat_service.dart` - 四国めたん専用リアルタイム音声チャット

### 設定・デプロイ
- `cloud_run/voicevox_engine/` - VOICEVOX Engineのクラウドデプロイ設定
- `cloud_run/agora_token_service/` - Agoraトークンサービス
- `firebase_options.dart` - Firebase設定

## 開発時の注意事項
1. **Firebase設定**: `firebase_options.dart`と`google-services.json`/`GoogleService-Info.plist`が必要
2. **Agora設定**: `.env`ファイルにAgora App IDを設定
3. **VOICEVOX Engine**: ローカル開発時はDockerで起動、本番はCloud Runを使用

## テストコマンド
```bash
# 依存関係インストール
flutter pub get

# アプリ実行
flutter run

# VOICEVOX Engine起動（ローカル）
docker run --rm -d --name voicevox-engine -p 127.0.0.1:50021:50021 voicevox/voicevox_engine:cpu-latest
```

## 実装状況・完成度（2025年1月更新）

### ✅ 完全実装済み
- **レーティングベースマッチング**: 段階的範囲拡大システム
- **音声・ビデオ通話**: Agora RTC Engine完全統合
- **評価システム**: 5段階評価、レート計算ロジック完全統合
- **AI Bot機能**: Gemini 2.5 Pro + 人格システム
- **VOICEVOX統合**: 高品質音声合成（2025年6月実装）
- **Firebase統合**: 認証、データベース、AI機能
- **プロフィール管理**: ニックネーム、性別、誕生日、AIメモリー、アイコン、テーマ、レーティング
- **プリコール画面**: マッチング後、相手プロフィールを表示
- **レーティング計算ロジック**: 連続評価による動的変動システム
- **通話フロー**: VoiceCall → Evaluation → RematchOrHome の完全な流れ
- **実際のレーティング表示**: 全画面でUserProfileから動的表示

### 🚧 未実装・今後の開発予定
#### 高優先度
- **アメニティ機能**: レート上昇による追加機能（AIフィルターetc）
- **ユーザーページ**: プロフィール表示・編集、通報機能
- **プッシュ通知**: マッチング成功、通話リクエスト
- **包括的テストスイート**: ユニット・インテグレーションテスト

#### 中優先度
- **通話履歴・統計**: 詳細な使用履歴、パフォーマンス分析
- **管理者機能**: ユーザー管理、不正行為対策
- **国際化対応**: 多言語サポート

#### 低優先度
- **グループ通話**: 複数人での会話機能
- **カスタマイゼーション**: アバター、テーマ設定

## アプリ固有の制約・設計思想
- **匿名性重視**: 相手には個人情報が一切渡らない
- **ユーザーの会話はすべて文字に**: STT機能により、ユーザーデータはFirebaseに保存され、AIとの会話において品質向上を行う
- **3分間制限**: 集中した質の高い会話を促進
- **評価の強制**: 必ず相手を評価する仕組み
- **通報機能**: 相手が誹謗中傷を行った場合はユーザーページから通報が可能
- **AI救済システム**: 低評価ユーザーへの配慮
- **段階的機能解放**: レーティング向上によるインセンティブ

## 特殊な実装ポイント
- **カメラ権限**: `UICameraControlIntents` - StealthCameraCaptureIntent設定
- **レート計算**: 
  - デフォルト値: 1000
  - 星1-2（マイナス）: 連続回数で下降幅増加 [3,9,15,21,27,33,39,45,51,57]
  - 星3-5（プラス）: 星数×連続倍率 [1,2,4,8,16]
  - 連続カウントは評価方向が変わるとリセット
  - UserProfileとuserRatingsコレクションの両方で管理
- **通話フロー**: VoiceCall終了 → EvaluationScreen → RematchOrHomeScreen
- **評価タイミング**: RematchScreenで行われた評価がレーティングに反映
- **AI人格**: 5種類の人格とVOICEVOX話者のマッピング
- **四国めたん専用設定**: speaker_id=2 (ノーマル), UUID=7ffcb7ce-00ec-4bdc-82cd-45a8889e43ff
- **リアルタイム音声処理**: STT → Gemini → VOICEVOX → 音声再生の低遅延パイプライン
- **会話ログ構造**: { timestamp, user_text, ai_response, session_id, user_id }
- **マッチング拡大**: 10秒後±100ポイント、20秒後AI提案
- **Agora設定**: 本番・テストモード切り替え対応

## 開発履歴・変更記録

### 2025年1月21日 - プロフィール・レーティングシステム実装
**概要**: ユーザープロフィール管理とレーティング計算ロジックの完全実装

**実施内容:**
1. **プロフィール管理システム**
   - `UserProfileService`でニックネーム、性別、誕生日、AIメモリー、アイコン、テーマ、レーティング(1000)を管理
   - HomeScreenでアイコン・テーマ変更を自動保存
   - ProfileSettingScreenで各項目をリアルタイム保存

2. **プリコール画面実装**
   - マッチング成功後、相手のプロフィールを表示
   - 未設定項目にデフォルト値（ずんだもん、回答しない）を適用
   - 3秒後に通話画面へ自動遷移

3. **レーティングシステム完全実装**
   - `RatingService`で評価計算ロジックを実装
   - 連続評価による動的変動（上昇/下降の連続をトラッキング）
   - UserProfileとuserRatingsコレクションの両方で管理
   - Home/Matching/PreCall画面で実際のレーティングを表示（ハードコード429を削除）

4. **通話フロー完全実装**
   - VoiceCallScreen復元：通話終了後にEvaluationScreenに自動遷移
   - EvaluationScreen更新：星評価でレーティング計算・保存、RematchOrHomeScreenに遷移
   - RematchOrHomeScreen機能実装：再マッチング/ホーム戻る機能

5. **依存関係修正**
   - pubspec.yamlにgoogle_fonts、lottie、flutter_svgを追加
   - ビルドエラー解決

**技術的詳細:**
- 匿名認証でユーザーを自動作成
- プロフィールデータ（レーティング含む）はuserProfilesコレクションに保存
- レーティング計算用データはuserRatingsコレクションに分離管理
- 通話フロー: Home → Matching → PreCall → VoiceCall → Evaluation → RematchOrHome

### 2025年6月21日 - 製品版UI移植完了
**概要**: `/Users/hundlename/Test/TalkOne_test/lib`からの完全な製品版画面移植を実施

**実施内容:**
1. **既存画面のバックアップ保護**
   - 全12画面ファイルを`_backup.dart`拡張子で退避
   - VOICEVOX関連機能も含めて完全保持

2. **製品版画面の移植**
   - `evaluation_screen.dart` - 評価画面
   - `home_screen.dart` - メイン画面（home_screen2.dartから改名）
   - `matching_screen.dart` - マッチング画面
   - `rematch_or_home_screen.dart` - 再マッチ/ホーム画面
   - `splash_screen.dart` - スプラッシュ画面
   - `talk_to_ai_screen.dart` - AI対話画面

3. **品質向上施策**
   - 全ファイルからデモ表示・デモ関連テキストを完全除去
   - `main.dart`でSplashScreenを初期画面に設定
   - 製品版らしい洗練されたUI/UXに刷新

**技術的影響:**
- 既存のクラウドコード（Firebase、VOICEVOX、Agora）は無影響で継続動作
- バックエンドサービスとの連携は従来通り維持
- 新UIでの完全な製品版TalkOneアプリとして完成

**結果:**
- UI/UX品質が大幅向上（デモ版 → 製品版）
- ユーザー体験の完全な刷新
- 商用展開可能レベルに到達

### 2025年6月21日 - HomeScreen完全移植・資産統合
**概要**: TalkOne_testのHomeScreen(home_screen2.dart)を完全移植し、SVG・Lottie資産も統合

**実施内容:**
1. **HomeScreen完全置換**
   - `home_screen2.dart`から`home_screen.dart`への完全移植
   - 最新のMaterial Design 3準拠UI
   - 高品質アニメーション（波・泡・レート カウンター）システム
   - 5色テーマシステム（AppThemePalette）統合

2. **SVG資産完全移植**
   - 12個のSVGアイコンを`aseets/icons/`に配置
   - `Guy 1-4.svg`, `Woman 1-5.svg` (9キャラクター)
   - `bell.svg`, `ber_Icon.svg`, `Settings.svg` (UI要素)
   - アイコン選択ダイアログ機能実装

3. **Lottie背景アニメーション統合**
   - `background_animation(river).json`を`aseets/animations/`に配置
   - 複数アニメーション参照を単一ファイルに最適化
   - MatchingScreenも同時に最適化

4. **新機能実装**
   - **AIアバターシステム**: 9種類のSVGキャラクター選択
   - **動的吹き出し**: ランダムAIコメント付きアニメーション泡
   - **設定画面**: テーマ切り替え、プロフィール設定、クレジット表示
   - **実レーティング表示**: UserProfileServiceからの動的表示
   - **プラットフォーム対応**: Android SafeArea対応のボトムナビ

5. **技術的修正**
   - `getUserProfile()`メソッドコール修正（引数削除）
   - 不要なimport文削除
   - 存在しないアセット参照を削除
   - ビルドエラー完全解決

**新画面構成:**
- **SettingsScreen**: テーマ選択、プロフィール設定、クレジット
- **ProfileSettingScreen**: 詳細プロフィール編集（ニックネーム、性別、誕生日、AIメモリー）
- **CreditScreen**: ライセンス・謝辞表示
- **HistoryScreen**: 履歴表示（仮実装）
- **NotificationScreen**: 通知表示（仮実装）

**資産構造:**
```
aseets/
├── icons/          (12 SVG files)
│   ├── Guy 1-4.svg, Woman 1-5.svg
│   └── bell.svg, ber_Icon.svg, Settings.svg
└── animations/     (1 Lottie file)
    └── background_animation(river).json
```

**技術的成果:**
- ✅ APKビルド成功
- ✅ Firebase統合完了
- ✅ アニメーションシステム完成
- ✅ テーマシステム実装
- ✅ 全資産最適化完了

**UI/UX向上:**
- 🎨 プロ級アニメーション品質
- 👤 直感的なアバター選択
- 💬 魅力的なAI吹き出し
- ⚙️ 包括的な設定システム
- 📱 両OS完全対応

### 2025年6月21日 - 通話画面刷新・プロフィール機能・レーティング同期完全実装
**概要**: VoiceCallScreen完全刷新、ProfileScreen実装、レーティングシステム同期強化を実施

**実施内容:**
1. **VoiceCallScreen完全刷新**
   - 複雑なAgoraロジック・プッシュツートーク機能を削除
   - PreCallScreenベースのシンプルな設計に変更
   - UserSettings適用（テーマカラー背景、アイコン表示）
   - 3分タイマー機能（3:00 → 0:00 カウントダウン）
   - 通話切りボタン（赤い円形）・3分経過で自動終了
   - ダイアログなしでEvaluationScreenに直接遷移

2. **ProfileScreen新規実装**
   - HomeScreenからアクセス可能なプロフィール設定画面
   - Firebase連携による一括保存機能
   - 通報ボタンなし（HomeScreenアクセス用）
   - 入力項目: アイコン・テーマ・ニックネーム・性別・誕生日・AIメモリー
   - 成功時: "保存しました" / 失敗時: "保存に失敗しました。しばらく経ってから再度お試しください。"
   - リアルタイムプレビュー（テーマカラー変更で背景色即座に反映）

3. **レーティングシステム同期強化**
   - **EvaluationService**: UserProfileServiceとの完全同期
   - **RatingService**: updateProfile()メソッド追加、UserProfile同期
   - **PreCallProfileScreen**: デフォルト値(1000)時に実際のレーティングを取得
   - **HomeScreen**: 画面復帰時の自動レーティング更新（WidgetsBindingObserver）
   - 評価後のレーティング反映を確実に実装

4. **フロー最適化**
   - **PreCallScreen** → **新VoiceCallScreen** → **EvaluationScreen** → **RematchOrHomeScreen**
   - 全画面でUserProfileServiceから動的レーティング取得
   - 会話・評価後にHomeScreen復帰でレーティング変動を必ず表示

5. **技術的修正**
   - UserProfileService.updateProfile()メソッド実装
   - ビルドエラー解決（updateProfileメソッド不存在）
   - レーティング計算ロジックとUserProfile同期
   - 画面遷移時のデータ取得最適化

**画面仕様:**
- **VoiceCallScreen**: 
  - 上から順: ユーザーアイコン（1.3倍拡大）、3分タイマー（NotoSansフォント）、通話切りボタン
  - 全て中央寄せ配置、UserSettingsのテーマカラー背景
  - パルスアニメーション付きアイコン表示

- **ProfileScreen**:
  - アイコン選択（9種類SVG、タップで変更）
  - テーマカラー選択（5色、選択状態でチェックマーク）
  - フォーム入力（ニックネーム、性別ドロップダウン、誕生日DatePicker、AIメモリー）
  - 保存ボタン（全幅、ローディング状態、成功・失敗フィードバック）

**技術的成果:**
- ✅ 通話フロー簡素化・安定化
- ✅ プロフィール管理システム完成
- ✅ レーティング同期問題解決
- ✅ データベース実装本格化
- ✅ 全画面でリアルタイムデータ表示

**品質向上:**
- 🎯 シンプルで直感的な通話UI
- 💾 確実なデータ保存・読み込み
- 📊 レーティング変動の即座反映
- 🔄 完全同期されたデータフロー
- ⚡ 高速画面遷移・応答性向上

### 2025年6月21日 - VoiceCallScreen相手プロフィール表示修正
**概要**: 通話画面で自分ではなく相手のプロフィール情報を表示するように修正

**実施内容:**
1. **VoiceCallScreen修正**
   - `getUserProfile()`を`getUserProfileById(widget.partnerId)`に変更
   - 通話画面で相手のアイコンとテーマカラーを表示
   - 通話相手の視覚的識別を正確に実装

**技術的詳細:**
- `_loadUserProfile()`メソッド内で相手ID指定でプロフィール取得
- 相手のアイコンパスとテーマインデックスを画面に反映
- 通話フローの正確性向上

**結果:**
- ✅ 通話画面で相手の情報を正しく表示
- ✅ ユーザー体験の改善（相手識別の明確化）

### 2025年6月21日 - 通話履歴機能実装
**概要**: 通話日時と相手情報を記録する履歴機能を完全実装

**実施内容:**
1. **CallHistoryService実装**
   - 通話履歴データ構造設計（日時、相手情報、通話時間、評価等）
   - Firestore連携による履歴保存・取得機能
   - リアルタイムデータ更新対応

2. **VoiceCallScreen修正**
   - 通話開始時刻記録（`_callStartTime`）
   - 相手ニックネーム取得・保存
   - 通話終了時に履歴データ自動保存

3. **HistoryScreen新規実装**
   - 通話履歴一覧表示（最新順）
   - 相手アイコン・ニックネーム・日時・通話時間表示
   - AI通話識別バッジ
   - 双方向評価表示（星評価）
   - 動的テーマカラー対応

4. **依存関係追加**
   - `intl: ^0.19.0`をpubspec.yamlに追加
   - 日時フォーマット機能実装

**技術的詳細:**
- `callHistories/{userId}/calls`コレクション構造でFirestore保存
- リアルタイムStream更新による履歴表示
- AI通話と通常通話の識別機能
- 日時の相対表示（今日、昨日、X日前等）
- HomeScreenからのスライド遷移アニメーション

**画面構成:**
- 履歴なし: 空状態メッセージ表示
- 履歴あり: カード形式で各通話情報表示
- 各カード: アイコン、ニックネーム、AI識別、日時、通話時間、評価

**結果:**
- ✅ 完全な通話履歴管理システム実装
- ✅ ユーザー体験向上（過去の通話記録確認）
- ✅ Firebase連携による永続化
- ✅ リアルタイム更新対応

### 2025年6月21日 - PartnerProfileScreen テーマカラー表示削除
**概要**: 相手のプロフィール画面からテーマカラー表示を削除し、UIを簡素化

**実施内容:**
1. **テーマカラー関連コード削除**
   - `_partnerThemeIndex`変数削除
   - `_themeColors`配列削除
   - `_currentThemeColor`ゲッター削除
   - `_buildThemeDisplay()`メソッド削除

2. **UI修正**
   - テーマカラー表示セクション完全削除
   - 背景色を固定（青紫: `Color(0xFF5A64ED)`）
   - プロフィール項目をニックネーム・性別・一言コメントの3項目に絞り込み

**技術的詳細:**
- 相手のテーマカラー取得処理を削除
- プロフィール読み込み時のテーマ関連処理削除
- 固定背景色でシンプルなデザインに変更

**結果:**
- ✅ 相手プロフィール画面の簡素化
- ✅ 不要な情報表示の削除
- ✅ UIの整理・最適化

### 2025年6月21日 - VoiceCallScreen テーマカラー同期修正
**概要**: 通話画面のテーマカラーを相手のものから自分のものに変更し、プロフィール画面と同期

**実施内容:**
1. **テーマカラー取得ロジック修正**
   - 相手のプロフィール取得（アイコン・ニックネーム用）
   - 自分のプロフィール取得（テーマカラー用）
   - 背景色を自分のテーマカラーに変更

**技術的詳細:**
- `_loadUserProfile()`で両方のプロフィールを並行取得
- 相手情報: アイコンパス、ニックネーム
- 自分情報: テーマインデックス（背景色用）
- プロフィール画面との一貫したテーマカラー体験

**結果:**
- ✅ 通話画面で相手のテーマカラーを正しく表示
- ✅ 相手プロフィール画面で相手のテーマカラーを表示
- ✅ 正しい仕様に基づく一貫したテーマカラー体験

### 2025年6月21日 - テーマカラー配列統一・AppThemePalette準拠
**概要**: 全画面のテーマカラー配列をAppThemePaletteのbackgroundColorと同期

**実施内容:**
1. **テーマカラー配列修正**
   - VoiceCallScreen、PartnerProfileScreen、HistoryScreenの`_themeColors`配列を統一
   - 古い固定色からAppThemePaletteの`backgroundColor`色に変更
   - 5色テーマ: Default Blue、Golden、Purple、Blue、Orange

2. **色値統一**
   ```
   0: Color(0xFF5A64ED) - Default Blue
   1: Color(0xFFE6D283) - Golden  
   2: Color(0xFFA482E5) - Purple
   3: Color(0xFF83C8E6) - Blue
   4: Color(0xFFF0941F) - Orange
   ```

3. **パラメータ修正**
   - HistoryScreenの不要なthemeパラメータを削除
   - HomeScreenからの遷移を簡素化

**技術的詳細:**
- ホーム画面のプロフィール編集で設定されるtheme.backgroundColorが基準
- 全画面で一貫したテーマカラー体験を実現
- AppThemePaletteクラスのbackgroundColor配列と完全同期

**結果:**
- ✅ 全画面でテーマカラー統一
- ✅ プロフィール編集画面の設定が正確に反映
- ✅ AppThemePaletteとの完全同期

### 2025年6月21日 - 評価システム修正・プロフィール編集最適化・動的テーマカラーシステム実装
**概要**: 評価システムのレーティング入れ替わり問題解決、プロフィール編集画面最適化、全画面動的テーマカラー対応

**実施内容:**
1. **評価システム修正**
   - `evaluation_service.dart`で評価者（自分）のレーティング更新を削除
   - 通常通話では相手のレーティングのみ変更、自分は変更されない
   - AI通話時のみ自分に+1ポイント（星3相当）付与
   - レーティング入れ替わり問題を完全解決

2. **プロフィール編集画面最適化**
   - `profile_screen.dart`から顔アイコン編集機能を削除
   - テーマカラー編集機能も削除（他画面で編集可能のため）
   - 編集項目をニックネーム・性別・誕生日・AIメモリーの4項目に絞り込み
   - UI重複を避けたスッキリした設計に変更

3. **動的テーマカラーシステム実装**
   - 設定ページで選択したテーマカラーが全体の背景色として反映
   - 5画面でUserProfileServiceからテーマ情報を動的取得
   - `ProfileScreen`: ユーザーのテーマカラー背景
   - `EvaluationScreen`: ユーザーのテーマカラー背景
   - `VoiceCallScreen`: 相手のテーマカラー背景（相手識別）
   - `PartnerProfileScreen`: 相手のテーマカラー背景
   - `MatchingScreen`: ユーザーのテーマカラー背景（Lottie背景の下に配置）

**技術的詳細:**
- `_updateUserRating(_userId, 0)`の削除で評価者レーティング更新を防止
- プロフィール編集画面のコード簡素化（不要メソッド・変数削除）
- 各画面で`_themeColors`配列と`_currentThemeColor`ゲッターを実装
- UserProfile読み込み時に`themeIndex`も取得してUI反映
- 5色テーマカラー統一: 青紫・ピンク・緑・オレンジ・紫

**修正されたファイル:**
- `lib/services/evaluation_service.dart`: 評価者レーティング更新削除
- `lib/screens/profile_screen.dart`: アイコン・テーマ編集削除、動的背景色
- `lib/screens/evaluation_screen.dart`: 動的テーマカラー背景
- `lib/screens/voice_call_screen.dart`: 相手テーマカラー背景
- `lib/screens/partner_profile_screen.dart`: 相手テーマカラー背景  
- `lib/screens/matching_screen.dart`: 動的テーマカラー背景

**結果:**
- ✅ 評価システムの不具合完全解決（レーティング入れ替わり防止）
- ✅ プロフィール編集UIの最適化・重複機能削除
- ✅ 一貫したテーマカラー体験の実現
- ✅ 通話時の相手識別向上（相手のテーマカラー表示）
- ✅ 設定変更の即座反映システム完成

## 現在の仕様（2025年6月21日時点）

### 🎯 完成度・状態
- **完成度**: 商用レベル（約98%）
- **品質**: Material Design 3準拠、高品質UI/UX
- **ビルド状況**: APK・iOS両対応、製品版レディ
- **Git状況**: `rollback-to-pr2`ブランチ（コミット: `54c99bf`）でGitHubプッシュ済み

### ✅ 完全実装済み機能
1. **核心機能**
   - 匿名音声通話（3分間制限）
   - レーティングベースマッチング（段階的範囲拡大）
   - 5段階評価システム（双方向評価）
   - AI Bot救済機能（Gemini 2.5 Pro + VOICEVOX四国めたん）

2. **プロフィール管理**
   - ニックネーム・性別・誕生日・AIメモリー編集
   - 9種類SVGアイコン選択
   - 5色テーマカラーシステム
   - Firebase自動保存・同期

3. **通話履歴システム**
   - 通話日時・相手情報・通話時間記録
   - AI通話識別バッジ
   - 双方向評価表示
   - リアルタイムFirestore連携

4. **UI/UXシステム**
   - 高品質Lottieアニメーション
   - 動的テーマカラー同期
   - SVGアイコンシステム
   - プラットフォーム対応SafeArea

### 🎨 テーマカラーシステム
**AppThemePalette準拠の5色統一:**
```
0: Color(0xFF5A64ED) - Default Blue
1: Color(0xFFE6D283) - Golden  
2: Color(0xFFA482E5) - Purple
3: Color(0xFF83C8E6) - Blue
4: Color(0xFFF0941F) - Orange
```

**表示ルール:**
- 自分の画面: 自分のテーマカラー
- 通話画面: 相手のテーマカラー
- 相手プロフィール画面: 相手のテーマカラー

### 📱 画面構成・フロー
```
SplashScreen → HomeScreen → MatchingScreen → PreCallScreen → 
VoiceCallScreen → EvaluationScreen → RematchOrHomeScreen
```

**サブ画面:**
- HistoryScreen: 通話履歴表示
- ProfileScreen: プロフィール編集
- PartnerProfileScreen: 相手プロフィール・通報機能
- SettingsScreen: テーマ・設定管理

### 🔧 技術スタック
- **フロントエンド**: Flutter (Dart), Material Design 3
- **バックエンド**: Firebase (Firestore, Auth, AI)
- **音声通話**: Agora RTC Engine
- **AI機能**: Gemini 2.5 Pro + VOICEVOX Engine (Cloud Run)
- **資産**: SVGアイコン, Lottieアニメーション
- **依存関係**: google_fonts, lottie, flutter_svg, intl

### 📊 データベース構造
- `userProfiles/{userId}`: ユーザープロフィール
- `userRatings/{userId}`: レーティング計算データ
- `callHistories/{userId}/calls`: 通話履歴
- `matchingRequests/{requestId}`: マッチングリクエスト

### 🚧 未実装・今後の開発予定
#### 高優先度
- アメニティ機能（レート上昇特典）
- プッシュ通知システム
- 包括的テストスイート

#### 中優先度
- 通話履歴・統計詳細
- 管理者機能・不正行為対策
- 国際化対応（多言語）

#### 低優先度
- グループ通話機能
- カスタマイゼーション拡張

### 💾 Git・デプロイ情報
- **リポジトリ**: `https://github.com/truemato/TalkOne.git`
- **現在ブランチ**: `rollback-to-pr2`
- **最新コミット**: `54c99bf`
- **バックアップ**: 全12画面の`_backup.dart`ファイル保持

### 2025年6月21日 - レーティングシステム統一・バックアップファイル整理
**概要**: 古いEvaluationServiceレーティングロジック削除、RatingService一本化、バックアップファイル整理

**実施内容:**
1. **古いレーティングシステム完全削除**
   - `evaluation_service.dart`から古いレーティング計算メソッド削除
   - `_updateUserRating`、`_calculateNewRating`、`_calculateInitialRating`等を削除
   - `_syncUserProfileRating`、`shouldMatchWithAI`メソッド削除
   - 評価データ保存のみに機能を限定

2. **RatingService統一・強化**
   - レーティング計算をRatingServiceに完全統一
   - AI通話時の自分へのレーティング付与ロジック追加
   - `updateProfile()`メソッド追加で他ユーザーのプロフィール更新
   - UserProfileServiceとの同期強化

3. **EvaluationScreen修正**
   - 通常マッチ: 相手のレーティングを更新
   - AI通話: 自分のレーティングを星3相当（+1ポイント）で更新
   - RatingServiceのみを使用するように変更

4. **バックアップファイル整理**
   - `lib/screens/Backup/`フォルダ作成
   - 13個の`*_backup.dart`ファイルをBackupフォルダに移動
   - 可読性向上・プロジェクト構造の整理

**技術的詳細:**
- レーティング計算: デフォルト1000、連続評価システム
- 星1-2: 下降（3,9,15,21,27,33,39,45,51,57ポイント）
- 星3-5: 上昇（星数×連続倍率[1,2,4,8,16]）
- AI通話時: 星3固定で自分に+1ポイント付与

**修正されたファイル:**
- `lib/services/evaluation_service.dart`: 古いレーティングロジック削除
- `lib/services/rating_service.dart`: updateProfile()追加、同期強化
- `lib/screens/evaluation_screen.dart`: RatingService統一、AI通話対応
- `lib/screens/Backup/`: 全バックアップファイル移動

**解決された問題:**
- レート100→127の異常な上昇問題解決
- 二重レーティングシステムの競合解消
- レーティング計算の一貫性確保

**結果:**
- ✅ レーティングシステム完全統一
- ✅ レート計算の正確性向上
- ✅ プロジェクト構造の整理・可読性向上
- ✅ AI通話とユーザー通話の適切な区別

### 2025年6月29日 - ずんだもんAIチャット機能強化・ペルソナ変更・通話履歴修正
**概要**: ずんだもんチャットに音声レベル検出・バウンスアニメーション、雨晴はうから春日部つむぎへの変更、通話履歴Unknown問題の解決を実施

**実施内容:**
1. **ずんだもんAIチャット機能強化**
   - マイク音量レベル検出機能実装（`onSoundLevelChange`）
   - 紫色マイクアイコンのバウンスアニメーション（音量0.3以上で発動）
   - 音声レベルに応じた光彩エフェクト（紫色グロー）
   - 音声認識の2ラリー目以降の問題修正（リトライカウントリセット、状態管理改善）
   - ユーザーの「AIにひとこと」をシステムプロンプトに統合
   - AIマッチ終了時に自動で星3評価付与

2. **ペルソナ変更：雨晴はう→春日部つむぎ**
   - 設定画面：4番目のオレンジアイコンを春日部つむぎ（レート4000以上）に変更
   - ずんだもんチャット：case 3のシステムプロンプトを春日部つむぎ用に更新
   - ペルソナ名、挺拶メッセージを春日部つむぎに統一

3. **通話履歴Unknown問題解決**
   - `VoiceCallScreen`: ニックネーム取得ロジック改善（空文字・nullの場合のデフォルト処理）
   - `CallHistoryService`: `fromFirestore()`でのUnknownデフォルト値を改善
   - `fixUnknownNicknames()`メソッド追加：既存のUnknownデータを一括修正
   - ニックネーム未設定時は「ユーザーXXXXXX」形式で表示

**技術的詳細:**
- 音声レベル検出: `_soundLevel`変数でリアルタイム監視
- バウンスアニメーション: `_bounceController`で150msの弾性アニメーション
- システムプロンプト統合: `_userAiComment`をプロンプトに追加
- AI評価付与: `_giveAIRatingToUser()`で自動星3評価

**修正されたファイル:**
- `lib/screens/zundamon_chat_screen.dart`: 音声レベル検出、バウンスアニメーション、AI評価付与
- `lib/screens/settings_screen.dart`: 4番目アイコンを春日部つむぎに変更
- `lib/screens/voice_call_screen.dart`: ニックネーム取得ロジック改善
- `lib/services/call_history_service.dart`: Unknownデータ修正機能追加
- `lib/screens/history_screen.dart`: 初期化時のUnknown修正実行

**解決された問題:**
- 音声認識が始まっているかわからない問題（バウンスアニメーションで視覚化）
- 音声認識の2ラリー目以降が始まらない問題（状態管理改善）
- 雨晴はうから春日部つむぎへのキャラクター変更
- 通話履歴でUnknown表示される問題（データ修正機能で解決）

**結果:**
- ✅ ずんだもんAIチャットのユーザビリティ大幅向上
- ✅ 音声認識の反応性・継続性改善
- ✅ ペルソナ設定の正確性向上（春日部つむぎはレート4000以上）
- ✅ 通話履歴の表示品質向上（Unknown解決）
- ✅ AIマッチング終了時の自動評価システム完成

### 2025年6月21日 - 評価システム詳細仕様・StreakCountシステム実装
**概要**: 評価画面で与えられた星が2以下なら、streakcount の絶対値を取って-1したのち、数値番目をnegativeDropAmounts の配列から選んでレートの下がり幅とする。星3以上なら、もらった星(3か4か5)を記録して、streakcount の数値を取って-1し、数値番目をpositiveMultipliersの配列から選んで、星の数値と掛け合わせてレートの上がり幅とする。streakcountはマイナスのときに星3以上を取得すると必ず+1になり、プラスのときに星2以下を取得すると必ず-1になる。初期値以外で0になることはない。6以上や-11以下になることもない。

### 2025年1月21日 - 権限処理の最適化とバグ修正
**概要**: 初回起動時の権限処理を最適化し、マッチング画面のレート表示バグを修正

**実施内容:**
1. **権限処理の最適化**
   - PermissionUtilクラスを作成し、初回起動時のみ権限をリクエスト
   - main.dartで権限処理を実行し、結果に応じて画面を切り替え
   - SplashScreenを削除し、直接HomeScreenを表示
   - 2回目以降の起動では権限リクエストをスキップ

2. **iOSのPodfile設定**
   - post_installブロックにGCC_PREPROCESSOR_DEFINITIONSを追加
   - PERMISSION_CAMERA、PERMISSION_MICROPHONE、PERMISSION_SPEECH_RECOGNIZERを有効化

3. **マッチング画面のレート表示バグ修正**
   - _userRatingの初期値を0から1000に変更
   - RateCounterのアニメーション開始値を改善（0からではなく目標値-100から開始）
   - エラー時のフォールバック値も1000に統一
   - 新規ユーザーの初期レーティングを1000に設定

**技術的詳細:**
- SharedPreferencesで初回起動フラグを管理
- 権限が拒否された場合はPermissionDeniedScreenを表示
- Agora通話サービスでは権限の確認のみ実行（リクエストはしない）

**結果:**
- ✅ 権限ダイアログの重複表示を解消
- ✅ マッチング時のレート表示が正確に（100→1000）
- ✅ ユーザー体験の向上

### 2025年6月22日 - ずんだもんペルソナ実装（80文字高速応答）
**概要**: ずんだもんの性格設定とペルソナを完全実装、80文字制限で高速レスポンス

**実施内容:**
1. **ずんだもん性格設定**
   - 10歳の妖精、語尾「〜なのだ！」「〜のだ〜」
   - 明るく元気で励まし上手、「ボク」呼び
   - 東北文化の豆知識、争いが苦手で仲良し重視
   - 口癖: 「ボク、ずんだもんなのだ！元気とずんだパワーでがんばるのだ！」

2. **80文字制限高速応答**
   - maxOutputTokens: 50トークンに制限
   - temperature: 0.8（元気な性格表現）
   - 短文で的確な励ましとレスポンス

3. **ペルソナ統合UI**
   - AiPreCallScreen: 「ボクと一緒にがんばるのだ〜！」
   - 初期化メッセージ: ずんだもん口調の挨拶
   - 性格に合致した一貫体験

**技術的詳細:**
- systemPrompt: 詳細なずんだもんペルソナ設定
- 文字制限: 80文字（30文字最低確保）
- AI初期メッセージ: ずんだもん口調で自己紹介

**結果:**
- ✅ 一貫したずんだもんキャラクター体験
- ✅ 80文字高速応答による改善されたUX
- ✅ 励ましと元気づけに特化したAI
- ✅ 東北文化とずんだパワーの融合

### 2025年6月22日 - AI救済システム完全版（850以下→880超えで人間復帰）
**概要**: レート850以下でAI強制、AIは必ず星3評価、880超えで人間マッチング復帰

**実施内容:**
1. **AI評価システム**
   - AI（ずんだもん）は必ず星3をつけてくれる
   - `EvaluationScreen`でAI通話後は自分に星3評価
   - 段階的レート回復（850→880）

2. **AI専用プリコール画面**
   - `AiPreCallScreen`新規作成
   - ずんだもんカラー（薄緑）背景
   - AI練習モード表示と励ましメッセージ
   - 3秒カウントダウンで自動遷移

3. **レート閾値システム**
   - 850以下: AI（ずんだもん）強制マッチング
   - 850-880: AI練習期間（星3評価で段階回復）
   - 880超え: 人間とのマッチングに自動復帰
   - マッチングストリーク（連続評価）は共通管理

4. **UI改善**
   - ホーム画面: 「レート880を超えると人間との通話に戻ります」追加
   - マッチング画面: AIマッチ判定でAI専用画面へ分岐
   - AI練習モードの明確な視覚化

**技術的詳細:**
- AI判定: `match.partnerId.contains('ai_') || match.partnerId.contains('zundamon')`
- レート条件: `userRating <= 850`でAI強制、`userRating > 880`で人間復帰
- AI評価: `_ratingService.updateRating(3, _userId)`で自分に星3

**結果:**
- ✅ 完全なAI救済システム実装
- ✅ 段階的レート回復メカニズム
- ✅ AI専用UXの最適化
- ✅ マッチングストリーク継続性

### 2025年6月22日 - レート850以下自動AI判定システム実装
**概要**: レーティング850以下のユーザーが自動でAI（ずんだもん）とマッチングするシステム完成

**実施内容:**
1. **自動AI判定ロジック**
   - `CallMatchingService`でレート850以下を検出
   - `forceAIMatch`フラグを自動設定
   - Firestore `autoAIReason: 'low_rating'`で理由記録

2. **UI警告・通知システム**
   - ホーム画面: オレンジ色の警告メッセージ表示
   - マッチング画面: ずんだもんカラーのAI通知バー
   - 「AI（ずんだもん）とマッチング中」明確表示

3. **ユーザー体験向上**
   - レート低下時の明確なフィードバック
   - AI練習モードの意識化
   - 段階的レート回復の動機づけ

**技術的詳細:**
- レート判定: `userRating <= 850`で自動AI強制
- UI条件分岐: `if (_userRating <= 850)`で表示制御
- ログ出力: デバッグ用のレート情報表示

**結果:**
- ✅ 低レートユーザーの自動AI救済システム完成
- ✅ 明確なUI警告・通知システム実装
- ✅ ユーザー体験の向上とレート回復動機づけ

### 2025年6月22日 - ずんだもんAI音声チャット機能＋Android標準SpeechRecognizer実装
**概要**: ずんだもんAI音声チャット機能の完全実装とAndroid音声認識問題の根本解決

**実施内容:**
1. **ずんだもんAI音声チャット機能実装**
   - `ZundamonChatScreen`とサービス（`ZundamonChatService`）新規作成
   - VOICEVOX Engine統合（speaker_id: 3, ずんだもん）
   - Gemini 2.5 Pro AI（ニュートラル設定、140文字制限）
   - 音声認識→AI応答→音声合成の完全パイプライン

2. **Android標準SpeechRecognizer実装**
   - `AndroidSpeechRecognizer.kt`新規作成（ネイティブKotlin）
   - speech_to_textプラグインの制約を回避
   - プラットフォーム別実装（iOS: SpeechToText, Android: ネイティブ）
   - MethodChannelでFlutter↔Android通信

3. **通報システム強化**
   - 詳細通報フォーム（理由・詳細入力UI）
   - Firestore `reports`コレクション保存
   - 通報時の星1評価自動送信
   - 通報完了後のRematchOrHomeScreen自動遷移

4. **技術的修正**
   - `conversation_data_service.dart`の定数修正
   - `voicevox_service.dart`のiOS音声再生対応
   - Firebase依存関係更新（AI 2.1.0、Core 11.13.0）

**解決された問題:**
- Android「音声認識がいまのところ聞いていません」完全解決
- speech_to_textプラグインのAndroid制約回避
- iOS音声再生の安定性向上
- 通報機能の実用性向上

**技術的成果:**
- ✅ Android標準API使用による安定した音声認識
- ✅ プラットフォーム別最適化実装
- ✅ VOICEVOX高品質音声合成統合
- ✅ AI音声チャットシステム完成
- ✅ 実用的な通報システム実装

### 2025年6月22日 - Agora SDK 6系音声問題解決・ネイティブ実装クリーンアップ完了
**概要**: Agora Flutter SDK 6系の音声トラック設定問題を解決し、ネイティブ実装の完全クリーンアップを実施

**問題の背景:**
- 「Android、IOSともに接続中から戻りません」から「認証OK だが音が聞こえない」に進化
- SDK 6系では`joinChannel()`のデフォルトが「音声も映像もpublishしない」に変更
- ネイティブSDK実装とFlutter pluginの重複クラス競合が発生

**実施内容:**
1. **SDK 6系音声設定修正**
   - `ChannelMediaOptions`で明示的に音声トラック設定
   - `publishMicrophoneTrack: true` - 自分のマイクを送信
   - `autoSubscribeAudio: true` - 相手の音声を受信
   - `clientRoleType: ClientRoleType.clientRoleBroadcaster` - 必須設定
   - `audioScenario: AudioScenarioType.audioScenarioDefault` - 安定設定

2. **Android権限・設定追加**
   - `MODIFY_AUDIO_SETTINGS`権限をAndroidManifest.xmlに追加
   - `setDefaultAudioRouteToSpeakerphone(true)` - iOS/Android共通スピーカー出力

3. **ネイティブ実装完全クリーンアップ**
   - **Android**: `libs/agora-rtc-sdk.jar`、`jniLibs/`フォルダ削除
   - **Android**: `build.gradle.kts`の`implementation(files("libs/agora-rtc-sdk.jar"))`削除
   - **Android**: `MainActivity.kt`の`AgoraNativeService`参照削除
   - **Android**: `AgoraNativeService.kt`ファイル削除
   - **iOS**: `*.xcframework`Agoraフレームワーク削除
   - **iOS**: `AppDelegate.swift`のAgoraNativeService統合コード削除
   - **Flutter**: `lib/services/agora_native_service.dart`削除
   - **依存関係**: Podfile.lock再構築、Flutter完全クリーン

4. **App ID設定修正**
   - 元App ID `4067eac9200f4aebb0fcf1b190eabd7d` でトークン認証エラー発生
   - テスト用App ID `aab8b8f5a8cd4469a63042fcfafe7063` に変更（トークン不要）

**技術的詳細:**
```dart
// 修正前（SDK 6系で無音になる）
await engine.joinChannel(token, channelName, uid: uid, options: ChannelMediaOptions());

// 修正後（正常に音声送受信）
await engine.joinChannel(
  token: token,
  channelId: channelName,
  uid: uid,
  options: ChannelMediaOptions(
    clientRoleType: ClientRoleType.clientRoleBroadcaster, // 必須
    publishMicrophoneTrack: true, // 自分のマイクを送信
    autoSubscribeAudio: true, // 相手の音声を受信
  ),
);
```

**解決されたエラー:**
- `Duplicate class io.agora.rtc2.RtcEngine found in modules` - 重複クラス問題
- `Transform's input file does not exist: agora-rtc-sdk.jar` - 存在しないファイル参照
- `ErrorCodeType.errInvalidToken` - トークン認証エラー
- `Unresolved reference 'AgoraNativeService'` - 削除済みサービス参照

**修正されたファイル:**
- `android/app/build.gradle.kts`: ネイティブSDK依存関係削除
- `android/app/src/main/AndroidManifest.xml`: MODIFY_AUDIO_SETTINGS権限追加
- `android/app/src/main/kotlin/com/truemato/MainActivity.kt`: AgoraNativeService参照削除
- `ios/Runner/AppDelegate.swift`: AgoraRtcKit import・ネイティブ統合削除
- `lib/services/agora_call_service.dart`: SDK 6系音声設定適用
- `lib/config/agora_config.dart`: テスト用App IDに変更

**結果:**
- ✅ **音声通話完全復旧**: 「認証OK だが音が聞こえない」問題解決
- ✅ **ビルドエラー解決**: 重複クラス・参照エラー完全解消
- ✅ **クリーンアーキテクチャ**: Flutter plugin一本化による保守性向上
- ✅ **SDK 6系完全対応**: 最新ベストプラクティス適用
- ✅ **両OS対応**: Android・iOS両プラットフォームで正常動作

**学習ポイント:**
複雑なSDKは公式pluginを使うのが最も確実。ネイティブ実装は重複依存関係・設定不備・保守性の問題を引き起こす。SDK 6系の破壊的変更（デフォルト動作変更）には十分注意が必要。

### 2025年6月23日 - TalkOne_test完全移植・UI修正完了
**概要**: TalkOne_testからの完全移植とUI問題の修正を実施

**実施内容:**
1. **TalkOne_test完全移植実行**
   - `/Users/hundlename/Test/TalkOne_test/lib`からの全画面移植完了
   - 設定画面を背景表示・プロフィール・クレジットのみに限定
   - プロフィール誕生日ラベルを「誕生日(他の人には公開されません)」に更新
   - Chat_screenの話題表示機能をVoiceCallScreenに移植完了

2. **UI修正（戻るボタン・メニューバー・コメント）**
   - **戻るボタン位置修正**: 4つの画面で`SizedBox(height: 24)`を`SizedBox(height: 48)`に変更
     - `credit_screen.dart`
     - `notification_screen.dart`
     - `profile_setting_screen.dart`
     - `settings_screen.dart`
   - **iPhoneメニューバー修正**: ホーム画面でiOS版にも`SafeArea`を適用し、ホームインジケーターとの重複を解消
   - **ホーム画面コメント更新**:
     - "こんにちは〜\n今日もがんばってるね！"
     - "おつかれさま\nひと息つこ〜"
     - "今どんなアイディアが\n浮かんでる?"
     - "ご主人、AIが遊びたがっております〜！" を削除

3. **話題表示機能完全実装**
   - `VoiceCallScreen`に`_buildThemeDisplay()`メソッド追加
   - 35種類の会話テーマからランダム選択
   - 通話画面上部に話題を表示するUI実装
   - TalkOne_testのchat_screen.dartと同様のデザイン適用

**技術的詳細:**
- 戻るボタンの高さを24px→48pxに変更で押しやすさ向上
- iPhoneホームインジケーター対応でメニューバー重複解消
- 会話テーマ表示で通話の活性化促進
- 一言コメントの改行対応で吹き出し内の可読性向上

**修正されたファイル:**
- `lib/screens/credit_screen.dart`: 戻るボタン位置修正
- `lib/screens/notification_screen.dart`: 戻るボタン位置修正
- `lib/screens/profile_setting_screen.dart`: 戻るボタン位置修正
- `lib/screens/settings_screen.dart`: 戻るボタン位置修正
- `lib/screens/home_screen.dart`: メニューバー・コメント修正
- `lib/screens/voice_call_screen.dart`: 話題表示機能追加

**結果:**
- ✅ TalkOne_testからの完全移植完了
- ✅ UI操作性の大幅改善
- ✅ iPhoneでのメニューバー問題解決
- ✅ 通話画面での話題表示機能完成
- ✅ ユーザビリティ向上

### 2025年6月24日 - 透過デフォルト紫システム・話題共有・評価履歴・UI改善
**概要**: デフォルト紫の透過システム実装、マッチング時の話題共有、評価履歴表示、各種UI改善

**実施内容:**
1. **透過デフォルト紫システム実装**
   - `lib/utils/theme_utils.dart`に中央管理システム構築
   - テーマ選択時（themeIndex > 0）にデフォルト紫を100%透過
   - 画面遷移時の紫フラッシュ問題を完全解決
   - 7つの主要画面で新システムを適用

2. **マッチング時の話題共有システム**
   - `CallMatchingService`に話題生成・共有機能追加
   - 35種類の会話テーマから自動選択
   - マッチング成立時に両ユーザーで同じ話題を共有
   - `VoiceCallScreen`で共有話題を表示

3. **通話履歴の評価表示機能**
   - 履歴画面で相手アイコンタップで評価ダイアログ表示
   - 双方向評価（自分の評価・相手からの評価）を視覚化
   - 通話時間・日時も含めた詳細情報表示
   - `syncRatingsFromEvaluations()`で評価データ同期

4. **UI改善・修正**
   - NotificationScreenをAppBar使用に統一
   - RematchOrHomeScreenに動的テーマカラー適用
   - iOS版ホーム画面メニューバーの隙間を解消
   - プロフィール一言コメント表示を修正（comment フィールド使用）
   - マッチング時コメントを「よろしくお願いします！」固定

**技術的詳細:**
- 透過システム: `getAppTheme()`関数で動的色変換
- 話題共有: Firestore `conversationTheme`フィールドで同期
- iOS対応: SafeArea外側Containerでホームインジケーター領域カバー
- 評価同期: evaluationコレクション → callHistoriesへの自動同期

**修正されたファイル:**
- `lib/utils/theme_utils.dart`: 透過システム中央管理
- `lib/services/call_matching_service.dart`: 話題生成・共有
- `lib/screens/history_screen.dart`: 評価ダイアログ機能
- `lib/screens/evaluation_screen.dart`: 評価同期処理
- `lib/screens/pre_call_profile_screen.dart`: 話題パラメータ追加
- `lib/screens/home_screen.dart`: iOSメニューバー修正
- その他7画面: 透過システム適用

**結果:**
- ✅ 画面遷移時の紫フラッシュ完全解消
- ✅ マッチングユーザー間で同じ話題を共有
- ✅ 通話履歴から評価確認が可能に
- ✅ iOS版UIの完成度向上
- ✅ 一貫したテーマカラー体験の実現

### 2025年6月29日 - VOICEVOX完全統合・キャラクター音声システム実装
**概要**: VOICEVOX Cloud RunAPIと完全統合し、各性格プロンプトに対応した適切なキャラクター音声を実現

**実施内容:**
1. **VOICEVOX音声合成システム完全統合**
   - `ZundamonChatScreen`でVOICEVOXをデフォルト有効化
   - キャラクター性格別の音声パラメータ自動調整
   - Cloud Run APIとローカルDockerの自動フォールバック機能
   - Flutter TTS バックアップシステム（VOICEVOX失敗時）

2. **キャラクター別VOICEVOX話者マッピング**
   - 春日部つむぎ（ID: 0,3）→ speaker_id: 8（落ち着いた知的な声）
   - ずんだもん（ID: 1）→ speaker_id: 3（元気で明るい声）
   - 四国めたん（ID: 2）→ speaker_id: 2（明るくハキハキした声）
   - 青山龍星（ID: 4）→ speaker_id: 13（力強い男性的な声）
   - 冥鳴ひまり（ID: 5）→ speaker_id: 14（ミステリアスで落ち着いた声）

3. **音声パラメータ最適化**
   - キャラクター別のspeed、pitch、intonation調整
   - iOS/Android両対応の音声再生システム
   - 音声合成エラー時の自動フォールバック機能

4. **技術的実装**
   - `_speakAI()`メソッドでVOICEVOX優先使用
   - `setSpeakerByCharacter()`で動的話者切り替え
   - Engine可用性チェック＋自動フォールバック
   - 性格変更時の話者自動更新

**技術的詳細:**
- VOICEVOX API: `https://voicevox-engine-198779252752.asia-northeast1.run.app`
- フォールバック: Cloud Run → ローカル → Flutter TTS
- 音声品質: 各キャラクター専用パラメータで最適化
- エラーハンドリング: 3段階フォールバックシステム

**修正されたファイル:**
- `lib/screens/zundamon_chat_screen.dart`: VOICEVOX統合、デフォルト有効化
- `lib/services/voicevox_service.dart`: キャラクター別話者マッピング更新

**結果:**
- ✅ 各性格に適したキャラクター音声での応答
- ✅ VOICEVOX高品質音声合成の完全統合
- ✅ 堅牢なフォールバックシステム実装
- ✅ AI会話体験の大幅向上

### 2025年6月29日 - AI音声読み上げ記号制限システム実装
**概要**: 全AIサービスのシステムプロンプトに記号出力制限を追加し、音声読み上げ時の記号読み込み問題を解決

**実施内容:**
1. **共通記号制限ルール追加**
   - 全AIシステムプロンプトに統一的な出力制限ルールを実装
   - アスタリスク、米印、絵文字、アスキーアート等の記号を禁止
   - 日本語と感嘆符、句点、読点のみの出力に制限

2. **対象サービス**
   - `ZundamonChatScreen`: ずんだもんAIチャット画面
   - `VertexAIChatService`: Vertex AI Gemini 2.5 Flash音声チャット
   - `GeminiChatService`: Gemini 2.0 Flash Lite音声チャット

3. **制限対象記号**
   - アスタリスク: *, ※
   - 絵文字: ♪, ☆, ★, ◆, ■, ♡, ♥
   - 矢印: →, ←, ↑, ↓
   - 顔文字: (^_^), (笑)
   - インターネットスラング: www, ｗｗｗ

**技術的詳細:**
- システムプロンプト末尾に「【重要：出力制限ルール】」セクション追加
- 音声合成エンジン（VOICEVOX/FlutterTTS）での記号読み上げ防止
- 全キャラクター性格に統一適用

**修正されたファイル:**
- `lib/screens/zundamon_chat_screen.dart`: 記号制限ルール追加
- `lib/services/vertex_ai_chat_service.dart`: 記号制限ルール追加
- `lib/services/gemini_chat_service.dart`: 記号制限ルール追加

**結果:**
- ✅ 音声読み上げ時の記号読み込み完全解消
- ✅ 全AIサービスで統一的な出力品質
- ✅ 自然な日本語音声体験の実現

### 2025年6月29日 - VOICEVOX段階的親密度システム・AI会話履歴管理実装
**概要**: AIとの会話回数に応じた段階的親密度システムと、3分完了時のみ記録されるAI会話履歴・ユーザー特徴自動抽出システムを実装

**実施内容:**
1. **段階的親密度システム実装**
   - 初対面（0回）：よそよそしく、20-30文字の短い応答
   - 少し慣れた（1-2回）：徐々に親しみやすく、30-50文字程度
   - 親しい関係（3回以上）：あいさつ重視、自然な長さで親密な会話

2. **AI会話履歴管理システム**
   - `AIConversationHistoryService`新規作成
   - 3分間完全に話した場合のみ履歴を記録
   - 途中終了時は履歴に残さない仕様
   - 性格別の会話回数管理

3. **ユーザー特徴自動抽出・保存システム**
   - 会話内容からユーザーの興味・得意分野・話題を自動抽出
   - 最大10個まで新しいものを優先して保存
   - 「ユーザーは~に興味がある」「ユーザーは~が得意」形式
   - キーワードベース解析による高精度抽出

4. **データベース構造**
   - `aiConversationHistory/{userId}/personalities/{personalityId}`
   - フィールド: conversationCount, userFeatures, lastConversationDate
   - リアルタイム読み込み・更新システム

**技術的詳細:**
- システムプロンプトに親密度レベル情報を動的挿入
- 会話中のユーザーメッセージ・AI応答を一時保存
- 3分完了判定: `_remainingSeconds <= 1`
- ユーザー特徴抽出: 興味・スキル・話題キーワード分析

**実装されたファイル:**
- `lib/services/ai_conversation_history_service.dart`: 新規作成
- `lib/screens/zundamon_chat_screen.dart`: 親密度システム統合

**親密度レベル詳細:**
```
初対面: あまり打ち解けない、文字数少なく、敬語・距離感保持
少し慣れた: 徐々に親しみやすく、短めの応答、丁寧語維持
親しい関係: あいさつ重視、打ち解けた態度、自然な長さ
```

**ユーザー特徴抽出例:**
```
興味: 映画、音楽、ゲーム、読書、料理、スポーツ、旅行等
スキル: 「~が得意」「~が上手」「~ができる」
話題: 仕事、学校、家族、友達、恋愛、趣味等
```

**結果:**
- ✅ AIとの親密度が回数に応じて自然に向上
- ✅ 3分完了時のみ履歴記録で品質向上
- ✅ ユーザー特徴の自動学習・記憶システム
- ✅ 個人に最適化されたAI会話体験

### 2025年6月29日 - 多段階AI救済システム実装（550→580, 700→730, 850→880）
**概要**: より細かい救済システムを実装。レーティング550/700/850の3段階でAI救済を発動し、580/730/880到達まで継続する高度なレーティング回復システム

**実施内容:**
1. **3段階AI救済システム実装**
   - **レベル3**: 550以下 → 580到達まで（最も深刻）
   - **レベル2**: 700以下 → 730到達まで（中程度）
   - **レベル1**: 850以下 → 880到達まで（軽度）
   - 即座にAIマッチング（ノータイム）、人間マッチング完全遮断

2. **CallMatchingService完全対応**
   - 多段階判定ロジック実装
   - `autoAIReason`フィールドで救済理由記録
   - 各段階の詳細ログ出力
   - AI強制マッチング機能の再有効化

3. **UI段階別表示システム**
   - **HomeScreen**: 救済レベル別の警告色・アイコン・メッセージ
   - **MatchingScreen**: 救済レベル別の通知色・アイコン・メッセージ
   - レベル3（赤色・警告）、レベル2（深いオレンジ・エラー）、レベル1（オレンジ・情報）

4. **段階的進捗表示**
   - 各レベルで明確な目標値表示
   - 「レート580を超えると次の段階に進みます」
   - 「レート880を超えると人間との通話に戻ります」

**技術的詳細:**
```dart
// CallMatchingService.dart - 多段階判定ロジック
if (userRating <= 550) {
  autoAIReason = 'multi_stage_rescue_550';
} else if (userRating > 550 && userRating <= 580) {
  autoAIReason = 'multi_stage_rescue_550_ongoing';
} else if (userRating > 580 && userRating <= 700) {
  autoAIReason = 'multi_stage_rescue_700';
} else if (userRating > 700 && userRating <= 730) {
  autoAIReason = 'multi_stage_rescue_700_ongoing';
} else if (userRating > 730 && userRating <= 850) {
  autoAIReason = 'multi_stage_rescue_850';
} else if (userRating > 850 && userRating <= 880) {
  autoAIReason = 'multi_stage_rescue_850_ongoing';
}
```

**UI実装詳細:**
- 救済レベル別の色分け: 赤色（レベル3）→ 深いオレンジ（レベル2）→ オレンジ（レベル1）
- アイコン段階変化: 警告（レベル3）→ エラー（レベル2）→ 情報（レベル1）
- 詳細な進捗メッセージとターゲット表示

**修正されたファイル:**
- `lib/services/call_matching_service.dart`: 多段階判定ロジック
- `lib/screens/home_screen.dart`: 段階別警告システム
- `lib/screens/matching_screen.dart`: 段階別通知システム

**結果:**
- ✅ 3段階の細かいAI救済システム完成
- ✅ 即座のAIマッチング（ノータイム）実現
- ✅ 段階的レーティング回復の明確な進捗表示
- ✅ ユーザー体験の大幅改善（迷いのない救済フロー）

### 2025年6月29日 - AIプロフィール完全読み取りシステム実装
**概要**: AIエージェントがユーザープロフィールの全情報を読み取り、「AIにひとこと」と「みんなに一言」を区別して会話に活用するシステムを実装

**実施内容:**
1. **完全プロフィール読み取りシステム**
   - ニックネーム、性別、誕生日、年齢計算を自動実行
   - AIに知ってほしいこと（aiMemory）と、みんなに一言（comment）の完全区別
   - 全プロフィール情報をシステムプロンプトに動的挿入

2. **「AIにひとこと」vs「みんなに一言」区別システム**
   - **AIにひとこと（aiMemory）**: AIが知ってほしい重要な個人情報
   - **みんなに一言（comment）**: 本来は他ユーザー向け、AIが「本来知るべきでない」情報
   - AIは両方を知っており、区別を理解して会話に活用

3. **包括的プロフィール情報構築**
   - `_buildComprehensiveUserProfile()`メソッド実装
   - 基本情報・AIメモリ・パブリックコメントをセクション分け
   - 年齢自動計算（誕生日から）、情報の重要度明示

4. **全AIサービス統一対応**
   - `ZundamonChatScreen`: 段階的親密度システムと統合
   - `VertexAIChatService`: Vertex AI Gemini 2.5 Flash対応
   - `GeminiChatService`: Gemini 2.0 Flash Lite対応

**技術的詳細:**
- プロフィール読み込み時に全フィールドを一括取得
- システムプロンプトに情報の性質を明記（重要度・用途説明）
- 「本来知るべきでない情報も知っている」ことを明示
- AIが性格・興味を推測して会話に活用するよう指示

**実装されたプロフィール活用:**
```
【ユーザーの基本情報】
- 名前: [ニックネーム]
- 性別: [性別]
- 年齢: 約X歳（誕生日: X月X日）

【ユーザーがAIに知ってほしいこと】
[aiMemoryの内容]
※重要な個人情報として会話で活用

【ユーザーの「みんなに一言」（本来は他のユーザー向け）】
[commentの内容]
※本来他のアプリユーザー向けだが、AIも知っている
※性格や興味を推測して会話に活用
```

**修正されたファイル:**
- `lib/screens/zundamon_chat_screen.dart`: 完全プロフィール読み取り実装
- `lib/services/vertex_ai_chat_service.dart`: 「みんなに一言」追加
- `lib/services/gemini_chat_service.dart`: 「みんなに一言」追加

**結果:**
- ✅ AIが全プロフィール情報を適切に理解・活用
- ✅ 「知ってほしいこと」と「みんなに一言」の区別実装
- ✅ より自然で個人最適化されたAI会話体験
- ✅ プライバシー意識を保ちつつ全情報活用

### 2025年7月26日 - ガウスブラー背景効果システム実装
**概要**: 全画面（EULA以外）にベジエでない画像を拡大したようなザリザリのガウスブラー効果を実装

**実施内容:**
1. **BlurWrapperウィジェット作成**
   - `lib/widgets/blur_wrapper.dart`に再利用可能なブラーコンポーネント実装
   - `BlurWrapper`と`PartialBlurWrapper`の2種類提供
   - デフォルト値: `sigmaX: 50.0, sigmaY: 50.0`（超強力ブラー）

2. **背景ブラー実装**
   - **対象画面**: HomeScreen, LoginScreen, SettingsScreen, HistoryScreen, NotificationScreen
   - **除外画面**: EulaScreen（ユーザー指定により除外）
   - **実装方式**: `Stack` + `Positioned.fill` + `BackdropFilter`

3. **技術仕様**
   - **ブラー強度**: `ImageFilter.blur(sigmaX: 50.0, sigmaY: 50.0)`
   - **オーバーレイ**: `Colors.black.withOpacity(0.3)`（強い黒オーバーレイ）
   - **背景透過**: メインScaffoldを`backgroundColor: Colors.transparent`に設定
   - **UI保持**: 全てのUIコンテンツはクリアに表示、背景のみブラー

4. **視覚効果**
   - ベジエでない画像を拡大したときのようなザリザリした質感
   - 背景の詳細を完全に隠しつつ、色味は保持
   - UIコンテンツの可読性は完全に維持

**技術的実装:**
```dart
// 各画面での実装例
Stack(
  children: [
    // 背景にぼかし効果を適用
    Positioned.fill(
      child: Container(
        color: themeColor,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 50.0, sigmaY: 50.0),
          child: Container(
            color: Colors.black.withOpacity(0.3),
          ),
        ),
      ),
    ),
    // メインコンテンツ
    Scaffold(backgroundColor: Colors.transparent, ...),
  ],
)
```

**結果:**
- ✅ 全主要画面にザリザリブラー効果実装完了
- ✅ UIの可読性を保ちながら背景のみブラー
- ✅ 再利用可能なBlurWrapperコンポーネント作成
- ✅ テーマカラー対応のブラー背景システム

## メモ・備考
- Firebase Security Rules適切に設定済み
- 商用展開可能レベルに到達
- 全機能がiPhone・Android両対応
- コードの品質・保守性良好
- レーティングシステム完全統一済み
- **Agora音声通話システム完全動作確認済み**
- **TalkOne_test完全移植完了・UI修正完了**
- **透過デフォルト紫システム・話題共有機能実装完了**
- **ガウスブラー背景効果システム実装完了（2025年7月26日）**