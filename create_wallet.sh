#!/bin/bash

# 确保 Go 可用
source ~/.profile

# 检查是否在 tracks 目录
if [ ! -d tracks ]; then
  echo "Tracks directory not found. Make sure to run this script in the correct directory."
  exit 1
fi

cd tracks

# 读取 name 参数
NAME=$(cat ~/.track_name)

# 生成钱包地址并保存输出
OUTPUT_FILE="wallet_output.txt"
go run cmd/main.go keys junction --accountName "${NAME}" --accountPath $HOME/.tracks/junction-accounts/keys > $OUTPUT_FILE

# 移除 ANSI 转义代码
sed -i 's/\x1b\[[0-9;]*m//g' $OUTPUT_FILE

# 提取地址和助记词
MNEMONIC=$(grep 'Mnemonic:' $OUTPUT_FILE | sed 's/.*Mnemonic: //')
ADDRESS=$(grep 'Address:' $OUTPUT_FILE | sed 's/.*Address: //')

# 保存助记词到文件
echo "Mnemonic: $MNEMONIC" > mnemonic.txt
echo "Address: $ADDRESS" >> mnemonic.txt

echo "Wallet created successfully. Mnemonic and Address saved to mnemonic.txt."
echo "Please obtain tokens for the address: $ADDRESS"
