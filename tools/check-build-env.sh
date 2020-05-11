#! /usr/bin/env bash

# ======= 检查编译环境 ========= #
echo -e "check build env ======="
# 检查是否安装了 brew；如果没有安装，则进行安装
echo "check Homebrew env......"
if [[ ! `which brew` ]]; then
	echo 'Homebrew not found. Trying to install...'
	ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)" || exit 1
fi
echo -e "check Homebrew ok......"

# yasm是汇编器；先检查是否有汇编器
echo "check yasm env......"
if [[ ! `which yasm` ]]; then
	echo "yasm not found begin install....."
	brew install yasm || exit 1
fi
echo -e "check yasm ok......"

# autoconf用于基于GNU的make生成工具，有些库不支持Libtool;
echo "check autoconf env......"
if [[ ! `which autoconf` ]]; then
    echo "autoconf not found begin install....."
    brew install autoconf || exit 1
fi
echo -e "check autoconfl ok......"

# gas-preprocessor.pl是汇编将汇编代码转换成目标平台机(ios)机器码的工具
echo "check gas-preprocessor.pl env......"
if [[ ! `which gas-preprocessor.pl` ]]; then
	echo "gas-preprocessor.pl not found begin install....."
    git clone https://github.com/libav/gas-preprocessor
    sudo cp gas-preprocessor/gas-preprocessor.pl /usr/local/bin/gas-preprocessor.pl
    chmod +x /usr/local/bin/gas-preprocessor.pl
	rm -rf gas-preprocessor
fi
echo -e "check gas-preprocessor.pl ok......"
echo -e "check build env over ======="
