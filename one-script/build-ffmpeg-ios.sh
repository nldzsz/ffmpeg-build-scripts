#! /usr/bin/env bash

# 源码存放目录
SOURCE_DIR=extra
# 编译目录
BUILD_DIR=build
# 编译最终结果存放目录
BUILD_UNIVERSAL_DIR=$BUILD_DIR/universal
# 各个库的编译结果存放目录
BUILD_THIN_DIR=$BUILD_DIR/thin
# 最低编译系统版本
TARGET_OS=10.0

# gas-preprocessor 用于将汇编代码转换成机器码的工具
GAS_PREPROCESSOR_URL=https://github.com/libav/gas-preprocessor/blob/master/gas-preprocessor.pl

# ======== ffmpeg 配置  ============ # 
# ffmpeg git地址
FFMPEG_URL=https://github.com/FFmpeg/FFmpeg.git
# 要编译的 ffmpeg 版本;如果要编译其它版本 修改这里即可
FFMPEG_VERSION=4.2
# ======== ffmpeg 配置  ============ # 

# ======== x264 配置  ============ # 
# x264 git地址
X264_URL=https://git.videolan.org/git/x264.git
# 要编译的 x264 版本;如果要编译其它版本 修改这里即可
X264_VERSION=remotes/origin/stable
# 是否将x264编译到ffmpeg中；为FALSE 则表示不编译进去
# X264_BUILD=TRUE

# ======== x264 配置  ============ # 

# ======== fdk_aac 配置  ============ #
# 要编译的 fdk_aac 版本;如果要编译其它版本 修改这里即可
FDK_AAC_TARGET=fdk-aac-2.0.0
# fdk_aac 地址
FDK_AAC_URL=https://jaist.dl.sourceforge.net/project/opencore-amr/fdk-aac/$FDK_AAC_TARGET.tar.gz
# 是否将fdk-aac编译到ffmpeg中；为FALSE 则表示不编译进去
# FDK_AAC_BUILD=TRUE
# ======== fdk_aac 配置  ============ # 

# ======== mp3lame 配置  ============ # 
# 要编译的 mp3lame 版本;如果要编译其它版本 修改这里即可
MP3LAME_TARGET=lame-3.100
# mp3lame 地址
MP3LAME_URL=https://jaist.dl.sourceforge.net/project/lame/lame/3.100/$MP3LAME_TARGET.tar.gz
# 是否将mp3lame编译到ffmpeg中；为FALSE 则表示不编译进去
# MP3LAME_BUILD=TRUE
# ======== mp3lame 配置  ============ # 

# 显示当前shell的所有变量(环境变量，自定义变量，与bash接口相关的变量)
set -e

# 支持的编译平台;可以在这里配置
# FF_ALL_ARCHS="armv7 armv7s arm64 i386 x86_64"
FF_ALL_ARCHS="arm64 x86_64"
# 要编译的平台 
FF_ARCH=$1

if [ -z "$FF_ARCH" ]; then
# -e 则支持换行
    echo -e "useage:\nbuild_ios.sh all|armv7|armv7s|arm64|i386|x86_64'\n"
    exit 1
fi

# ffmpeg 编译参数 通用参数
FFMPEG_CFG_FLAGS="--enable-static --disable-shared --enable-small --enable-cross-compile --disable-debug --disable-programs \
                 --disable-doc --enable-pic"

# 先创建extra目录
if [[ ! -d $SOURCE_DIR ]]; then
	mkdir $SOURCE_DIR
fi

# 获取git库的当前分支名
function obtain_git_branch {
  br=`git branch | grep "*"`
  echo ${br/* /}
}

# 通过 git 获取源码 $1 git地址 $2 本地保存路径 $3 要使用的远程分支 $4 在本地对应的分支
# 如果要重新拉取；删掉对应的源码目录即可
function pull_source_from_git()
{
	echo "==== pull $2 source begin====="
	# -z 变量是否为零 -o 逻辑或
	if [ -z $1 -o -z $SOURCE_DIR/$2 ]; then
    	echo "invalid '$REMOTE_REPO' '$LOCAL_WORKSPACE'"
	elif [ ! -d $SOURCE_DIR/$2 ]; then
		echo "$1 $SOURCE_DIR/$2"
    	git clone $1 $SOURCE_DIR/$2
	else
    	cd $SOURCE_DIR/$2
    	git fetch --all --tags
    	cd -
	fi

	# 切换分支
	cd $SOURCE_DIR/$2
	result=`obtain_git_branch`
	if [[ $result != $4 ]]; then
		# 避免再次切换分支会出现 fatal: A branch named xxx already exists 错误；不用管
    	git checkout -B $4 $3
	fi
	cd -
    echo "==== pull $2 source sucess ====="
}

# 通过 curl下载gz源码，并解压;参数1 下载远程地址；参数2 本地保存路径名
function pull_source_by_curl()
{
	echo "==== curl $2 source begin====="
	if [ ! -d $SOURCE_DIR/$2 ] ; then
		cd $SOURCE_DIR
		curl -O $1
		tar zxf $2.tar.gz
		rm $2.tar.gz
		cd -
	fi
	echo "==== curl $2 source sucess====="
}

# 编译 x264 $1 当前要编译的平台
function build_x264()
{
	ARCH=$1

	# 获取当前绝对路径
	CWD=`pwd`
	
	# 如果已经编译过 则不需重复编译
	prefixdir=$CWD/$BUILD_DIR/x264-$ARCH
	if [[ -f $prefixdir/lib/libx264.a ]]; then
		return 0
	fi

	echo "building x264 $ARCH..."
	# 创建x264编译目录,编译的中间产物将放置于此目录中，不会对源码造成污染；如果不进入到指定目录，make工具默认再当前目录下进行编译.
	# 编译目录不存在 则创建
	if [[ ! -d $BUILD_DIR/build_x264_$ARCH ]]; then
		mkdir -p $BUILD_DIR/build_x264_$ARCH
	fi

	cd "$BUILD_DIR/build_x264_$ARCH"
	CFLAGS="-arch $ARCH"
	ASFLAGS=

	if [ "$ARCH" = "i386" -o "$ARCH" = "x86_64" ]
	then
	    PLATFORM="iPhoneSimulator"
	    CPU=
	    if [ "$ARCH" = "x86_64" ]
	    then
	    	CFLAGS="$CFLAGS -mios-simulator-version-min=$TARGET_OS"
	    	HOST=
	    else
	    	CFLAGS="$CFLAGS -mios-simulator-version-min=$TARGET_OS"
			HOST="--host=i386-apple-darwin"
	    fi
	else
	    PLATFORM="iPhoneOS"
	    if [ $ARCH = "arm64" ]
	    then
	        HOST="--host=aarch64-apple-darwin"
			XARCH="-arch aarch64"
	    else
	        HOST="--host=arm-apple-darwin"
			XARCH="-arch arm"
	    fi
        CFLAGS="$CFLAGS -fembed-bitcode -mios-version-min=$TARGET_OS"
        ASFLAGS="$CFLAGS"
	fi

	# 将xcrun的参数命令全部转换成小写
	XCRUN_SDK=`echo $PLATFORM | tr '[:upper:]' '[:lower:]'`
	# CC 常量用于指定本次编译的编译器(包括C和C++)，它是一个系统环境变量
	CC="xcrun -sdk $XCRUN_SDK clang"
	if [ $PLATFORM = "iPhoneOS" ]
	then
	# x264源码自带gas-preprocessor.pl，使用自带的；并将该变量引入系统环境变量
	    export AS="$CWD/$SOURCE_DIR/x264/tools/gas-preprocessor.pl $XARCH -- $CC"
	else
	# 取消系统环境变量AS
	    export -n AS
	fi

	CXXFLAGS="$CFLAGS"
	LDFLAGS="$CFLAGS"
	CC=$CC $CWD/$SOURCE_DIR/x264/configure \
	    --enable-static --enable-pic --disable-cli \
	    $HOST \
	    --extra-cflags="$CFLAGS" \
	    --extra-asflags="$ASFLAGS" \
	    --extra-ldflags="$LDFLAGS" \
	    --prefix="$prefixdir" || exit 1
	echo "x264 CC $CC"

	make -j3 install || exit 1
	cd $CWD
}

# 编译 fdk_aac
function build_fdk_aac()
{
	CWD=`pwd`

	for ARCH in $ARCHS
	do
		# 如果已经编译过 则不需重复编译
		prefixdir=$CWD/$BUILD_DIR/fdkaac-$ARCH
		if [[ -f $prefixdir/lib/libx264.a ]]; then
			continue
		fi

		echo "building fdk aac $ARCH..."
		
		# 编译目录不存在，则创建
		if [[ ! -d $BUILD_DIR/build_fdkaac_$ARCH ]]; then
			mkdir -p $BUILD_DIR/build_fdkaac_$ARCH
		fi
		cd "$BUILD_DIR/build_fdkaac_$ARCH"

		CFLAGS="-arch $ARCH"

		if [ "$ARCH" = "i386" -o "$ARCH" = "x86_64" ]
		then
			PLATFORM="iPhoneSimulator"
			CPU=
			if [ "$ARCH" = "x86_64" ]
			then
			   	CFLAGS="$CFLAGS -mios-simulator-version-min=$target_ios"
			   	HOST="--host=x86_64-apple-darwin"
			else
			    CFLAGS="$CFLAGS -mios-simulator-version-min=$target_ios"
				HOST="--host=i386-apple-darwin"
			fi
		else
			PLATFORM="iPhoneOS"
			if [ "$ARCH" = "arm64" ]
			then
	#		    CFLAGS="$CFLAGS -D__arm__ -D__ARM_ARCH_7EM__" # hack!
	            CFLAGS="$CFLAGS -mios-version-min=$target_ios"
		        HOST="--host=aarch64-apple-darwin"
	        else
		        CFLAGS="$CFLAGS -mios-version-min=$target_ios"
		        HOST="--host=arm-apple-darwin"
	        fi
	        CFLAGS="$CFLAGS -fembed-bitcode"
		fi

		XCRUN_SDK=`echo $PLATFORM | tr '[:upper:]' '[:lower:]'`
			
		CC="xcrun -sdk $XCRUN_SDK clang -Wno-error=unused-command-line-argument-hard-error-in-future"
		# gas-preprocessor.pl作用就是将汇编代码转换成机器码，是编译过程中必须要的东西;有两种配置方式，手动指定或者自动在环境变量中查找
		# gas-preprocessor.pl下载地址：https://github.com/libav/gas-preprocessor/blob/master/gas-preprocessor.pl。可以下载后拷贝到目录extras下
		# 方法一：手动指定路径；方式如下，如果这里指定的路径不存在，将去环境变量指定的路径中查找该文件
		# 方法二：自动在环境变量中查找；只需要将gas-preprocessor.pl下载下来 拷贝到/usr/local/bin目录中然后 执行 chmod 777 /usr/local/bin/gas-preprocessor.pl
		AS="$CWD/$SOURCE_DIR/$FDK_AAC_TARGET/extras/gas-preprocessor.pl $CC"
		CXXFLAGS="$CFLAGS"
		LDFLAGS="$CFLAGS"

		$CWD/$SOURCE/configure \
	        $CONFIGURE_FLAGS \
	        $HOST \
	        $CPU \
	        CC="$CC" \
	        CXX="$CC" \
	        CPP="$CC -E" \
	        AS="$AS" \
	        CFLAGS="$CFLAGS" \
	        LDFLAGS="$LDFLAGS" \
	        CPPFLAGS="$CFLAGS" \
	        --prefix="$prefixdir"

		make -j3 install
		cd $CWD
	done
}

# 编译 mp3lame
function build_mp3lame()
{
	for ARCH in $ARCHS
    do
    	# 如果已经编译过 则不需重复编译
		prefixdir=$CWD/$BUILD_DIR/mp3lame-$ARCH
		if [[ -f $prefixdir/lib/libmp3lame.a ]]; then
			continue
		fi

        echo "building mp3lame $ARCH..."
        # 编译目录不存在 则创建
        if [[ ! -d  $BUILD_DIR/build_mp3lame_$ARCH ]]; then
        	mkdir -p $BUILD_DIR/build_mp3lame_$ARCH
        fi
		cd "$BUILD_DIR/build_mp3lame_$ARCH"

        if [ "$ARCH" = "i386" -o "$ARCH" = "x86_64" ]
        then
            PLATFORM="iPhoneSimulator"
            if [ "$ARCH" = "x86_64" ]
            then
                SIMULATOR="-mios-simulator-version-min=$target_ios"
                HOST=x86_64-apple-darwin
            else
                SIMULATOR="-mios-simulator-version-min=$target_ios"
                HOST=i386-apple-darwin
            fi
        else
            PLATFORM="iPhoneOS"
            SIMULATOR=
            HOST=arm-apple-darwin
        fi

        XCRUN_SDK=`echo $PLATFORM | tr '[:upper:]' '[:lower:]'`
        
        CC="xcrun -sdk $XCRUN_SDK clang -arch $ARCH"
        #AS="$CWD/$SOURCE/extras/gas-preprocessor.pl $CC"
        CFLAGS="-arch $ARCH $SIMULATOR -fembed-bitcode"
        CXXFLAGS="$CFLAGS"
        LDFLAGS="$CFLAGS"

        CC=$CC $CWD/$SOURCE/configure \
            CFLAGS="$CFLAGS" \
            LDFLAGS="$LDFLAGS" \
            $CONFIGURE_FLAGS \
            --host=$HOST \
            --prefix="$prefixdir" \

        make -j3 install
        cd $CWD
    done
}

# ======= 检查编译环境 ========= #
echo -e "check build env =======\n"
# 检查是否安装了 brew；如果没有安装，则进行安装
echo "check Homebrew env......"
if [[ ! `which brew` ]]; then
	echo 'Homebrew not found. Trying to install...'
	ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)" || exit 1
fi
echo -e "check Homebrew ok......\n"

# yasm是汇编器；先检查是否有汇编器
echo "check yasm env......"
if [[ ! `which yasm` ]]; then
	echo "yasm not found begin install....."
	brew install yasm || exit 1
fi
echo -e "check yasm ok......\n"

# gas-preprocessor.pl是汇编将汇编代码转换成目标平台机(ios)机器码的工具
echo "check gas-preprocessor.pl env......"
if [[ ! `which gas-preprocessor.pl` ]]; then
	echo "gas-preprocessor.pl not found begin install....."
	(curl -L $GAS_PREPROCESSOR_URL -o /usr/local/bin/gas-preprocessor.pl \
			&& chmod +x /usr/local/bin/gas-preprocessor.pl) \
			|| exit 1
fi
echo -e "check gas-preprocessor.pl ok......\n"
echo -e "check build env over ======="

# ==== 编译参数 平台相关的 编译优化相关的  ======= #
# Optimization options (experts only):
# FFMPEG_CFG_FLAGS="$FFMPEG_CFG_FLAGS --disable-armv5te"
# FFMPEG_CFG_FLAGS="$FFMPEG_CFG_FLAGS --disable-armv6"
# FFMPEG_CFG_FLAGS="$FFMPEG_CFG_FLAGS --disable-armv6t2"
# FFMPEG_CFG_FLAGS="$FFMPEG_CFG_FLAGS --disable-symver"

# 开发阶段可以开启，正式版关闭
FFMPEG_CFG_FLAGS="$FFMPEG_CFG_FLAGS --disable-stripping"
# --arch:CPU平台架构类型
# --target-os:目标系统->darwin(mac系统早起版本名字)
# --enable-static:编译静态库(.a)
# --disable-shared:不编译共享库(.so)
FFMPEG_CFG_FLAGS="$FFMPEG_CFG_FLAGS --arch=$FF_ARCH"
FFMPEG_CFG_FLAGS="$FFMPEG_CFG_FLAGS --target-os=darwin"
FFMPEG_EXTRA_CFLAGS=

# i386, x86_64
FFMPEG_CFG_FLAGS_SIMULATOR=
FFMPEG_CFG_FLAGS_SIMULATOR="$FFMPEG_CFG_FLAGS_SIMULATOR --disable-asm"
FFMPEG_CFG_FLAGS_SIMULATOR="$FFMPEG_CFG_FLAGS_SIMULATOR --disable-mmx"
FFMPEG_CFG_FLAGS_SIMULATOR="$FFMPEG_CFG_FLAGS_SIMULATOR --assert-level=2"

# armv7, armv7s, arm64
FFMPEG_CFG_FLAGS_ARM=
FFMPEG_CFG_FLAGS_ARM="$FFMPEG_CFG_FLAGS_ARM --enable-pic"
FFMPEG_CFG_FLAGS_ARM="$FFMPEG_CFG_FLAGS_ARM --enable-neon"

# 编译ffmpeg
function build_ffmpeg()
{
	CWD=`pwd`
	
	# ===== 三方库 ====== ####
	# 根据需求 获取x264 源码并且编译x264
	# 这里必须要--enable-encoder的方式开启libx264，libfdk_aac，libmp3lame;
	# libx264为gpl源码；fdk-aac为nonfree的
	# 否则外部库无法加载到ffmpeg中
	if [[ $X264_BUILD = "TRUE" ]]; then
		# 拉取源码
		pull_source_from_git $X264_URL x264 $X264_VERSION lasted
		# 编译
		build_x264
		# 配置对应 ffmpeg 参数
		FFMPEG_CFG_FLAGS="$FFMPEG_BUILD_ARGS --enable-gpl --enable-libx264"
		if [ -f "${FFMPEG_DEP_LIB}/lib$lib.a" ]; then
			    FFMPEG_CFG_FLAGS="$FFMPEG_CFG_FLAGS $ENABLE_FLAGS"

			    FFMPEG_CFLAGS="$FFMPEG_CFLAGS -I${FFMPEG_DEP_INC}"
			    FFMPEG_DEP_LIBS="$FFMPEG_DEP_LIBS -L${FFMPEG_DEP_LIB} $LD_FLAGS"
		fi
	fi
	# 获取fdk-aac源码
	if [[ $FDK_AAC_BUILD = "TRUE" ]]; then
		# 拉取源码
		pull_source_by_curl $FDK_AAC_URL $FDK_AAC_TARGET
		# 编译
		build_fdk_aac
		# 配置对应 ffmpeg 参数
		FFMPEG_CFG_FLAGS="$FFMPEG_BUILD_ARGS --enable-nonfree --enable-libfdk-aac"
	fi
	# 获取mp3lame源码
	if [[ $MP3LAME_BUILD = "TRUE" ]]; then
		# 拉取源码
		pull_source_by_curl $MP3LAME_URL $MP3LAME_TARGET
		# 编译
		build_mp3lame
		# 配置对应 ffmpeg 参数
		FFMPEG_CFG_FLAGS="$FFMPEG_BUILD_ARGS --enable-libmp3lame"
	fi
	# ===== 三方库 ====== ####

	# 获取ffmpeg 源码
	pull_source_from_git $FFMPEG_URL ffmpeg remotes/origin/release/$FFMPEG_VERSION $FFMPEG_VERSION

	# 编译目录不存在 则创建
    if [[ ! -d  $BUILD_DIR/build_ffmpeg_$1 ]]; then
    	mkdir -p $BUILD_DIR/build_ffmpeg_$1
    fi
	cd "$BUILD_DIR/build_ffmpeg_$1"

	FF_BUILD_NAME="unknown"
	FF_XCRUN_PLATFORM="iPhoneOS"
	FF_XCRUN_OSVERSION=
	FF_GASPP_EXPORT=
	FF_XCODE_BITCODE=

	if [ "$FF_ARCH" = "i386" ]; then
	    FF_BUILD_NAME="ffmpeg-i386"
	    FF_XCRUN_PLATFORM="iPhoneSimulator"
	    FF_XCRUN_OSVERSION="-mios-simulator-version-min=$TARGET_OS"
	    FFMPEG_CFG_FLAGS="$FFMPEG_CFG_FLAGS $FFMPEG_CFG_FLAGS_SIMULATOR"
	elif [ "$FF_ARCH" = "x86_64" ]; then
	    FF_BUILD_NAME="ffmpeg-x86_64"
	    FF_XCRUN_PLATFORM="iPhoneSimulator"
	    FF_XCRUN_OSVERSION="-mios-simulator-version-min=$TARGET_OS"
	    FFMPEG_CFG_FLAGS="$FFMPEG_CFG_FLAGS $FFMPEG_CFG_FLAGS_SIMULATOR"
	elif [ "$FF_ARCH" = "armv7" ]; then
	    FF_BUILD_NAME="ffmpeg-armv7"
	    FF_XCRUN_OSVERSION="-miphoneos-version-min=$TARGET_OS"
	    FF_XCODE_BITCODE="-fembed-bitcode"
	    FFMPEG_CFG_FLAGS="$FFMPEG_CFG_FLAGS $FFMPEG_CFG_FLAGS_ARM"
	#    FFMPEG_CFG_CPU="--cpu=cortex-a8"
	elif [ "$FF_ARCH" = "armv7s" ]; then
	    FF_BUILD_NAME="ffmpeg-armv7s"
	    FFMPEG_CFG_CPU="--cpu=swift"
	    FF_XCRUN_OSVERSION="-miphoneos-version-min=$TARGET_OS"
	    FF_XCODE_BITCODE="-fembed-bitcode"
	    FFMPEG_CFG_FLAGS="$FFMPEG_CFG_FLAGS $FFMPEG_CFG_FLAGS_ARM"
	elif [ "$FF_ARCH" = "arm64" ]; then
	    FF_BUILD_NAME="ffmpeg-arm64"
	    FF_XCRUN_OSVERSION="-miphoneos-version-min=$TARGET_OS"
	    FF_XCODE_BITCODE="-fembed-bitcode"
	    FFMPEG_CFG_FLAGS="$FFMPEG_CFG_FLAGS $FFMPEG_CFG_FLAGS_ARM"
	    FF_GASPP_EXPORT="GASPP_FIX_XCODE5=1"
	else
	    echo "unknown architecture $FF_ARCH";
	    exit 1
	fi

	echo "build_name: $FF_BUILD_NAME"
	echo "platform:   $FF_XCRUN_PLATFORM"
	echo "osversion:  $FF_XCRUN_OSVERSION"


	#--------------------
	#tr命令可以对来自标准输入的字符进行替换、压缩和删除
	#'[:upper:]'->将小写转成大写
	#'[:lower:]'->将大写转成小写
	#将platform->转成大写或者小写
	# xcrun -sdk $FF_XCRUN_SDK clang表示使用clang作为ffmpeg的编译器
	# xcrun 做的是定位到 clang，并执行它，附带输入 clang 后面的参数
	# -sdk 表示参数表示选择的平台是iPhoneSimulator还是iPhoneOS
	echo "--------------------"
	echo "[*] configurate ffmpeg"
	echo "--------------------"
	FF_XCRUN_SDK=`echo $FF_XCRUN_PLATFORM | tr '[:upper:]' '[:lower:]'`
	FF_XCRUN_CC="xcrun -sdk $FF_XCRUN_SDK clang"

	FFMPEG_CFG_FLAGS="$FFMPEG_CFG_FLAGS $FFMPEG_CFG_CPU"

	CC=$FF_XCRUN_CC $CWD/$SOURCE_DIR/x264/configure \
		$FFMPEG_CFG_FLAGS \
        --cc="$FF_XCRUN_CC" \
        $FFMPEG_CFG_CPU \
        --extra-cflags="$FFMPEG_CFLAGS" \
        --extra-cxxflags="$FFMPEG_CFLAGS" \
        --extra-ldflags="$FFMPEG_LDFLAGS $FFMPEG_DEP_LIBS"

        make clean

    # 导入 gas-process 到环境变量中
    make -j3 $FF_GASPP_EXPORT
	make install
	
}

# 开始编译
echo "===== begin build ffmpeg ======"
case $FF_ARCH in
	arm64|armv7|armv7s)
		echo "$1"
		# build_ffmpeg $FF_ARCH
	;;
	i386|x86_64)
		echo "$1"
		# build_ffmpeg $FF_ARCH
	;;
	all|*)
		for ARCH in $FF_ALL_ARCHS; do
			build_ffmpeg $ARCH
		done
	;;
esac
echo "===== end build ffmpeg ======"






