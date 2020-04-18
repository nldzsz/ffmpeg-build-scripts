#! /usr/bin/env bash
#
# Copyright (C) 2013-2015 Bilibili
# Copyright (C) 2013-2015 Zhang Rui <bbcallen@gmail.com>
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

# !======= shell 注释 =======
# ffmpeg git地址
FFMPEG_UPSTREAM=https://github.com/FFmpeg/FFmpeg.git
# 要编译的 ffmpeg 版本这里为4.2;如果要编译其它版本 修改这里即可
FFMPEG_VERSION=4.2
FFMPEG_COMMIT=remotes/origin/release/$FFMPEG_VERSION
# ffmpeg 源码存储路径
FFMPEG_LOCAL_REPO=extra/ffmpeg

# x264 git 地址 这里可以自己更改版本号
X264_UPSTREAM=https://git.videolan.org/git/x264.git
X264_VERSION=stable
X264_COMMIT=remotes/origin/$X264_VERSION
X264_LOCAL_REPO=extra/x264

# fdkaac curl 地址 这里可以自己更改版本号
FDKAAC_VERSION=fdk-aac-2.0.0
FDKAAC_UPSTREAM=https://jaist.dl.sourceforge.net/project/opencore-amr/fdk-aac/$FDKAAC_VERSION.tar.gz
FDKAAC_LOCAL_REPO=extra

#mp3lame curl 地址 这里可以自己更改版本号
MP3LAME_VERSION=lame-3.100
MP3LAME_UPSTREAM=https://jaist.dl.sourceforge.net/project/lame/lame/3.100/$MP3LAME_VERSION.tar.gz
MP3LAME_LOCAL_REPO=extra

# 标记是否拉取过了源码
PULL_TOUCH=extra/touch

# 显示当前shell的所有变量(环境变量，自定义变量，与bash接口相关的变量)
set -e
# 公用工具脚本路径
TOOLS=tools

# 各个平台的cpu架构
# FF_ALL_ARCHS="armv7 armv7s arm64 i386 x86_64"
FF_ALL_ARCHS_ANDROID="armv7a arm64"
FF_ALL_ARCHS_IOS="arm64 x86_64"
FF_ALL_ARCHS_MAC="x86_64"

# $1 表示执行shell脚本时输入的参数 比如./init-ios.sh arm64 x86_64 $1的值为arm64;$1的值为x86_64
# $0 当前脚本的文件名
# $# 传递给脚本或函数的参数个数。
# $* 传递给脚本或者函数的所有参数;
# $@ 传递给脚本或者函数的所有参数;
# 两者区别就是 不被双引号(" ")包含时，都以"$1" "$2" … "$n" 的形式输出所有参数。而"$*"表示"$1 $2 … $n";
# "$@"依然为"$1" "$2" … "$n"
# $$ 脚本所在的进程ID
# $? 上个命令的退出状态，或函数的返回值。一般命令返回值 执行成功返回0 失败返回1
FF_TARGET=$1

function echo_ffmpeg_version() {
    echo $FFMPEG_COMMIT
}

# 获取git库的当前分支名
function obtain_git_branch {
  br=`git branch | grep "*"`
  echo ${br/* /}
}

# 源码fork到本地的路径;默认iOS平台
FORK_SOURCE=ios/forksource

function pull_common() {
    
    echo "== check build env ! =="
    # 检查编译环境，比如是否安装 brew yasm gas-preprocessor.pl等等;
    # sh $TOOLS/check-build-env.sh 用. 相当于将脚本引用进来执行，如果出错，本shell也会退出。而sh 则是重新开辟一个新shell，脚本出错不影响本shell的继续执行
    . $TOOLS/check-build-env.sh

    git --version

    # 拉取 x264源码
    echo "== pull x264 base =="
    . $TOOLS/pull-repo-base.sh $X264_UPSTREAM $X264_LOCAL_REPO

    # 拉取 fdkaac源码
    echo "== pull fdkaac base =="
    . $TOOLS/curl-repo-base.sh $FDKAAC_UPSTREAM $FDKAAC_LOCAL_REPO $FDKAAC_VERSION

    # 拉取 mp3lame源码
    echo "== pull mp3lame base =="
    . $TOOLS/curl-repo-base.sh $MP3LAME_UPSTREAM $MP3LAME_LOCAL_REPO $MP3LAME_VERSION

    # 拉取 ffmpeg源码
    echo "== pull ffmpeg base =="
    . $TOOLS/pull-repo-base.sh $FFMPEG_UPSTREAM $FFMPEG_LOCAL_REPO
    
    # 创建标记
    echo "== create touch =="
    touch $PULL_TOUCH
}

# $1 代表平台 armv5 arm64...
# $2 代表库的名称 ffmpeg x264
# $3 代表库源码在本地的路径
# $4 代表要切换到库的git分支名 ffmpeg 切换到4.2分支
# $5 代表要对应到$4的git 远程分支名 ffmpeg remotes/origin/release/$FFMPEG_VERSION
function fork_from_git() {
    echo "== pull $2 fork $1 =="
# pull-repo-ref.sh 是对git clone --referrence的封装。加快clone速度，如果本地IJK_LOCAL_REPO中有，则从本地直接copy，否则从远程IJK_UPSTREAM拉取
#    sh $TOOLS/pull-repo-ref.sh $IJK_FFMPEG_FORK ios/ffmpeg-$1 ${FFMPEG_LOCAL_REPO}
    
    # 这里直接copy 过去
    if [ -d $FORK_SOURCE/$2-$1 ]; then
        rm -rf $FORK_SOURCE/$2-$1
    fi
    mkdir -p $FORK_SOURCE
    cp -rf $3 $FORK_SOURCE/$2-$1
    cd $FORK_SOURCE/$2-$1
    # 切换到指定的分支
    result=`obtain_git_branch`
    if [[ $result != $4 ]]; then
        # 避免再次切换分支会出现 fatal: A branch named xxx already exists 错误；不用管
        git checkout -b $4 $5
    fi
    # 进入最近一次的目录，这里就是进入cd 编译脚本所在目录
    cd -
}

# $1 代表平台 armv5 arm64...
# $2 代表库的名称 ffmpeg x264
# $3 代表库在本地的路径
function fork_from_curl() {
    echo "== pull $2 fork $1 =="
    if [ -d $FORK_SOURCE/$2-$1 ]; then
        rm -rf $FORK_SOURCE/$2-$1
    fi

    # -rf 拷贝指定目录及其所有的子目录下文件
    cp -rf $3 $FORK_SOURCE/$2-$1
}

# ---- for 语句 ------
# $1 的取值格式为 val1 val2 val3....valn 中间为空格隔开
function pull_fork_all() {
    for ARCH in $*
    do
        # fork ffmpeg
        fork_from_git $ARCH "ffmpeg" $FFMPEG_LOCAL_REPO $FFMPEG_VERSION $FFMPEG_COMMIT

        # fork x264
        fork_from_git $ARCH "x264" $X264_LOCAL_REPO $X264_VERSION $X264_COMMIT

        # fork fdkaac
        fork_from_curl $ARCH "fdk-aac" $FDKAAC_LOCAL_REPO/$FDKAAC_VERSION

        # fork mp3lame
        fork_from_curl $ARCH "mp3lame" $MP3LAME_LOCAL_REPO/$MP3LAME_VERSION
    done
}

# 找到ios/IJKMediaPlayer/IJKMediaPlayer/IJKFFMoviePlayerController.m文件，
# 并将文件中kIJKFFRequiredFFmpegVersion的ffmpeg版本号替换为这里实际使用的版本号
# function sync_ff_version() {
#     sed -i '' "s/static const char \*kIJKFFRequiredFFmpegVersion\ \=\ .*/static const char *kIJKFFRequiredFFmpegVersion = \"${FFMPEG_COMMIT}\";/g" ios/IJKMediaPlayer/IJKMediaPlayer/IJKFFMoviePlayerController.m
# }

#=== sh脚本执行开始 ==== #
# $FF_TARGET 表示脚本执行时输入的第一个参数
# 如果参数为 ffmpeg-version 则表示打印出要使用的ffmpeg版本
# 可以指定要编译的cpu架构类型，比如armv7s 也可以为all或者没有参数 表示全部cpu架构都编译
# ------ case 语句 ------
# armv7|armv7s|arm64|i386|x86_64 表示 如果$FF_TARGET的值为armv7,armv7s,arm64,i386,x86_64中任何一个都可以;注意这里不能替换为||
# * 表示任何字符串
OFF="on"
if [ ! -z $2 ] && [ -f $PULL_TOUCH ] ;then
    OFF=$2
fi

case "$FF_TARGET" in
    ffmpeg-version)
        echo_ffmpeg_version
    ;;
    clean)
        echo "=== clean forksource ===="
        if [ -d ios/forksource ]; then
            rm -rf ios/forksource
        fi
        if [ -d android/forksource ]; then
            rm -rf android/forksource
        fi
        if [ -d mac/forksource ]; then
            rm -rf mac/forksource
        fi
        echo "=== clean local source ===="
    ;;
    ios)
        FORK_SOURCE=$FF_TARGET/forksource
        # 不拉取最新代码
        if [ $OFF != "offline" ];then
            pull_common
        fi
        pull_fork_all $FF_ALL_ARCHS_IOS
    ;;
    android)
        FORK_SOURCE=$FF_TARGET/forksource
        # 不拉取最新代码
        if [ $OFF != "offline" ];then
            pull_common
        fi
        pull_fork_all $FF_ALL_ARCHS_ANDROID
    ;;
    mac)
        FORK_SOURCE=$FF_TARGET/forksource
        # 不拉取最新代码
        if [ $OFF != "offline" ];then
            pull_common
        fi
        pull_fork_all $FF_ALL_ARCHS_MAC
    ;;
    all|*)
        FORK_SOURCE=ios/forksource
        if [ $OFF != "offline" ];then
            pull_common
        fi
        pull_fork_all $FF_ALL_ARCHS_IOS
    ;;
esac
#=== sh脚本执行结束 ==== #
