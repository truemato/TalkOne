#!/bin/bash

# Firestore インデックス作成スクリプト

echo "Firestore インデックスを作成します..."

# 1. エラーメッセージに表示されたインデックスを直接作成
echo "1. evaluations コレクションのインデックスを作成中..."
echo "以下のURLをブラウザで開いてインデックスを作成してください："
echo "https://console.firebase.google.com/v1/r/project/myproject-c8034/firestore/indexes?create_composite=ClNwcm9qZWN0cy9teXByb2plY3QtYzgwMzQvZGF0YWJhc2VzLyhkZWZhdWx0KS9jb2xsZWN0aW9uR3JvdXBzL2V2YWx1YXRpb25zL2luZGV4ZXMvXxABGhMKD2V2YWx1YXRlZFVzZXJJZBABGg0KCWNyZWF0ZWRBdBACGgwKCF9fbmFtZV9fEAI"

echo ""
echo "2. または、firebase deploy コマンドを使用："
echo "firebase deploy --only firestore:indexes"

echo ""
echo "3. 手動でFirebaseコンソールから作成する場合："
echo "- https://console.firebase.google.com/project/myproject-c8034/firestore/indexes"
echo "- 「インデックスを作成」をクリック"
echo "- 以下のインデックスを追加："
echo ""
echo "evaluations コレクション:"
echo "  - evaluatedUserId (昇順)"
echo "  - createdAt (降順)"
echo ""
echo "callRequests コレクション:"
echo "  - status (昇順)"
echo "  - userRating (昇順)"
echo ""
echo "callRequests コレクション:"
echo "  - status (昇順)"
echo "  - userRating (降順)"