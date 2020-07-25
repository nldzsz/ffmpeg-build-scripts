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
# 显示当前shell的所有变量(环境变量，自定义变量，与bash接口相关的变量)
set -e

# =====自定义字典实现======== #
# 各个源码的索引;
ffmpeg=0
x264=1
fdkaac=2
mp3lame=3
ass=4
freetype=5
fribidi=6

# 各个源码的名字
LIBS[ffmpeg]=ffmpeg
LIBS[x264]=x264
LIBS[fdkaac]=fdk-aac
LIBS[mp3lame]=mp3lame
LIBS[ass]=ass
LIBS[freetype]=freetype
LIBS[fribidi]=fribidi

# 默认情况下会检测extra目录下是否有对应的源码，如果没有且要编译这些库，那么将到这里对应的地址去下载
# ffmpeg
All_Resources[ffmpeg]=https://codeload.github.com/FFmpeg/FFmpeg/tar.gz/n4.2

# x264
All_Resources[x264]=https://code.videolan.org/videolan/x264/-/archive/stable/x264-stable.tar.gz

# fdkaac
All_Resources[fdkaac]=https://jaist.dl.sourceforge.net/project/opencore-amr/fdk-aac/fdk-aac-2.0.0.tar.gz

#mp3lame
All_Resources[mp3lame]=https://jaist.dl.sourceforge.net/project/lame/lame/3.100/lame-3.100.tar.gz

# libass
All_Resources[ass]=https://codeload.github.com/libass/libass/tar.gz/0.14.0

# freetype
All_Resources[freetype]=https://mirror.yongbok.net/nongnu/freetype/freetype-2.10.2.tar.gz

# fribidi
All_Resources[fribidi]=https://codeload.github.com/fribidi/fribidi/tar.gz/v1.0.10

# =====自定义字典实现======== #

# 平台
uname=`uname`
if [ $uname == "Darwin" ];then
export OUR_SED="sed -i '' "
else
export OUR_SED="sed -i"
fi

# 公用工具脚本路径
TOOLS=tools
# 获取git库的当前分支名
function obtain_git_branch {
  br=`git branch | grep "*"`
  echo ${br/* /}
}

# 检查编译环境是否具备
function check_build_env
{
    echo "== check build env ! =="
    # 检查编译环境，比如是否安装 brew yasm gas-preprocessor.pl等等;
    # sh $TOOLS/check-build-env.sh 代表重新开辟一个新shell，是两个不同的shell进程了，互相独立，如果出错，不影响本shell
    #  . $TOOLS/check-build-env.sh 代表在本shell中执行该脚本，全局变量可以共享，如果出错，本shell也会退出。
    . $TOOLS/check-build-env.sh
    echo -e "check build env success ok! ======="
}

# wget命令下载源码
function wget_down_lib_sources_ifneeded() {
        
    mkdir -p extra
    for lib in $(echo ${!All_Resources[*]})
    do
        if [ ! -d extra/${LIBS[$lib]} ] && [ ${LIBFLAGS[$lib]} == "TRUE" ];then
            UPSTREAM=${All_Resources[$lib]}
            echo "== pull ${LIBS[$lib]} base begin. =="
            . $TOOLS/curl-repo-base.sh $UPSTREAM extra ${LIBS[$lib]}
            echo "== pull ${LIBS[$lib]} base finish =="
        fi
    done
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
    
    # 平台对应的forksource目录下存在对应的源码目录，则默认已经有代码了，不拷贝了；如果要重新拷贝，先删除存在的源码目录
    if [ -d $FORK_SOURCE/$2-$1 ]; then
        echo "== pull $2 fork $1 == has exist return"
        return
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

# 从本地copy源码
# $1 代表平台 armv5 arm64...
# $2 代表库的名称 ffmpeg x264
# $3 代表操作系统平台 ios/windows/linux/android
function copy_from_local() {
    echo "== copy $3 $2 fork $1 =="
    # 平台对应的forksource目录下存在对应的源码目录，则默认已经有代码了，不拷贝了；如果要重新拷贝，先手动删除forksources下对应的源码
    if [ -d $3/forksource/$2-$1 ]; then
        echo "== copy $3 $2 fork $1 == has exist return"
        return
    fi
   
    mkdir -p $3/forksource
    # -rf 拷贝指定目录及其所有的子目录下文件
    cp -rf extra/$2 $3/forksource/$2-$1
}

# ---- 供外部调用，检查编译环境和获取所有用于编译的源码 ------
# 参数为所有需要编译的平台 x86_64 arm64 等等；使用prepare_all ios x86_64 arm64;
# $* 的取值格式为 val1 val2 val3....valn 中间为空格隔开
function prepare_all() {
    # 检查环境
    check_build_env
    
    # 先下载取原始的源码
    wget_down_lib_sources_ifneeded
    
    # 代表从第一个参数之后开始的所有参数
    for ARCH in ${*:2}
    do
        for lib in $(echo ${!All_Resources[*]})
        do
            if [[ -d extra/${LIBS[$lib]} ]] && [[ ${LIBFLAGS[$lib]} = "TRUE" ]];then
                if [ ${LIBS[$lib]} = "ffmpeg" ] && [ $INTERNAL_DEBUG = "TRUE" ];then
                    # ffmpeg用内部自己研究的代码
                    cp -rf "/Users/apple/devoloper/mine/ffmpeg/ffmpeg-source" $1/forksource/${LIBS[$lib]}-$ARCH
                    continue
                fi
                
                # 正常拷贝库
                copy_from_local $ARCH ${LIBS[$lib]} $1
                
            fi
        done
    done
}

function rm_extra_source()
{
    echo "....rm extra source begin...."
    rm -rf extra
    echo "....rm extra source finish...."
}

function rm_fork_source()
{
    echo "....rm forksource source begin...."
    rm -rf $1/forksource
    echo "....rm forksource source finish...."
}
