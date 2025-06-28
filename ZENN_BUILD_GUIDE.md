# TalkOne アプリケーションビルドガイド

## 📱 匿名音声通話アプリ「TalkOne」を自分の環境でビルドする

このガイドでは、GitHubからTalkOneのソースコードをクローンして、iPhone/Android両方でビルドする手順を説明します。

## 🚀 前提条件

### 必要な開発環境
- **Flutter SDK**: 3.4.0以上
- **Dart SDK**: 3.4.0以上
- **Xcode**: 14.0以上（iOS開発用）
- **Android Studio**: 最新版（Android開発用）
- **CocoaPods**: 1.12.0以上（iOS用）
- **Git**: 最新版

### 必要なアカウント
- **Firebase アカウント**（無料枠で可）
- **Agora アカウント**（無料枠で可）
- **Apple Developer アカウント**（iOSビルド用・有料）
- **Google Play Developer アカウント**（Android配布用・任意）

## 📥 ステップ1: プロジェクトのクローン

```bash
# リポジトリをクローン
git clone https://github.com/truemato/TalkOne-Project.git
cd TalkOne-Project

# 依存関係をインストール
flutter pub get
```

## 🔥 ステップ2: Firebase プロジェクトの設定

### 2.1 Firebase プロジェクト作成

1. [Firebase Console](https://console.firebase.google.com/)にアクセス
2. 「プロジェクトを作成」をクリック
3. プロジェクト名を入力（例：`talkone-your-name`）
4. Google Analytics は任意（推奨：有効）

### 2.2 必要なFirebaseサービスを有効化

Firebase コンソールで以下のサービスを有効化：

1. **Authentication**
   - 「始める」をクリック
   - 以下のプロバイダを有効化：
     - 匿名認証
     - Google認証
     - Apple認証（iOS用）

2. **Cloud Firestore**
   - 「データベースを作成」
   - 本番環境モードで開始
   - ロケーション：asia-northeast1（東京）推奨

3. **Firebase AI (Vertex AI)**
   - 「AI」セクションから「Get started」
   - Vertex AI を有効化

### 2.3 FlutterFire CLI で設定ファイル生成

```bash
# FlutterFire CLI をインストール
dart pub global activate flutterfire_cli

# Firebase設定を自動生成
flutterfire configure

# 以下のプラットフォームを選択：
# ✓ android
# ✓ ios
# ✓ macos
# ✓ web
```

これにより以下のファイルが自動生成されます：
- `lib/firebase_options.dart`
- `ios/Runner/GoogleService-Info.plist`
- `android/app/google-services.json`

## 🎙️ ステップ3: Agora設定

### 3.1 Agora アカウント作成

1. [Agora Console](https://console.agora.io/)にアクセス
2. 新規プロジェクトを作成
3. App ID を取得（トークン不要モードで開始）

### 3.2 環境変数の設定

```bash
# .env.template を .env にコピー
cp .env.template .env

# .env ファイルを編集
AGORA_APP_ID=your_agora_app_id_here
```

## 📱 ステップ4: iOS ビルド設定

### 4.1 CocoaPods インストール

```bash
cd ios
pod install
cd ..
```

### 4.2 Xcode での設定

1. `ios/Runner.xcworkspace` を Xcode で開く
2. **Runner** プロジェクトを選択
3. **Signing & Capabilities** タブで：
   - Team を選択（Apple Developer アカウント）
   - Bundle Identifier を変更（例：`com.yourname.talkone`）

### 4.3 Info.plist 権限設定確認

以下の権限が `ios/Runner/Info.plist` に含まれていることを確認：

```xml
<key>NSCameraUsageDescription</key>
<string>TalkOneでビデオ通話をするために、カメラへのアクセスが必要です。</string>
<key>NSMicrophoneUsageDescription</key>
<string>TalkOneで音声通話をするために、マイクへのアクセスが必要です。</string>
<key>NSSpeechRecognitionUsageDescription</key>
<string>TalkOneであなたの音声をテキストに変換するために、音声認識機能が使用されます。</string>
```

### 4.4 iOS ビルド実行

```bash
# デバッグビルド
flutter run -d ios

# リリースビルド
flutter build ios --release
```

## 🤖 ステップ5: Android ビルド設定

### 5.1 アプリケーションID変更

`android/app/build.gradle` を編集：

```gradle
defaultConfig {
    applicationId "com.yourname.talkone"  // 変更
    minSdkVersion 24
    targetSdkVersion 34
}
```

### 5.2 署名設定（リリースビルド用）

#### キーストア作成
```bash
keytool -genkey -v -keystore talkone-release-key.jks \
        -alias talkone -keyalg RSA -keysize 2048 -validity 10000
```

#### `android/key.properties` 作成
```properties
storePassword=your_store_password
keyPassword=your_key_password
keyAlias=talkone
storeFile=../talkone-release-key.jks
```

### 5.3 Android ビルド実行

```bash
# デバッグビルド
flutter run -d android

# リリースビルド（APK）
flutter build apk --release

# リリースビルド（App Bundle）
flutter build appbundle --release
```

## 🎨 ステップ6: オプション設定

### VoiceVox 音声合成（任意）

ローカルで VoiceVox を使用する場合：

```bash
# Docker で VoiceVox Engine を起動
docker run --rm -d --name voicevox-engine \
           -p 127.0.0.1:50021:50021 \
           voicevox/voicevox_engine:cpu-latest
```

### Google Sign-In 設定

1. Firebase Console → Authentication → Sign-in method → Google
2. 「ウェブ SDK 構成」から「ウェブ クライアント ID」をコピー
3. `ios/Runner/Info.plist` に追加：

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>YOUR_REVERSED_CLIENT_ID</string>
        </array>
    </dict>
</array>
```

## ⚠️ トラブルシューティング

### よくある問題と解決方法

#### 1. CocoaPods エラー（iOS）
```bash
cd ios
pod deintegrate
pod install
cd ..
flutter clean
flutter pub get
```

#### 2. Gradle エラー（Android）
```bash
cd android
./gradlew clean
cd ..
flutter clean
flutter pub get
```

#### 3. Firebase 初期化エラー
- `firebase_options.dart` が正しく生成されているか確認
- Bundle ID / Application ID が Firebase に登録されているか確認

#### 4. Agora 接続エラー
- App ID が正しく設定されているか確認
- ネットワーク接続を確認

## 📋 ビルド前チェックリスト

- [ ] Flutter SDK インストール済み
- [ ] Firebase プロジェクト作成済み
- [ ] `firebase_options.dart` 生成済み
- [ ] Agora App ID 取得・設定済み
- [ ] `.env` ファイル作成済み
- [ ] iOS: Bundle ID 設定済み
- [ ] iOS: 署名設定完了
- [ ] Android: Application ID 設定済み
- [ ] 依存関係インストール済み（`flutter pub get`）
- [ ] iOS: `pod install` 実行済み

## 🎉 ビルド成功後

おめでとうございます！TalkOne が正常にビルドできました。

### 動作確認
1. アプリを起動
2. 「ゲストとして続ける」でログイン
3. ホーム画面が表示されることを確認
4. マッチング機能をテスト（2台の端末が必要）

### カスタマイズ例
- アプリ名変更：`pubspec.yaml` の `name` フィールド
- アイコン変更：`assets/icon/app_icon.png` を置き換えて `flutter pub run flutter_launcher_icons`
- テーマカラー変更：`lib/utils/theme_utils.dart`

## 📚 参考リンク

- [Flutter 公式ドキュメント](https://flutter.dev/docs)
- [Firebase Flutter セットアップ](https://firebase.google.com/docs/flutter/setup)
- [Agora Flutter SDK](https://docs.agora.io/en/video-calling/get-started/get-started-sdk?platform=flutter)
- [TalkOne リポジトリ](https://github.com/truemato/TalkOne-Project)

## 💡 ヒント

- 開発中は Firebase エミュレータを使用すると便利
- Agora の無料枠は月10,000分まで利用可能
- iOS シミュレータではカメラ機能が制限される
- 実機テストを推奨（特に音声通話機能）

---

**注意**: このプロジェクトは教育目的で公開されています。商用利用の際は、適切なライセンスとセキュリティ対策を実施してください。