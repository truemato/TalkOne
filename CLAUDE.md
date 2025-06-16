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

### AI Bot救済機能（懲罰部屋システム）
- **対象者**: 評価が急激に下がった人、レート偏差値が著しく低い人
- **AI相手**: 最新のAI（Gemini 2.5 Pro）との3分間音声会話
- **音声合成**: VOICEVOX四国めたん専用（speaker_uuid: 7ffcb7ce-00ec-4bdc-82cd-45a8889e43ff）
- **音声認識**: STT (speech_to_text) でユーザー音声をリアルタイム認識
- **会話ログ**: 全ての会話内容（平文）をFirebase Firestoreに自動保存
- **学習機能**: AIがユーザーを記憶し、話題の幅が広がる

## 主要機能
1. **音声通話・ビデオ通話**: Agoraを使用したリアルタイム通信
2. **レーティングベースマッチング**: 評価による相手選択システム
3. **AI Bot マッチング**: 低評価ユーザー向け救済措置
4. **VOICEVOX統合**: 四国めたんによるリアルタイム音声AI会話（2025年6月実装完了）
5. **アメニティ機能**: レート上昇による追加機能解放
6. **ユーザーページ**: プロフィール・通報機能

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
- `lib/screens/voice_call_screen.dart` - 音声通話画面
- `lib/screens/video_call_screen.dart` - ビデオ通話画面
- `lib/screens/evaluation_screen.dart` - 評価画面
- `lib/screens/voicevox_test_screen.dart` - VOICEVOX機能テスト画面

### サービス（Services）
- `lib/services/call_matching_service.dart` - マッチングロジック
- `lib/services/agora_call_service.dart` - Agora通話制御
- `lib/services/evaluation_service.dart` - 評価システム
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

## 実装状況・完成度

### ✅ 完全実装済み
- **レーティングベースマッチング**: 段階的範囲拡大システム
- **音声・ビデオ通話**: Agora RTC Engine完全統合
- **評価システム**: 5段階評価、レート計算ロジック
- **AI Bot機能**: Gemini 2.5 Pro + 人格システム
- **VOICEVOX統合**: 高品質音声合成（2025年6月実装）
- **Firebase統合**: 認証、データベース、AI機能

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
- **ユーザーの会話はすべて文字に**: STT機能により、ユーザー音声とAI応答の全文がFirebaseに保存され、AIとの会話において品質向上を行う
- **3分間制限**: 集中した質の高い会話を促進
- **評価の強制**: 必ず相手を評価する仕組み
- **通報機能**: 相手が誹謗中傷を行った場合はユーザーページから通報が可能
- **AI救済システム**: 低評価ユーザーへの配慮
- **段階的機能解放**: レーティング向上によるインセンティブ

## 特殊な実装ポイント
- **カメラ権限**: `UICameraControlIntents` - StealthCameraCaptureIntent設定
- **レート計算**: 星1-5で-2〜+3ポイント変動
- **AI人格**: 5種類の人格とVOICEVOX話者のマッピング
- **四国めたん専用設定**: speaker_id=2 (ノーマル), UUID=7ffcb7ce-00ec-4bdc-82cd-45a8889e43ff
- **リアルタイム音声処理**: STT → Gemini → VOICEVOX → 音声再生の低遅延パイプライン
- **会話ログ構造**: { timestamp, user_text, ai_response, session_id, user_id }
- **マッチング拡大**: 10秒後±100ポイント、20秒後AI提案
- **Agora設定**: 本番・テストモード切り替え対応

## メモ・備考
- 商用レベルの完成度（約85%）
- 核心機能は完全実装済み
- UI/UXは高品質、Material Design準拠
- Firebase Security Rules適切に設定済み