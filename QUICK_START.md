# TalkOne クイックスタートガイド

## 🚀 最速でビルドする（10分でできる！）

### 1️⃣ プロジェクト準備（2分）
```bash
# クローン
git clone https://github.com/truemato/TalkOne-Project.git
cd TalkOne-Project

# 環境変数準備
cp .env.template .env
```

### 2️⃣ Firebase 設定（5分）

#### Firebase プロジェクト作成
1. https://console.firebase.google.com/ にアクセス
2. 「プロジェクトを作成」→ 名前入力 → 作成

#### FlutterFire CLI で自動設定
```bash
# CLI インストール（初回のみ）
dart pub global activate flutterfire_cli

# 自動設定（対話形式）
flutterfire configure
```
✅ これで Firebase 設定完了！

### 3️⃣ Agora 設定（2分）
1. https://console.agora.io/ でプロジェクト作成
2. App ID をコピー
3. `.env` ファイルに貼り付け：
```
AGORA_APP_ID=あなたのAppIDをここに
```

### 4️⃣ ビルド実行（1分）

#### iOS
```bash
cd ios && pod install && cd ..
flutter run -d ios
```

#### Android
```bash
flutter run -d android
```

## ✅ 完了！

これでアプリが起動します。「ゲストとして続ける」でログインできます。

## 🆘 エラーが出たら？

### Firebase エラー
→ `flutterfire configure` を再実行

### CocoaPods エラー
```bash
cd ios
pod deintegrate
pod install
```

### ビルドエラー
```bash
flutter clean
flutter pub get
```

詳細は [ZENN_BUILD_GUIDE.md](./ZENN_BUILD_GUIDE.md) を参照してください。