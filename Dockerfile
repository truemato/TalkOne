# マルチステージビルド：本番環境用
FROM cirrusci/flutter:stable AS build

# 作業ディレクトリを設定
WORKDIR /app

# Flutter設定
RUN flutter config --enable-web

# 依存関係ファイルをコピーしてインストール
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

# ソースコードをコピー
COPY . .

# Web用にビルド
RUN flutter build web --release

# 本番環境用の軽量なNginxイメージ
FROM nginx:alpine

# Nginxの設定ファイルをコピー
COPY docker/nginx.conf /etc/nginx/nginx.conf

# ビルド済みのFlutter Webファイルをコピー
COPY --from=build /app/build/web /usr/share/nginx/html

# ポート80を公開
EXPOSE 80

# Nginxを起動
CMD ["nginx", "-g", "daemon off;"]