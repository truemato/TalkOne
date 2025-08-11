# TalkOne 通報通知システム - デプロイガイド

## 概要
このCloud Functionは、TalkOneアプリで通報が行われた際に、管理者に自動でメール通知を送信するシステムです。

## 前提条件
1. Firebase プロジェクトの作成
2. Firebase CLI のインストール
3. Gmail アカウント（通知送信用）
4. 管理者メールアドレス

## セットアップ手順

### 1. Firebase CLI のインストール
```bash
npm install -g firebase-tools
```

### 2. Firebase にログイン
```bash
firebase login
```

### 3. プロジェクトの初期化
```bash
# プロジェクトディレクトリに移動
cd /path/to/TalkOne-Project/cloud_functions

# Firebase プロジェクトを設定
firebase use --add
# プロジェクトIDを選択
```

### 4. 環境変数の設定
```bash
# Gmail 設定（通知送信用）
firebase functions:config:set gmail.email="your-notification-gmail@gmail.com"
firebase functions:config:set gmail.password="your-app-password"

# 管理者メール設定
firebase functions:config:set admin.email="your-admin-email@example.com"
```

**重要**: Gmail のパスワードは「アプリパスワード」を使用してください。
1. Googleアカウント設定 → セキュリティ
2. 2段階認証を有効化
3. アプリパスワードを生成して使用

### 5. 依存関係のインストール
```bash
cd report-notification
npm install
```

### 6. Cloud Functions のデプロイ
```bash
# 全体をデプロイ
firebase deploy --only functions

# 特定の関数のみデプロイ
firebase deploy --only functions:sendReportNotification
```

### 7. デプロイ確認
```bash
# ログを確認
firebase functions:log

# 関数一覧を確認
firebase functions:list
```

## 設定項目

### Gmail設定
- `gmail.email`: 通知送信用のGmailアドレス
- `gmail.password`: Gmailのアプリパスワード

### 管理者設定  
- `admin.email`: 通報通知を受信する管理者メールアドレス

### Firebase Console での確認
1. [Firebase Console](https://console.firebase.google.com/) にアクセス
2. プロジェクトを選択
3. Functions セクションで関数の状態を確認
4. Firestore で `reports` コレクションを確認

## 通知の仕組み

### 通常の通報通知
- Firestore の `reports` コレクションに新しいドキュメントが作成されると自動実行
- 通報者・被通報者の情報を取得
- 詳細な通報内容をHTMLメールで送信

### 緊急通報通知
- 暴力、ハラスメント、ヘイトスピーチなどの緊急性の高い通報を検出
- 通常の通知とは別に、緊急アラートメールを送信
- 件名に「🚨【緊急】」を付けて優先度を明示

## メール内容
- 通報ID、時刻、理由
- 通報者・被通報者の情報（匿名化済み）
- 通話時間やその他の詳細情報
- Firebase Console へのリンク

## トラブルシューティング

### 1. メールが送信されない
```bash
# 設定確認
firebase functions:config:get

# ログ確認  
firebase functions:log --only sendReportNotification
```

### 2. 関数がトリガーされない
- Firestore Rules を確認
- `reports` コレクションへの書き込み権限をチェック

### 3. Gmail認証エラー
- アプリパスワードを再生成
- 2段階認証が有効になっているか確認

## セキュリティ注意事項
1. 環境変数には機密情報を保存しない
2. Gmail のアプリパスワードを適切に管理
3. Firebase Console のアクセス権限を制限
4. ログに個人情報が出力されないよう注意

## 料金について
- Cloud Functions: 実行回数に応じた従量課金
- Firestore: 読み取り・書き込み回数に応じた課金
- Gmail: 無料（送信制限あり）

月間数千件の通報であれば、ほぼ無料枠内で運用可能です。