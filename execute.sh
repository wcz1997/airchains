#!/bin/bash

# 确保 Go 可用
source ~/.profile

# 读取 name 参数
NAME=$(cat ~/.track_name)

# 检查是否在 tracks 目录
if [ ! -d tracks ]; then
  echo "Tracks directory not found. Make sure to run this script in the correct directory."
  exit 1
fi

cd ./tracks

# 获取地址和助记词
ADDRESS=$(grep -oP '(?<=Address: ).*' wallet_output.txt)
MNEMONIC=$(grep -oP '(?<=Mnemonic: ).*' wallet_output.txt)

# 执行 sequencer 设置
go mod tidy
go run cmd/main.go init --daRpc "mock-rpc" --daKey "Mock-Key" --daType "mock" --moniker "${NAME}" --stationRpc "http://127.0.0.1:8545/" --stationAPI "http://127.0.0.1:8545/" --stationType "evm"
go run cmd/main.go prover v1EVM

# 获取 node_id 和真实 IP
NODE_ID=$(grep 'node_id' $HOME/.tracks/config/sequencer.toml | awk -F "=" '{print $2}' | tr -d ' "')
REAL_IP=$(hostname -I | awk '{print $1}')

go run cmd/main.go create-station --accountName "${NAME}" --accountPath $HOME/.tracks/junction-accounts/keys --jsonRPC "https://testnet.rpc.airchains.silentvalidator.com/" --info "EVM Track" --tracks "${ADDRESS}" --bootstrapNode "/ip4/${REAL_IP}/tcp/2300/p2p/${NODE_ID}"

# 配置并启动 stationd 服务
sudo tee /etc/systemd/system/stationd.service > /dev/null << SERVICE_EOF
[Unit]
Description=station track service
After=network-online.target
[Service]
User=$USER
WorkingDirectory=$HOME/tracks/
ExecStart=$(which go) run cmd/main.go start
Restart=always
RestartSec=3
LimitNOFILE=65535
[Install]
WantedBy=multi-user.target
SERVICE_EOF

sudo systemctl daemon-reload
sudo systemctl enable stationd
sudo systemctl start stationd

# 获取私钥
cd ../evm-station
PRIVATE_KEY=$(/bin/bash ./scripts/local-keys.sh)

# 生成随机以太坊地址
TO_ADDRESS=$(openssl rand -hex 20)
TO_ADDRESS="0x${TO_ADDRESS}"

# 创建 transfer.js 文件
mkdir -p $HOME/transfer
cat << EOL > $HOME/transfer/transfer.js
const { ethers } = require("ethers");
const RPC_URL = "http://127.0.0.1:8545";
const provider = new ethers.JsonRpcProvider(RPC_URL);
const privateKey = "${PRIVATE_KEY}";
const wallet = new ethers.Wallet(privateKey, provider);
const toAddress = "${TO_ADDRESS}";
const amountInEther = "0.0013";

async function sendTransaction() {
    try {
        const tx = { to: toAddress, value: ethers.parseEther(amountInEther) };
        const receipt = await wallet.sendTransaction(tx);
        await receipt.wait();
        console.log(\`Transaction successful with hash: \${receipt.hash}\`);
    } catch (error) {
        console.error(\`Transaction failed: \${error}\`);
    }
}

setInterval(sendTransaction, 25 * 100);
sendTransaction();
EOL

# 安装依赖
cd $HOME/transfer
npm install ethers@latest

# 创建并启动 transfer 服务
sudo tee /etc/systemd/system/transfer.service > /dev/null << SERVICE_EOF
[Unit]
Description=Transfer Service
After=network.target

[Service]
User=$USER
WorkingDirectory=$HOME/transfer
ExecStart=$(which node) transfer.js
Restart=always
RestartSec=3
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
SERVICE_EOF

sudo systemctl daemon-reload
sudo systemctl enable transfer
sudo systemctl start transfer

echo "Execute script executed successfully."
sudo journalctl -u stationd -f -o cat
