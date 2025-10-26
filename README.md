# Pydio Cells + MinIO on K3s

完全な統合デプロイメント構成（単一namespace、内部DNS通信、Cloudflare Tunnels対応）

## 📋 概要

このプロジェクトは、K3s上でPydio CellsとMinIOを統合して動作させる完全なデプロイメント構成です。

### 主な特徴

- ✅ **単一namespace構成**: 全てのコンポーネントが`cells` namespace内で動作
- ✅ **内部DNS通信**: IPアドレス直接指定なし、全てKubernetes DNS名を使用
- ✅ **Cloudflare Tunnels対応**: 将来の外部公開に備えた設計
- ✅ **ファイルアップロード最適化**: MinIOとの完全な統合で大容量ファイル対応
- ✅ **本番環境対応**: リソース制限、ヘルスチェック、永続化ストレージ完備

## 🏗️ アーキテクチャ

```
┌─────────────────────────────────────────────────┐
│           cells namespace                        │
│                                                  │
│  ┌──────────────┐      ┌──────────────┐        │
│  │ Pydio Cells  │─────>│    MySQL     │        │
│  │  (Web UI)    │      │  (Database)  │        │
│  └──────┬───────┘      └──────────────┘        │
│         │                                        │
│         v                                        │
│  ┌──────────────┐                               │
│  │    MinIO     │                               │
│  │  (Storage)   │                               │
│  └──────────────┘                               │
│                                                  │
│  内部通信: *.cells.svc.cluster.local            │
└─────────────────────────────────────────────────┘
          │
          v
    ┌─────────────┐
    │ Cloudflare  │ (将来の外部公開用)
    │   Tunnel    │
    └─────────────┘
```

## 🚀 クイックスタート

### 前提条件

- K3s クラスター（動作確認済み）
- kubectl コマンド
- 利用可能なストレージクラス: `local-path`

### デプロイ手順

```bash
# 1. リポジトリのクローン（既にある場合はスキップ）
cd ~/MinIO_PydioCells

# 2. デプロイスクリプトに実行権限を付与
chmod +x deploy-cells.sh

# 3. デプロイ実行
./deploy-cells.sh
```

デプロイ完了まで約3-5分かかります。

## 📦 デプロイされるコンポーネント

### 1. MinIO (オブジェクトストレージ)
- **用途**: ファイルストレージバックエンド
- **ストレージ**: 20Gi PVC
- **内部アクセス**: `http://minio.cells.svc.cluster.local:9000`
- **Console**: NodePort 30901

### 2. MySQL (データベース)
- **用途**: Pydio Cellsのメタデータ保存
- **ストレージ**: 10Gi PVC
- **内部アクセス**: `mysql.cells.svc.cluster.local:3306`
- **バージョン**: MySQL 8.0

### 3. Pydio Cells (アプリケーション)
- **用途**: ファイル共有・コラボレーション
- **ストレージ**: 10Gi PVC
- **内部アクセス**: `http://pydio-cells.cells.svc.cluster.local:8080`
- **外部アクセス**: NodePort 30808

## 🔧 初期セットアップ

### 1. Pydio Cellsへアクセス

```bash
# ノードIPの取得
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')

# ブラウザで開く
echo "http://${NODE_IP}:30808"
```

### 2. インストールウィザード

1. **データベース設定**
   - データベースタイプ: MySQL
   - ホスト: `mysql.cells.svc.cluster.local`
   - ポート: `3306`
   - データベース名: `cells`
   - ユーザー名: `cells`
   - パスワード: `cells-db-password-change-me`

2. **MinIOストレージ設定**
   - ストレージタイプ: S3 Compatible
   - エンドポイント: `http://minio.cells.svc.cluster.local:9000`
   - Access Key: `pydio-access-key`
   - Secret Key: `pydio-secret-key-change-me-in-production`
   - バケット名: `pydio-data`
   - リージョン: `us-east-1` (デフォルト)

3. **管理者アカウント作成**
   - お好みのユーザー名とパスワードを設定

## 🌐 Cloudflare Tunnels での外部公開

将来的にインターネットに公開する場合:

### セットアップ手順

1. **Cloudflare Tunnelの作成**
   ```bash
   cloudflared tunnel create pydio-cells
   ```

2. **設定ファイルの編集**
   ```bash
   vi cloudflare-tunnel-config.yaml
   # 実際のTunnel ID、credentials、ドメイン名を設定
   ```

3. **DNS設定**
   Cloudflareダッシュボードで以下のCNAMEレコードを追加:
   - `cells.yourdomain.com` → `<tunnel-id>.cfargotunnel.com`
   - `minio.yourdomain.com` → `<tunnel-id>.cfargotunnel.com`

4. **デプロイ**
   ```bash
   kubectl apply -f cloudflare-tunnel-config.yaml
   ```

詳細は `cloudflare-tunnel-config.yaml` を参照してください。

## 🔍 トラブルシューティング

### Podの状態確認

```bash
kubectl get pods -n cells
```

### ログ確認

```bash
# Pydio Cellsのログ
kubectl logs -n cells deployment/pydio-cells -f

# MinIOのログ
kubectl logs -n cells deployment/minio -f

# MySQLのログ
kubectl logs -n cells statefulset/mysql -f
```

### よくある問題

#### 1. Pydio Cellsが起動しない

```bash
# 依存サービスの確認
kubectl get pods -n cells

# MySQLとMinIOが先に起動している必要があります
```

#### 2. ファイルアップロードが失敗する

```bash
# MinIOの接続確認
kubectl exec -it -n cells deployment/pydio-cells -- nc -zv minio.cells.svc.cluster.local 9000

# MinIOのログ確認
kubectl logs -n cells deployment/minio -f
```

#### 3. データベース接続エラー

```bash
# MySQL接続テスト
kubectl exec -it -n cells statefulset/mysql -- mysql -u cells -p'cells-db-password-change-me' cells

# 接続できればOK
```

## 📊 リソース要件

### 最小構成
- CPU: 2 cores
- メモリ: 4GB
- ストレージ: 40GB

### 推奨構成
- CPU: 4 cores
- メモリ: 8GB
- ストレージ: 100GB+

## 🔐 セキュリティ

### 本番環境で必須の設定変更

1. **全てのパスワードを変更**
   ```bash
   # cells-complete.yaml内の以下を変更:
   # - minio-credentials
   # - mysql-credentials
   ```

2. **TLSの有効化**
   - 本番環境ではHTTPSを使用
   - Cloudflare Tunnelを使用する場合は自動的にHTTPS化

3. **ネットワークポリシーの設定**
   ```bash
   # 必要な通信のみ許可
   kubectl apply -f network-policies.yaml
   ```

## 🗑️ アンインストール

```bash
# 全てのリソースを削除
kubectl delete namespace cells

# PVCも削除される場合、データは完全に消去されます
```

## 📚 参考リンク

- [Pydio Cells公式ドキュメント](https://pydio.com/en/docs/cells/v4)
- [MinIO公式ドキュメント](https://min.io/docs/minio/kubernetes/upstream/)
- [Cloudflare Tunnel ドキュメント](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/)
- [K3s公式サイト](https://k3s.io/)

## 📝 ライセンス

このデプロイメント構成はMITライセンスです。
各コンポーネントのライセンスは個別に確認してください。

## 🤝 貢献

Issue、Pull Requestを歓迎します！

---

**作成日**: 2025-10-26  
**作成者**: Pydio Cells K3s デプロイメントプロジェクト
