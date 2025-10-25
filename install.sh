#!/bin/bash

echo "=== Starting Pydio Cells + MinIO Installation ==="

# 1. Helm repoの追加
echo "Adding MinIO Helm repository..."
helm repo add minio https://charts.min.io/ || true
helm repo update

# 2. MinIOのインストール
echo "Installing MinIO..."
helm upgrade --install minio minio/minio \
  --namespace minio \
  --create-namespace \
  --values minio-values.yaml \
  --wait \
  --timeout 5m

# 3. Pydio Cellsのデプロイ
echo "Deploying Pydio Cells..."
kubectl apply -f pydio-cells-deployment.yaml

# 4. デプロイメントの待機
echo "Waiting for deployments to be ready..."
kubectl wait --for=condition=available --timeout=300s \
  deployment/mysql -n pydio-system
kubectl wait --for=condition=available --timeout=300s \
  deployment/pydio-cells -n pydio-system

# 5. ステータス確認
echo "=== Deployment Status ==="
kubectl get pods -n minio
kubectl get pods -n pydio-system

# 6. サービス情報の表示
echo "=== Service Information ==="
kubectl get svc -n minio
kubectl get svc -n pydio-system
kubectl get ingress -n pydio-system

echo "=== Installation Complete ==="
echo "Add the following entries to your /etc/hosts file:"
echo "$(kubectl get node -o wide | awk 'NR>1 {print $6}') minio.local minio-console.local pydio.local"
