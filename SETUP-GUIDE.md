# Pydio Cells セットアップガイド

## 🎯 初期セットアップ手順

デプロイが完了したら、以下の手順でPydio Cellsの初期設定を行います。

### 1. Pydio Cellsにアクセス

ブラウザで以下のURLを開きます：
```
http://192.168.1.241:30808
```

### 2. インストールウィザード

#### ステップ1: インストールモードの選択
- **Browser Install**を選択

#### ステップ2: データベース設定

以下の情報を入力します：

```
データベースタイプ: MySQL

Database Connection:
  - ホスト: mysql.cells.svc.cluster.local
  - ポート: 3306
  - データベース名: cells
  - ユーザー名: cells
  - パスワード: cells-db-password-change-me
```

**重要**: 内部DNS名 `mysql.cells.svc.cluster.local` を使用することで、IPアドレスを直接指定せずに通信できます。

#### ステップ3: 管理者アカウント作成

お好みのユーザー名とパスワードを設定します：
```
ログインID: admin（または任意）
パスワード: （強力なパスワードを設定）
確認用パスワード: （再入力）
```

#### ステップ4: アプリケーション設定

```
Application Title: Pydio Cells（または任意の名前）
Default Language: 日本語 or English
```

#### ステップ5: ストレージ設定（重要！）

MinIOをストレージバックエンドとして設定します：

```
Storage Type: S3 API Compatible Storage

S3 Configuration:
  - Endpoint: http://minio.cells.svc.cluster.local:9000
  - API Key (Access Key): pydio-access-key
  - API Secret (Secret Key): pydio-secret-key-change-me-in-production
  - Bucket Name: pydio-data
  - Region: us-east-1
  - Path Style: Enable (チェックを入れる)
  - Use HTTPS: Disable（内部通信のため）
```

**重要ポイント**:
- エンドポイントは内部DNS名を使用
- `pydio-data` バケットは既に作成済み
- Path Styleを有効にする必要があります

#### ステップ6: 高度な設定（オプション）

```
External URL: http://192.168.1.241:30808
（Cloudflare Tunnels使用時は後で変更）

Services Discovery:
  - Auto-discovery: Enable
```

#### ステップ7: インストール実行

「Install Now」または「インストール開始」をクリック

### 3. インストール完了後

- 設定した管理者アカウントでログイン
- ダッシュボードが表示されればセットアップ完了！

## 🧪 動作確認

### ファイルアップロードテスト

1. ログイン後、「My Files」または「マイファイル」をクリック
2. 「Upload」ボタンからファイルをアップロード
3. 大容量ファイル（数GB）でもアップロード可能なことを確認

### MinIO連携確認

MinIO Consoleで `pydio-data` バケットを確認：
```
http://192.168.1.241:30901
```

アップロードしたファイルが `pydio-data` バケット内に保存されていることを確認できます。

## 🔧 トラブルシューティング

### データベース接続エラー

```bash
# MySQL接続テスト
kubectl exec -it -n cells statefulset/mysql -- mysql -u cells -p'cells-db-password-change-me' cells

# 接続できればOK
# できない場合はMySQLのログ確認
kubectl logs -n cells statefulset/mysql
```

### MinIO接続エラー

```bash
# MinIO接続テスト
kubectl exec -it -n cells deployment/pydio-cells -- nc -zv minio.cells.svc.cluster.local 9000

# MinIOのログ確認
kubectl logs -n cells deployment/minio
```

### Pydio Cellsが起動しない

```bash
# Pydio Cellsのログ確認
kubectl logs -n cells deployment/pydio-cells -f

# 依存サービスの確認
kubectl get pods -n cells
```

### ファイルアップロードエラー

1. **MinIOの接続設定を確認**
   - 管理画面 → Settings → Storage
   - エンドポイントが `http://minio.cells.svc.cluster.local:9000` であることを確認

2. **バケットの権限確認**
   ```bash
   # MinIO Consoleでバケットの権限を確認
   # http://192.168.1.241:30901
   ```

3. **Pydio Cellsのログ確認**
   ```bash
   kubectl logs -n cells deployment/pydio-cells | grep -i error
   ```

## 🚀 次のステップ

### ユーザー管理

1. 管理画面 → People → Users
2. 新しいユーザーを追加
3. グループとロールの設定

### ワークスペース作成

1. Cells → Create New Cell
2. フォルダー構造の設定
3. アクセス権限の設定

### 外部公開の準備

Cloudflare Tunnelsでの外部公開を計画している場合：
1. `cloudflare-tunnel-config.yaml` を確認
2. Cloudflare Tunnelの作成
3. 設定ファイルの編集とデプロイ

詳細は `cloudflare-tunnel-config.yaml` と `README.md` を参照してください。

## 📊 パフォーマンス最適化

### リソース調整

大量のファイルを扱う場合、リソース制限を調整：

```bash
# cells-complete.yamlを編集
vi cells-complete.yaml

# Pydio Cellsのresources:
resources:
  requests:
    memory: 2Gi
    cpu: 1000m
  limits:
    memory: 8Gi
    cpu: 4000m

# 再デプロイ
kubectl apply -f cells-complete.yaml
kubectl rollout restart deployment/pydio-cells -n cells
```

### MinIOのチューニング

大容量ファイル用にMinIOを最適化：

```bash
# MinIOのメモリ制限を増やす
# cells-complete.yaml内のMinIO resourcesを編集
```

## 📝 セキュリティチェックリスト

- [ ] 全てのデフォルトパスワードを変更
- [ ] 管理者アカウントに強力なパスワードを設定
- [ ] MinIOのアクセスキー・シークレットキーを変更
- [ ] MySQLのパスワードを変更
- [ ] 定期的なバックアップ設定
- [ ] ログの定期確認
- [ ] ファイアウォール設定（本番環境）
- [ ] SSL/TLS設定（Cloudflare Tunnels使用時）

## 🎉 完了！

セットアップが完了したら、快適なファイル共有環境をお楽しみください！

---

**サポート情報**:
- Pydio公式ドキュメント: https://pydio.com/en/docs/cells/v4
- MinIO公式ドキュメント: https://min.io/docs/
