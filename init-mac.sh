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

# 显示当前shell的所有变量(环境变量，自定义变量，与bash接口相关的变量)
set -e
# 公用工具脚本路径
TOOLS=tools
# 获取三方库(x264 lame fdk-aac等)代码脚本路径
EXTERNAL=external
# ffmpeg 源码存储路径
FFMPEG_LOCAL_REPO=extra/ffmpeg

# 由于目前设备基本都是电脑64位 手机64位 所以这里脚本默认只支持 arm64 x86_64两个平台
# FF_ALL_ARCHS="armv7 armv7s arm64 i386 x86_64"
FF_ALL_ARCHS="arm64 x86_64"

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

# 源码fork到本地的路径;请勿随便更改
FORK_SOURCE=ios/forksource
function pull_common() {
    
    echo "== check build env ! =="
    # 检查编译环境，比如是否安装 brew yasm gas-preprocessor.pl等等
    sh $TOOLS/check-build-env.sh

    git --version

    # 拉取 x264源码
    echo "== pull xh264 base =="
    sh $EXTERNAL/init-x264.sh ios "$FF_ALL_ARCHS" $FORK_SOURCE

    # 拉取 fdkaac源码
    echo "== pull fdkaac base =="
    sh $EXTERNAL/init-fdk-aac.sh ios "$FF_ALL_ARCHS" $FORK_SOURCE

    # 拉取 mp3lame源码
    echo "== pull mp3lame base =="
    sh $EXTERNAL/init-mp3lame.sh ios "$FF_ALL_ARCHS" $FORK_SOURCE

    # 拉取 ffmpeg源码
    echo "== pull ffmpeg base =="
    sh $TOOLS/pull-repo-base.sh $FFMPEG_UPSTREAM $FFMPEG_LOCAL_REPO
}

function pull_fork() {
    echo "== pull ffmpeg fork $1 =="
#    sh $TOOLS/pull-repo-ref.sh $IJK_FFMPEG_FORK ios/ffmpeg-$1 ${FFMPEG_LOCAL_REPO}
    # 这里直接copy 过去
    if [ -d $FORK_SOURCE/ffmpeg-$1 ]; then
        rm -rf $FORK_SOURCE/ffmpeg-$1
    fi
    cp -rf $FFMPEG_LOCAL_REPO $FORK_SOURCE/ffmpeg-$1
    cd $FORK_SOURCE/ffmpeg-$1
    # 创建本地分支ijkplayer 并且关联到FFMPEG_COMMIT指定的远程分支
    result=`obtain_git_branch`
    if [[ $result != $FFMPEG_VERSION ]]; then
        # 避免再次切换分支会出现 fatal: A branch named xxx already exists 错误；不用管
        git checkout -b $FFMPEG_VERSION ${FFMPEG_COMMIT}
    fi
    # 进入最近一次的目录，这里就是进入cd 编译脚本所在目录
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
#=== sh脚本执行结束 ==== #

