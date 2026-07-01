# nginx-alb-gateway-demo

NGINX + Docker Compose で、ALB / API Gateway っぽい **入口処理**（パスルーティング、共通ヘッダ付与、レート制限、upstream 停止時の fallback）を小さく再現するデモです。

- GitHub: https://github.com/masanori0209/nginx-alb-gateway-demo
- 解説記事（Zenn）: 公開後に URL を追記

:::message
このリポジトリは、AWS ALB / API Gateway / Cloud Load Balancing の **完全な置き換え** ではありません。マネージドサービスで何を買っているのかを手触りで理解するための、ローカル実験用です。
:::

## できること

| 機能 | NGINX 設定 | クラウドで近いもの |
|---|---|---|
| `/api/a` → `api-a` | `location` + `proxy_pass` | ALB / API Gateway の path routing |
| `/api/b` → `api-b` | 同上 | 同上 |
| 共通レスポンスヘッダ | `add_header` | API Gateway の response mapping など |
| レート制限 | `limit_req` | API Gateway throttling / Cloud Armor rate limiting |
| upstream 停止時 | `error_page` + `@fallback` | 簡易なエラー応答（本番の graceful degradation とは別物） |

## 前提

- Docker / Docker Compose が使えること
- ポート `8080` が空いていること（別ポートを使う場合は `DEMO_PORT` を指定）

## 起動

```bash
git clone https://github.com/masanori0209/nginx-alb-gateway-demo.git
cd nginx-alb-gateway-demo

docker compose up -d
```

ポートを変える例:

```bash
DEMO_PORT=19080 docker compose up -d
```

## 動作確認

```bash
curl -i http://localhost:8080/api/a/
curl -i http://localhost:8080/api/b/
```

レート制限の確認（連続リクエスト）:

```bash
for i in $(seq 1 8); do
  echo -n "req $i: "
  curl -s -o /dev/null -w "%{http_code}\n" http://localhost:8080/api/a/
done
```

upstream 停止時の fallback:

```bash
docker compose stop api-a
curl -i --max-time 5 http://localhost:8080/api/a/
docker compose start api-a
```

一括検証:

```bash
chmod +x scripts/verify.sh
./scripts/verify.sh
```

記事用のターミナル PNG / GIF を再生成する場合:

```bash
chmod +x scripts/capture-media.sh
./scripts/capture-media.sh
```

## 構成

```text
nginx-alb-gateway-demo/
├── docker-compose.yml
├── nginx/
│   └── nginx.conf
├── scripts/
│   └── verify.sh
└── README.md
```

## 停止

```bash
docker compose down
```

## GitHub へ公開する場合（メモ）

ローカルで初回 push する例:

```bash
cd nginx-alb-gateway-demo
git init
git add .
git commit -m "Initial commit: NGINX gateway routing demo"
gh repo create masanori0209/nginx-alb-gateway-demo --public --source=. --remote=origin --push
```

`gh` がない場合は GitHub 上で空リポジトリを作り、`git remote add origin git@github.com:masanori0209/nginx-alb-gateway-demo.git` から push してください。

## ライセンス

MIT
