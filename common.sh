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
# 各个源码的索引;(也为下载顺序,编译顺序)
ffmpeg=0
x264=1
fdkaac=2
mp3lame=3
fribidi=4
freetype=5
expat=6
fontconfig=7
ass=8

# 各个源码的名字
LIBS[ffmpeg]=ffmpeg
LIBS[x264]=x264
LIBS[fdkaac]=fdk-aac
LIBS[mp3lame]=mp3lame
LIBS[fribidi]=fribidi
LIBS[freetype]=freetype
LIBS[expat]=expat
LIBS[fontconfig]=fontconfig
LIBS[ass]=ass

# 各个源码对应的pkg-config中.pc的名字
LIBS_PKGS[ffmpeg]=ffmpeg
LIBS_PKGS[x264]=x264
LIBS_PKGS[fdkaac]=fdk-aac
LIBS_PKGS[mp3lame]=mp3lame
LIBS_PKGS[fribidi]=fribidi
LIBS_PKGS[freetype]=freetype2
LIBS_PKGS[expat]=expat
LIBS_PKGS[fontconfig]=fontconfig
LIBS_PKGS[ass]=libass

# 默认情况下会检测extra目录下是否有对应的源码，如果没有且要编译这些库，那么将到这里对应的地址去下载
# ffmpeg
All_Resources[ffmpeg]=https://codeload.github.com/FFmpeg/FFmpeg/tar.gz/n4.2
# x264
All_Resources[x264]=https://code.videolan.org/videolan/x264/-/archive/stable/x264-stable.tar.gz
# fdkaac
All_Resources[fdkaac]=https://jaist.dl.sourceforge.net/project/opencore-amr/fdk-aac/fdk-aac-2.0.0.tar.gz
#mp3lame
All_Resources[mp3lame]=https://jaist.dl.sourceforge.net/project/lame/lame/3.100/lame-3.100.tar.gz
# fribidi
All_Resources[fribidi]=https://codeload.github.com/fribidi/fribidi/tar.gz/v1.0.10
# freetype
All_Resources[freetype]=https://mirror.yongbok.net/nongnu/freetype/freetype-2.10.2.tar.gz
# expat
All_Resources[expat]=https://github.com/libexpat/libexpat/releases/download/R_2_2_9/expat-2.2.9.tar.gz
# fontconfig
All_Resources[fontconfig]=https://www.freedesktop.org/software/fontconfig/release/fontconfig-2.13.92.tar.gz
# libass
All_Resources[ass]=https://codeload.github.com/libass/libass/tar.gz/0.14.0

# 外部库引入ffmpeg时的配置参数
# 这里必须要--enable-encoder --enable-decoder的方式开启libx264，libfdk_aac，libmp3lame
# 否则外部库无法加载到ffmpeg中
# libx264和mp3lame只提供编码功能，h264和mp3的解码是ffmpeg内置的库(--enable-decoder=h264和--enable-decoder=mp3float开启)
LIBS_PARAM[ffmpeg]=""
LIBS_PARAM[x264]="--enable-gpl --enable-libx264 --enable-encoder=libx264"
LIBS_PARAM[fdkaac]="--enable-nonfree --enable-libfdk-aac --enable-encoder=libfdk_aac"
LIBS_PARAM[mp3lame]="--enable-libmp3lame --enable-encoder=libmp3lame"
LIBS_PARAM[fribidi]="--enable-libfribidi"
LIBS_PARAM[freetype]="--enable-filter=drawtext --enable-libfreetype --enable-muxer=ass --enable-demuxer=ass --enable-muxer=srt --enable-demuxer=srt --enable-muxer=webvtt --enable-demuxer=webvtt --enable-encoder=ass --enable-decoder=ass --enable-encoder=srt --enable-decoder=srt --enable-encoder=webvtt --enable-decoder=webvtt"
LIBS_PARAM[expat]=""
LIBS_PARAM[fontconfig]="--enable-libfontconfig"
LIBS_PARAM[ass]="--enable-libass --enable-filter=subtitles"
export LIBS_PARAM

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

get_cpu_count() {
    if [ "$(uname)" == "Darwin" ]; then
        echo $(sysctl -n hw.physicalcpu)
    else
        echo $(nproc)
    fi
}

# 获取git库的当前分支名
function obtain_git_branch {
  br=`git branch | grep "*"`
  echo ${br/* /}
}

# 检查编译环境是否具备
function check_build_env
{
    echo -e "== check build env ! =="
    # 检查编译环境，比如是否安装 brew yasm gas-preprocessor.pl等等;
    # sh $TOOLS/check-build-env.sh 代表重新开辟一个新shell，是两个不同的shell进程了，互相独立，如果出错，不影响本shell
    #  . $TOOLS/check-build-env.sh 代表在本shell中执行该脚本，全局变量可以共享，如果出错，本shell也会退出。
    . $TOOLS/check-build-env.sh
    echo -e "check build env success ok! ======="
    echo -e ""
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
# $1 代表库的名称 ffmpeg x264
function copy_from_local() {
    
    # 平台对应的forksource目录下存在对应的源码目录，则默认已经有代码了，不拷贝了；如果要重新拷贝，先手动删除forksources下对应的源码
    if [ -d build/forksource/$1 ]; then
#        echo "== copy $3 $2 fork $1 == has exist return"
        return
    fi
    
    echo "== copy fork $1 =="
    mkdir -p build/forksource
    # -rf 拷贝指定目录及其所有的子目录下文件
    cp -rf extra/$1 build/forksource/$1
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
    for lib in $(echo ${!All_Resources[*]})
    do
        if [[ -d extra/${LIBS[$lib]} ]] && [[ ${LIBFLAGS[$lib]} = "TRUE" ]];then
            if [ ${LIBS[$lib]} = "ffmpeg" ] && [ $INTERNAL_DEBUG = "TRUE" ];then
                # ffmpeg用内部自己研究的代码
                if [ ! -d build/forksource/ffmpeg ];then
                    echo "== copy fork ffmpeg =="
                    mkdir -p build/forksource/ffmpeg
                    cp -rf /Users/apple/devoloper/mine/ffmpeg/ffmpeg-source/ build/forksource/ffmpeg
                fi
                
                continue
            fi
            
            # 正常拷贝库
            copy_from_local ${LIBS[$lib]}
            
        fi
    done
}

function rm_extra_source()
{
    echo "....rm extra source...."
    rm -rf extra
}

function rm_all_fork_source()
{
    echo "....rm $1 forksource $2...."
    rm -rf build/forksource
}

function rm_fork_source()
{
    if [ $1 = "all" ];then
        rm -rf build/forksource
        return
    fi
    
    echo "....rm forksource $1...."
    rm -rf build/forksource/$1
}

function rm_build()
{
    if [ $2 = "all" ];then
        rm -rf build/$1-*
        return
    fi
    
    for ARCH in ${*:3}
    do
        echo "....rm $1 build $2 $ARCH...."
        rm -rf build/$1/$2-$ARCH
    done
}

# 版本要和实际下载地址对应;cat > .... << EOF 代表将两个EOF之间内容输入到指定文件
create_mp3lame_package_config() {
    local pkg_path="$1"
    local prefix_path="$2"

    cat > "${pkg_path}/mp3lame.pc" << EOF
prefix=${prefix_path}
exec_prefix=\${prefix}
libdir=\${exec_prefix}/lib
includedir=\${prefix}/include

Name: libmp3lame
Description: lame mp3 encoder library
Version: 3.100

Requires:
Libs: -L\${libdir} -lmp3lame
Cflags: -I\${includedir}
EOF
}
# 遇到问题：当以静态库方式引入fontconf到ffmpeg中时提示"pkg-conf fontconf not found"
# 分析原因：fontconf自己生成的pc文件不包含expat库，最终导致了错误
# 解决方案：自己定义fontconfig库的pc文件
create_fontconfig_package_config() {
    local pkg_path=$1
    local prefix_path=$2
    cat > "${pkg_path}/fontconfig.pc" << EOF
prefix=${prefix_path}
exec_prefix=\${prefix}
libdir=\${exec_prefix}/lib
includedir=\${prefix}/include
sysconfdir=\${prefix}/etc
localstatedir=\${prefix}/var
PACKAGE=fontconfig
confdir=\${sysconfdir}/fonts
cachedir=\${localstatedir}/cache/\${PACKAGE}

Name: Fontconfig
Description: Font configuration and customization library
Version: 2.13.92
Requires:  freetype2 >= 21.0.15, expat >= 2.2.0
Requires.private:
Libs: -L\${libdir} -lfontconfig
Libs.private:
Cflags: -I\${includedir}
EOF
}
create_zlib_system_package_config() {
    local SDK_PATH=$1
    local PKG_PATH=$2
    
    ZLIB_VERSION=$(grep '#define ZLIB_VERSION' ${SDK_PATH}/usr/include/zlib.h | grep -Eo '\".*\"' | sed -e 's/\"//g')

    cat > "${PKG_PATH}/zlib.pc" << EOF
prefix=${SDK_PATH}/usr
exec_prefix=\${prefix}
libdir=\${exec_prefix}/lib
includedir=\${prefix}/include

Name: zlib
Description: zlib compression library
Version: ${ZLIB_VERSION}

Requires:
Libs: -L\${libdir} -lz
Cflags: -I\${includedir}
EOF
}
create_libiconv_system_package_config() {
    local SDK_PATH=$1
    local PKG_PATH=$2
    local LIB_ICONV_VERSION=$(grep '_LIBICONV_VERSION' ${SDK_PATH}/usr/include/iconv.h | grep -Eo '0x.*' | grep -Eo '.*    ')

    cat > "${PKG_PATH}/libiconv.pc" << EOF
prefix=${SDK_PATH}/usr
exec_prefix=\${prefix}
libdir=\${exec_prefix}/lib
includedir=\${prefix}/include

Name: libiconv
Description: Character set conversion library
Version: ${LIB_ICONV_VERSION}

Requires:
Libs: -L\${libdir} -liconv -lcharset
Cflags: -I\${includedir}
EOF
}
create_bzip2_system_package_config() {
    local SDK_PATH=$1
    local PKG_PATH=$2
    BZIP2_VERSION=$(grep -Eo 'version.*of' ${SDK_PATH}/usr/include/bzlib.h | sed -e 's/of//;s/version//g;s/\ //g')

    cat > "${PKG_PATH}/bzip2.pc" << EOF
prefix=${SDK_PATH}/usr
exec_prefix=\${prefix}
libdir=\${exec_prefix}/lib
includedir=\${prefix}/include

Name: bzip2
Description: library for lossless, block-sorting data compression
Version: ${BZIP2_VERSION}

Requires:
Libs: -L\${libdir} -lbz2
Cflags: -I\${includedir}
EOF
}
create_libuuid_system_package_config() {
    local SDK_PATH=$1
    local PKG_PATH=$2

    cat > "${PKG_PATH}/uuid.pc" << EOF
prefix=${SDK_PATH}
exec_prefix=\${prefix}
libdir=\${exec_prefix}/usr/lib
includedir=\${prefix}/include

Name: uuid
Description: Universally unique id library
Version:
Requires:
Cflags: -I\${includedir}
Libs: -L\${libdir}
EOF
}
