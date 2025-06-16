# VOICEVOX Engine for Railway
FROM voicevox/voicevox_engine:cpu-latest

# Railwayで動的ポートを使用
ENV PORT=50021
EXPOSE $PORT

# CORS設定を追加してWebアプリからのアクセスを許可
CMD python run.py --host 0.0.0.0 --port $PORT --allow_origin "*"