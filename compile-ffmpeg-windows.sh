#! /usr/bin/env bash
#
# Copyright (C) 2013-2014 Bilibili
# Copyright (C) 2013-2014 Zhang Rui <bbcallen@gmail.com>
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

#----------
set -e
#当前windows操作系统的位数，如果是64位则填写x86_64，32位则填写x86
export FF_WINDOW_ARCH="x86_64"

# 是否将这些外部库添加进去;如果不添加 则将对应的值改为FALSE即可；默认添加3个库
export lIBS=(x264 fdk-aac mp3lame)
export LIBFLAGS=(FALSE TRUE TRUE)
# 内部调试用
export INTERNAL_DEBUG=FALSE
UNI_BUILD_ROOT=`pwd`

real-do-compile()
{	
	CONFIGURE_FLAGS=$1
	lib=$2
	SOURCE=$UNI_BUILD_ROOT/windows/forksource/$lib-$FF_WINDOW_ARCH
	PREFIX=$UNI_BUILD_ROOT/windows/build/$lib-$FF_WINDOW_ARCH
	cd $SOURCE
	
	echo ""
	echo "build windows $lib $FF_WINDOW_ARCH ......."
	echo "CONFIGURE_FLAGS:$CONFIGURE_FLAGS"
	echo "prefix:$PREFIX"
	echo ""

	./configure \
	${CONFIGURE_FLAGS} \
	--prefix=$PREFIX 

	make && make install
	
	cd -
}

#编译x264
do-compile-x264()
{	
	CONFIGURE_FLAGS="--enable-static --enable-shared --enable-pic --disable-cli --enable-strip"
	real-do-compile "$CONFIGURE_FLAGS" "x264"
}

#编译fdk-aac
do-compile-fdk-aac()
{
	CONFIGURE_FLAGS="--enable-static --enable-shared --with-pic "
	real-do-compile "$CONFIGURE_FLAGS" "fdk-aac"
}
#编译mp3lame
do-compile-mp3lame()
{
	#遇到问题：mp3lame连接时提示"export lame_init_old: symbol not defined"
	#分析原因：未找到这个函数的实现
	#解决方案：删除libmp3lame.sym中的lame_init_old
	SOURCE=./windows/forksource/mp3lame-$FF_WINDOW_ARCH/include/libmp3lame.sym
	sed -i "s/lame_init_old//g" $SOURCE
	
	CONFIGURE_FLAGS="--enable-static --enable-shared --disable-frontend "
	real-do-compile "$CONFIGURE_FLAGS" "mp3lame"
}

# 编译外部库
compile_external_lib_ifneed()
{
    #${#array[@]}获取数组长度用于循环
    for(( i=0;i<${#lIBS[@]};i++)) 
    do
        lib=${lIBS[i]};
        FFMPEG_DEP_LIB=$UNI_BUILD_ROOT/windows/build/$lib-$FF_WINDOW_ARCH/lib
		echo "$FFMPEG_DEP_LIB"
        if [[ ${LIBFLAGS[i]} == "TRUE" ]]; then
            if [[ ! -f "${FFMPEG_DEP_LIB}/lib$lib.a" || ! -f "${FFMPEG_DEP_LIB}/lib$lib.dll.a" ]] ; then
                # 编译
                do-compile-$lib
            fi
        fi
    done;
}

do-compile-ffmpeg()
{
	FF_BUILD_NAME=ffmpeg
	FF_BUILD_ROOT=`pwd`/windows

	# 对于每一个库，他们的./configure 他们的配置参数以及关于交叉编译的配置参数可能不一样，具体参考它的./configure文件
	# 用于./configure 的参数
	FF_CFG_FLAGS=
	# 用于./configure 关于--extra-cflags 的参数，该参数包括如下内容：
	# 1、关于cpu的指令优化
	# 2、关于编译器指令有关参数优化
	# 3、指定引用三方库头文件路径或者系统库的路径
	FF_EXTRA_CFLAGS=""
	# 用于./configure 关于--extra-ldflags 的参数
	# 1、指定引用三方库的路径及库名称 比如-L<x264_path> -lx264
	FF_EXTRA_LDFLAGS=
	
	FF_SOURCE=$FF_BUILD_ROOT/forksource/$FF_BUILD_NAME-$FF_WINDOW_ARCH
	FF_PREFIX=$FF_BUILD_ROOT/build/$FF_BUILD_NAME
	mkdir -p $FF_PREFIX

	# 开始编译
	# 导入ffmpeg 的配置
	export COMMON_FF_CFG_FLAGS=
		. $FF_BUILD_ROOT/../config/module.sh
		

	#导入ffmpeg的外部库
	EXT_ALL_LIBS=
	#${#array[@]}获取数组长度用于循环
	for(( i=0;i<${#lIBS[@]};i++))
	do
		lib=${lIBS[i]};
		lib_name=$lib-$FF_WINDOW_ARCH
		lib_inc_dir=$FF_BUILD_ROOT/build/$lib_name/include
		lib_lib_dir=$FF_BUILD_ROOT/build/$lib_name/lib
		ENABLE_FLAGS=
		LD_FLAGS=
		# 这里必须要--enable-encoder --enable-decoder的方式开启libx264，libfdk_aac，libmp3lame
		# 否则外部库无法加载到ffmpeg中
		# libx264和mp3lame只提供编码功能，他们的解码是额外的库
		if [ $lib = "x264" ]; then
			ENABLE_FLAGS="--enable-gpl --enable-libx264 --enable-encoder=libx264 --enable-decoder=h264"
		fi

		if [ $lib = "fdk-aac" ]; then
			ENABLE_FLAGS="--enable-nonfree --enable-libfdk-aac --enable-encoder=libfdk_aac --enable-decoder=libfdk_aac"
		fi

		if [ $lib = "mp3lame" ]; then
			ENABLE_FLAGS="--enable-libmp3lame --enable-encoder=libmp3lame --enable-decoder=mp3float"
		fi
		if [[ ${LIBFLAGS[i]} == "TRUE" ]];then
			COMMON_FF_CFG_FLAGS="$COMMON_FF_CFG_FLAGS $ENABLE_FLAGS"

			FF_EXTRA_CFLAGS="$FF_EXTRA_CFLAGS -I${lib_inc_dir}"
			FF_EXTRA_LDFLAGS="$FF_EXTRA_LDFLAGS -L${lib_lib_dir} $LD_FLAGS"
        
			EXT_ALL_LIBS="$EXT_ALL_LIBS $lib_lib_dir/lib$lib.a"
		fi
	done

	FF_CFG_FLAGS="$COMMON_FF_CFG_FLAGS $FF_CFG_FLAGS"

	# 进行裁剪
	FF_CFG_FLAGS="$FF_CFG_FLAGS --enable-ffmpeg --enable-ffprobe";
	# 开启调试;如果关闭 则注释即可
	#FF_CFG_FLAGS="$FF_CFG_FLAGS --enable-debug --disable-optimizations";
	#--------------------
	
	echo ""
	echo "--------------------"
	echo "[*] configurate ffmpeg"
	echo "--------------------"
	echo "FF_CFG_FLAGS=$FF_CFG_FLAGS \n"
	echo "--extra-cflags=$FF_EXTRA_CFLAGS \n"
	echo "--extra-ldflags=$FF_EXTRA_LDFLAGS \n"

	cd $FF_SOURCE
	# 当执行过一次./configure 会在源码根目录生成config.h文件
	./configure $FF_CFG_FLAGS \
		--prefix=$FF_PREFIX \
		--extra-cflags="$FF_EXTRA_CFLAGS" \
		--extra-ldflags="$FF_EXTRA_LDFLAGS" \

	#------- 编译和连接 -------------
	#生成各个模块对应的静态或者动态库(取决于前面是生成静态还是动态库)
	echo ""
	echo "--------------------"
	echo "[*] compile ffmpeg"
	echo "--------------------"
	cp config.* $FF_PREFIX
	make && make install
	mkdir -p $FF_PREFIX/include/libffmpeg
	cp -f config.h $FF_PREFIX/include/libffmpeg/config.h
	# 拷贝外部库
	for lib in $EXT_ALL_LIBS
	do
		cp -f $lib $FF_PREFIX/lib
	done
	cd -
}

# 检查是否安装了pkg-config
if [[ ! `which pkg-config` ]]; then
    echo "check pkg-config env......"
    echo "pkg-config not found begin install....."
    apt-cyg install pkg-config || exit 1
    echo -e "check pkg-config ok......"
fi

FF_TARGET=$1
# 命令开始执行处----------
if [ "$FF_TARGET" == "reset" ]; then
    # 重新拉取所有代码
    echo "....repull all source...."
    rm -rf windows/forksource
    . ./compile-init.sh windows
elif [ "$FF_TARGET" == "all" ]; then
    
    # 开始之前先检查fork的源代码是否存在
    if [ ! -d windows/forksource ]; then
        . ./compile-init.sh windows "offline"
    fi
    
    rm -rf windows/build/ffmpeg-*
    
	# 先编译外部库
    compile_external_lib_ifneed
	
    # 最后编译ffmpeg
    do-compile-ffmpeg
    
elif [ "$FF_TARGET" = "clean" ]; then

    echo "=================="
    echo "clean ffmpeg"
    cd windows/forksource/ffmpeg && git clean -xdf && cd -
    echo "clean build cache"
    echo "================="
    rm -rf windows/build/ffmpeg-*
    echo "clean success"
else
    echo "Usage:"
    echo "  compile-ffmpeg.sh all"
    echo "  compile-ffmpeg.sh clean"
    echo "  compile-ffmpeg.sh reset"
    exit 1
fi
