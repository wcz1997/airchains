#!/bin/bash

# 设置非交互模式
export DEBIAN_FRONTEND=noninteractive

# 检查是否提供了参数
if [ $# -ne 1 ]; then
  echo "Usage: $0 <name>"
  exit 1
fi

# 获取参数
NAME=$1

# 保存name到文件
echo $NAME > ~/.track_name

# 安装依赖
sudo apt-get update
sudo apt-get install -y jq 

# 安装 Go 1.22.3
wget https://go.dev/dl/go1.22.3.linux-amd64.tar.gz
sudo tar -C /usr/local -xzf go1.22.3.linux-amd64.tar.gz
echo "export PATH=$PATH:/usr/local/go/bin" >> ~/.profile
source ~/.profile

# 安装 Node.js 18
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt install -y nodejs

# 克隆项目
git clone https://github.com/airchains-network/evm-station.git
git clone https://github.com/airchains-network/tracks.git

cd tracks
git checkout tags/v0.0.4
cd ..

# 执行evm-station的初始设置
cd evm-station
go mod tidy
/bin/bash ./scripts/local-setup.sh

# 配置并启动 evmstationd 服务
sudo tee /etc/systemd/system/evmstationd.service > /dev/null << SERVICE_EOF
[Unit]
Description=evmstationd
After=network.target
[Service]
User=$USER
WorkingDirectory=$HOME/evm-station/
ExecStart=/bin/bash ./scripts/local-start.sh
Restart=always
RestartSec=3
LimitNOFILE=10000
[Install]
WantedBy=multi-user.target
SERVICE_EOF

sudo systemctl daemon-reload
sudo systemctl enable evmstationd
sudo systemctl start evmstationd

echo "Setup script executed successfully. You can now run the second script."
