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
#IJK_FFMPEG_UPSTREAM=git://git.videolan.org/ffmpeg.git
#IJK_FFMPEG_UPSTREAM=https://github.com/Bilibili/FFmpeg.git
#IJK_FFMPEG_FORK=https://github.com/Bilibili/FFmpeg.git
#IJK_FFMPEG_COMMIT=ff3.3--ijk0.8.0--20170518--001
#IJK_FFMPEG_LOCAL_REPO=extra/ffmpeg
# ijkplayer 默认使用的ffmpeg 版本是3.3，这里改为ffmpeg 官网的4.0版本
IJK_FFMPEG_UPSTREAM=https://github.com/FFmpeg/FFmpeg.git
IJK_FFMPEG_FORK=https://github.com/FFmpeg/FFmpeg.git
IJK_FFMPEG_COMMIT=remotes/origin/release/4.2
IJK_FFMPEG_LOCAL_REPO=extra/ffmpeg

# gas-preprocessor据说是一个
IJK_GASP_UPSTREAM=https://github.com/Bilibili/gas-preprocessor.git

# Apple's gas is ancient and doesn't support modern preprocessing features like
# .rept and has ugly macro syntax, among other things. Thus, this script
# implements the subset of the gas preprocessor used by x264 and ffmpeg
# that isn't supported by Apple's gas.
# 意思是说它是一个工具，用来使apple的编译器编译时支持modern preprocessing的工具(这是我的理解？)
# https://github.com/Bilibili/gas-preprocessor.git

# 显示当前shell的所有变量(环境变量，自定义变量，与bash接口相关的变量)
set -e
TOOLS=tools

FF_ALL_ARCHS_IOS6_SDK="armv7 armv7s i386"
FF_ALL_ARCHS_IOS7_SDK="armv7 armv7s arm64 i386 x86_64"
FF_ALL_ARCHS_IOS8_SDK="armv7 arm64 i386 x86_64"
FF_ALL_ARCHS=$FF_ALL_ARCHS_IOS8_SDK

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
    echo $IJK_FFMPEG_COMMIT
}

function pull_common() {
    git --version
    echo "== pull gas-preprocessor base =="
    sh $TOOLS/pull-repo-base.sh $IJK_GASP_UPSTREAM extra/gas-preprocessor

    echo "== pull ffmpeg base =="
    sh $TOOLS/pull-repo-base.sh $IJK_FFMPEG_UPSTREAM $IJK_FFMPEG_LOCAL_REPO
}

function pull_fork() {
    echo "== pull ffmpeg fork $1 =="
#    sh $TOOLS/pull-repo-ref.sh $IJK_FFMPEG_FORK ios/ffmpeg-$1 ${IJK_FFMPEG_LOCAL_REPO}
# 这里直接copy 过去
    if [ -d ios/ffmpeg-$1 ]; then
        rm -rf ios/ffmpeg-$1
    fi
    cp -rf $IJK_FFMPEG_LOCAL_REPO ios/ffmpeg-$1
    cd ios/ffmpeg-$1
# 创建本地分支ijkplayer 并且关联到IJK_FFMPEG_COMMIT指定的远程分支
    git checkout -b ijkplayer ${IJK_FFMPEG_COMMIT}
# 进入最近一次的目录，这里就是进入cd ijkplayer源码所在目 
    cd -
}

# ---- for 语句 ------
# $FF_ALL_ARCHS 的取值格式为 val1 val2 val3....valn 中间为空格隔开
function pull_fork_all() {
    for ARCH in $FF_ALL_ARCHS
    do
        pull_fork $ARCH
    done
}

# 找到ios/IJKMediaPlayer/IJKMediaPlayer/IJKFFMoviePlayerController.m文件，
# 并将文件中kIJKFFRequiredFFmpegVersion的ffmpeg版本号替换为这里实际使用的版本号
function sync_ff_version() {
    sed -i '' "s/static const char \*kIJKFFRequiredFFmpegVersion\ \=\ .*/static const char *kIJKFFRequiredFFmpegVersion = \"${IJK_FFMPEG_COMMIT}\";/g" ios/IJKMediaPlayer/IJKMediaPlayer/IJKFFMoviePlayerController.m
}

#=== sh脚本执行开始 ==== #
# $FF_TARGET 表示脚本执行时输入的第一个参数
# 如果参数为 ffmpeg-version 则表示打印出要使用的ffmpeg版本
# 可以指定要编译的cpu架构类型，比如armv7s 也可以为all或者没有参数 表示全部cpu架构都编译

# ------ case 语句 ------
# armv7|armv7s|arm64|i386|x86_64 表示 如果$FF_TARGET的值为armv7,armv7s,arm64,i386,x86_64中任何一个都可以;注意这里不能替换为||
# * 表示任何字符串
case "$FF_TARGET" in
    ffmpeg-version)
        echo_ffmpeg_version
    ;;
    armv7|armv7s|arm64|i386|x86_64)
        pull_common
        pull_fork $FF_TARGET
    ;;
    all|*)
        pull_common
        pull_fork_all
    ;;
esac

sync_ff_version
#=== sh脚本执行结束 ==== #

