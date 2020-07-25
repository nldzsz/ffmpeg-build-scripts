#! /usr/bin/env bash

# ======= 检查编译环境 ========= #
uname=`uname`
echo -e "check $uname build env ======="
if [[ $uname = "Darwin" ]]  && [[ ! `which brew` ]]; then
    # Mac平台检查是否安装了 brew；如果没有安装，则进行安装
    echo "check Homebrew env......"
	echo 'Homebrew not found. Trying to install...'
	ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)" || exit 1
    echo -e "check Homebrew ok......"
fi

# wget用于下载资源的命令包
echo "check wget env......"
if [[ ! `which wget` ]]; then
    echo "wget not found begin install....."
    if [[ "$(uname)" == "Darwin" ]];then
        # Mac平台;自带
        brew install wget
    elif [[ "$(uname)" == "Linux" ]];then
        # Linux平台
        sudo apt install wget || exit 1
    else
        # windows平台
        apt-cyg install wget || exit 1
    fi
fi
echo -e "check wget ok......"

# yasm是PC平台的汇编器(nasm也是，不过yasm是nasm的升级版)，用于windows，linux，osx系统的ffmpeg汇编部分编译；
if [[ ! `which yasm` ]] && [[ $FF_PLATFORM_TARGET != "ios" && $FF_PLATFORM_TARGET != "android" ]]; then
    echo "check yasm env......"
	echo "yasm not found begin install....."
	if [[ "$(uname)" == "Darwin" ]];then
        # Mac平台
        brew install yasm || exit 1
    elif [[ "$(uname)" == "Linux" ]];then
        # Linux平台和windows平台
        wget http://www.tortall.net/projects/yasm/releases/yasm-1.3.0.tar.gz || exit 1
        tar zxvf yasm-1.3.0.tar.gz || exit 1
        rm yasm-1.3.0.tar.gz
        cd yasm-1.3.0
        ./configure || exit 1
		sudo make && sudo make install || exit 1
        cd -
        rm -rf yasm-1.3.0
    else
        # windows平台
        apt-cyg install yasm || exit 1
    fi
    echo -e "check yasm ok......"
fi

if [[ $uname = "Darwin" || $uname = "Linux" ]]  && [[ ! `which autoconf` ]]; then
    # Mac 平台 autoconf用于基于GNU的make生成工具，有些库不支持Libtool;
    echo "check autoconf env......"
    echo "autoconf not found begin install....."
    
    
    if [[ "$(uname)" == "Darwin" ]];then
        # Mac平台
        brew install autoconf || exit 1
    elif [[ "$(uname)" == "Linux" ]];then
        # Linux平台平台
        sudo apt-get install autoconf
        #result=$(echo `autoconf --version` | perl -pe '($_)=/([0-9]+([.][0-9]+)+)/' )
        #if [[ "$result" < "1.16.1" ]];then
        #    sudo apt-get --purge remove automake
        #    wget http://ftp.gnu.org/gnu/automake/automake-1.16.1.tar.gz
        #    tar zxvf automake-1.16.1.tar.gz || exit 1
        #   rm automake-1.16.1.tar.gz
        #   cd automake-1.16.1
        #    ./configure || exit 1
        #    sudo make && sudo make install || exit 1
        #   cd -
        #    rm -rf automake-1.16.1
        #fi
    else
        # windows平台
        apt-cyg install autoconf || exit 1
    fi
    echo -e "check autoconfl ok......"
fi

if [[ $uname = "Darwin" && $FF_PLATFORM_TARGET == "ios" ]]  && [[ ! `which gas-preprocessor.pl` ]]; then
    # gas-preprocessor.pl是IOS平台用的汇编器，安卓则包含在ndk目录中，不需要单独再指定
    echo "check gas-preprocessor.pl env......"
	echo "gas-preprocessor.pl not found begin install....."
    git clone https://github.com/libav/gas-preprocessor
    sudo cp gas-preprocessor/gas-preprocessor.pl /usr/local/bin/gas-preprocessor.pl
    chmod +x /usr/local/bin/gas-preprocessor.pl
	rm -rf gas-preprocessor
    echo -e "check gas-preprocessor.pl ok......"
fi

# 遇到问题：cygwin平台编译fdk-aac时提示" 'aclocal-1.15' is missing on your system."
# 分析原因：未安装automake
# 解决方案：安装automake
if [[ "$uname" = CYGWIN_NT-* ]]  && [[ ! `which automake` ]]; then
    echo "check automake env......"
    echo "automake not found begin install....."
    apt-cyg install automake || exit 1
    echo -e "check automake ok......"
fi

# 如果要编译ffplay则还需要编译SDL2库
if [[ $ENABLE_FFMPEG_TOOLS = "TRUE" ]] && [[ $FF_PLATFORM_TARGET != "ios" && $FF_PLATFORM_TARGET != "android" ]]; then
    echo "check SDL2 env......"
    if [[ $uname = "Darwin" ]] && [[ ! -d /usr/local/Cellar/sdl2 ]]; then
        brew install SDL2 || exit 1
    elif [[ $uname = "Linux" ]] && [[ ! `dpkg -l|grep libsdl` ]];then
        sudo apt-get install libsdl2-2.0
        sudo apt-get install libsdl2-dev
    fi
    echo -e "check SDL2 env ok......"
fi
