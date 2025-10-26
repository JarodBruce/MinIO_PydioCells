#!/bin/bash

# ============================================
# K3s IPv6デュアルスタック有効化スクリプト
# ============================================

set -e

echo "========================================"
echo "K3s IPv6デュアルスタック設定"
echo "========================================"
echo ""
echo "このスクリプトはK3sクラスタでIPv6を有効化します"
echo "注意: クラスタの再起動が必要です"
echo ""

# rootユーザー確認
if [ "$EUID" -ne 0 ]; then 
    echo "このスクリプトはroot権限で実行してください"
    exit 1
fi

# ホストのIPv6アドレス確認
echo "1. ホストのIPv6アドレスを確認中..."
IPV6_ADDR=$(ip -6 addr show | grep "inet6" | grep -v "scope link" | grep -v "::1" | awk '{print $2}' | head -1 | cut -d'/' -f1)

if [ -z "$IPV6_ADDR" ]; then
    echo "エラー: ホストにIPv6アドレスが設定されていません"
    echo ""
    echo "IPv6を有効化するには以下を確認してください:"
    echo "  1. ルーターでIPv6 (IPoE) が有効か"
    echo "  2. /etc/sysctl.conf で net.ipv6.conf.all.disable_ipv6=0"
    echo "  3. ネットワーク設定でIPv6が有効か"
    exit 1
fi

echo "   IPv6アドレス検出: $IPV6_ADDR"
echo ""

# K3sサーバーノードかエージェントノードか確認
if [ -f /etc/systemd/system/k3s.service ]; then
    K3S_SERVICE="k3s"
    K3S_MODE="server"
    echo "2. K3sサーバーノードを検出"
elif [ -f /etc/systemd/system/k3s-agent.service ]; then
    K3S_SERVICE="k3s-agent"
    K3S_MODE="agent"
    echo "2. K3sエージェントノードを検出"
else
    echo "エラー: K3sがインストールされていません"
    exit 1
fi

echo ""

# K3s設定ファイルのバックアップ
echo "3. 現在の設定をバックアップ中..."
cp /etc/systemd/system/${K3S_SERVICE}.service /etc/systemd/system/${K3S_SERVICE}.service.backup.$(date +%Y%m%d_%H%M%S)

# K3s環境変数ファイルの作成
echo "4. IPv6設定を追加中..."

if [ "$K3S_MODE" == "server" ]; then
    cat > /etc/systemd/system/k3s.service.env <<EOF
# K3s IPv6デュアルスタック設定
# 生成日時: $(date)

# クラスタのIPファミリー設定
K3S_CLUSTER_CIDR="10.42.0.0/16,fd00:42::/56"
K3S_SERVICE_CIDR="10.43.0.0/16,fd00:43::/112"

# デュアルスタック有効化
K3S_DUAL_STACK="true"

# IPv6転送を有効化
EOF

    echo "   サーバーノードの設定完了"
    echo ""
    echo "   クラスタCIDR (Pod): 10.42.0.0/16 (IPv4), fd00:42::/56 (IPv6)"
    echo "   サービスCIDR: 10.43.0.0/16 (IPv4), fd00:43::/112 (IPv6)"
else
    echo "   エージェントノードは追加設定不要"
fi

echo ""

# カーネルパラメータの設定
echo "5. カーネルパラメータを設定中..."
cat >> /etc/sysctl.conf <<EOF

# K3s IPv6サポート
net.ipv6.conf.all.forwarding=1
net.ipv6.conf.all.accept_ra=2
net.bridge.bridge-nf-call-ip6tables=1
EOF

sysctl -p > /dev/null 2>&1

echo "   IPv6フォワーディング有効化完了"
echo ""

# 変更の適用
echo "6. systemd設定を再読み込み中..."
systemctl daemon-reload

echo ""
echo "========================================"
echo "設定完了！"
echo "========================================"
echo ""
echo "次のステップ:"
echo ""
if [ "$K3S_MODE" == "server" ]; then
    echo "  1. 全てのノードで同じ設定を実行してください"
    echo ""
    echo "  2. マスターノードでK3sを再起動:"
    echo "     sudo systemctl restart k3s"
    echo ""
    echo "  3. エージェントノードでK3sを再起動:"
    echo "     sudo systemctl restart k3s-agent"
else
    echo "  1. K3sエージェントを再起動:"
    echo "     sudo systemctl restart k3s-agent"
fi
echo ""
echo "  4. 設定確認:"
echo "     kubectl get nodes -o wide"
echo "     kubectl get pods -A -o wide"
echo ""
echo "注意: 再起動後、全てのPodが再作成されます"
echo ""

# 自動再起動の確認
read -p "今すぐK3sを再起動しますか？ (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    echo "K3sを再起動中..."
    systemctl restart ${K3S_SERVICE}
    echo "再起動完了！"
    echo ""
    echo "ステータス確認:"
    systemctl status ${K3S_SERVICE} --no-pager | head -20
fi
