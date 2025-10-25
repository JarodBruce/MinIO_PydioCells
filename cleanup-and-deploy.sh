#!/bin/bash

echo "=== Cleaning up existing deployments ==="

# 既存のリソースを削除
helm uninstall minio -n minio 2>/dev/null || true
kubectl delete namespace minio --force --grace-period=0 2>/dev/null || true
kubectl delete namespace pydio-system --force --grace-period=0 2>/dev/null || true

# 残っているPVCとPVを削除
kubectl delete pvc --all -n minio 2>/dev/null || true
kubectl delete pvc --all -n pydio-system 2>/dev/null || true

echo "Waiting for cleanup..."
sleep 10

echo "=== Starting fresh deployment ==="

# MinIOのデプロイ（スタンドアロン版）
echo "Deploying MinIO..."
kubectl apply -f minio-standalone.yaml

# Pydio Cellsのデプロイ
echo "Deploying Pydio Cells..."
kubectl apply -f pydio-fixed.yaml

# デプロイメント待機
echo "Waiting for MinIO..."
kubectl wait --for=condition=available --timeout=300s \
  deployment/minio -n minio || true

echo "Waiting for MySQL..."
kubectl wait --for=condition=ready --timeout=300s \
  pod -l app=mysql -n pydio-system || true

echo "Waiting for Pydio Cells..."
kubectl wait --for=condition=available --timeout=300s \
  deployment/pydio-cells -n pydio-system || true

echo "=== Deployment Status ==="
kubectl get pods -n minio
kubectl get pods -n pydio-system

echo "=== Service Endpoints ==="
NODE_IP=$(kubectl get nodes -o wide | awk 'NR==2 {print $6}')
echo "MinIO Console: http://${NODE_IP}:30901"
echo "MinIO API: http://${NODE_IP}:30900"
echo "Pydio Cells: http://${NODE_IP}:30808"

echo ""
echo "MinIO Credentials:"
echo "  Username: minioadmin"
echo "  Password: minioadmin123"
