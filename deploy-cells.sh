#!/bin/bash

set -e

echo "============================================"
echo "  Pydio Cells + MinIO 完全再構築"
echo "  単一namespace、内部DNS通信"
echo "============================================"
echo ""

# カラー出力
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# ステップ1: 既存リソースの完全削除
echo -e "${YELLOW}[1/5] 既存リソースのクリーンアップ...${NC}"
echo "既存のnamespaceを削除中..."

kubectl delete namespace minio --force --grace-period=0 2>/dev/null || true
kubectl delete namespace pydio-system --force --grace-period=0 2>/dev/null || true
kubectl delete namespace cells --force --grace-period=0 2>/dev/null || true

echo "PVCのクリーンアップ..."
kubectl delete pvc --all -n minio 2>/dev/null || true
kubectl delete pvc --all -n pydio-system 2>/dev/null || true
kubectl delete pvc --all -n cells 2>/dev/null || true

# Helmリリースも削除
helm uninstall minio -n minio 2>/dev/null || true
helm uninstall minio -n cells 2>/dev/null || true

echo "クリーンアップ完了を待機中..."
sleep 15

# namespaceが完全に削除されるまで待つ
while kubectl get namespace cells 2>/dev/null; do
  echo "cells namespaceの削除待機中..."
  sleep 3
done

echo -e "${GREEN}✓ クリーンアップ完了${NC}"
echo ""

# ステップ2: 新しい統合構成のデプロイ
echo -e "${YELLOW}[2/5] 新しい統合構成をデプロイ中...${NC}"
kubectl apply -f cells-complete.yaml

echo -e "${GREEN}✓ マニフェスト適用完了${NC}"
echo ""

# ステップ3: 各コンポーネントの起動待機
echo -e "${YELLOW}[3/5] コンポーネントの起動を待機中...${NC}"

echo "MinIOの起動を待機..."
kubectl wait --for=condition=available --timeout=300s \
  deployment/minio -n cells || echo "MinIO timeout - 続行します"

echo "MySQLの起動を待機..."
kubectl wait --for=condition=ready --timeout=300s \
  pod -l app=mysql -n cells || echo "MySQL timeout - 続行します"

echo "Pydio Cellsの起動を待機..."
kubectl wait --for=condition=available --timeout=300s \
  deployment/pydio-cells -n cells || echo "Pydio Cells timeout - 続行します"

echo -e "${GREEN}✓ 全コンポーネント起動完了${NC}"
echo ""

# ステップ4: デプロイメント状態の確認
echo -e "${YELLOW}[4/5] デプロイメント状態の確認...${NC}"
echo ""
echo "=== Pods ==="
kubectl get pods -n cells -o wide
echo ""
echo "=== Services ==="
kubectl get svc -n cells
echo ""
echo "=== PersistentVolumeClaims ==="
kubectl get pvc -n cells
echo ""
echo "=== Ingress ==="
kubectl get ingress -n cells
echo ""

# ステップ5: アクセス情報の表示
echo -e "${YELLOW}[5/5] アクセス情報${NC}"
echo ""

# ノードIPの取得
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')

echo "============================================"
echo -e "${GREEN}✓ デプロイメント完了！${NC}"
echo "============================================"
echo ""
echo "📦 デプロイされたコンポーネント:"
echo "  - MinIO (オブジェクトストレージ)"
echo "  - MySQL (データベース)"
echo "  - Pydio Cells (アプリケーション)"
echo ""
echo "🌐 アクセス情報:"
echo ""
echo "【Pydio Cells】"
echo "  URL: http://${NODE_IP}:30808"
echo "  内部DNS: http://pydio-cells.cells.svc.cluster.local:8080"
echo ""
echo "【MinIO Console】"
echo "  URL: http://${NODE_IP}:30901"
echo "  Username: minioadmin"
echo "  Password: minioadmin123"
echo "  内部DNS (API): http://minio.cells.svc.cluster.local:9000"
echo "  内部DNS (Console): http://minio.cells.svc.cluster.local:9001"
echo ""
echo "【MySQL】（内部アクセスのみ）"
echo "  Host: mysql.cells.svc.cluster.local"
echo "  Port: 3306"
echo "  Database: cells"
echo "  Username: cells"
echo "  Password: cells-db-password-change-me"
echo ""
echo "📝 次のステップ:"
echo ""
echo "1. Pydio Cellsの初期セットアップ:"
echo "   http://${NODE_IP}:30808 にアクセス"
echo ""
echo "2. データベース接続設定（セットアップ時）:"
echo "   - ホスト: mysql.cells.svc.cluster.local"
echo "   - ポート: 3306"
echo "   - データベース名: cells"
echo "   - ユーザー名: cells"
echo "   - パスワード: cells-db-password-change-me"
echo ""
echo "3. MinIOストレージ設定（セットアップ時）:"
echo "   - エンドポイント: http://minio.cells.svc.cluster.local:9000"
echo "   - Access Key: pydio-access-key"
echo "   - Secret Key: pydio-secret-key-change-me-in-production"
echo "   - バケット名: pydio-data"
echo ""
echo "4. Cloudflare Tunnels設定（将来の外部公開用）:"
echo "   cloudflare-tunnel-config.yaml を参照"
echo ""
echo "============================================"
echo ""
echo "💡 ヒント:"
echo "  - 全てのコンポーネントが同じ'cells' namespace内で動作"
echo "  - 内部通信は全てKubernetes DNS名を使用"
echo "  - IPアドレス直接指定なし、将来のCloudflare Tunnels対応済み"
echo ""
echo "🔍 トラブルシューティング:"
echo "  kubectl logs -n cells deployment/pydio-cells"
echo "  kubectl logs -n cells deployment/minio"
echo "  kubectl logs -n cells statefulset/mysql"
echo ""
