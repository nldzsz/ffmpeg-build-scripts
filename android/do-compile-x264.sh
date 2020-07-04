#!/bin/bash

CONFIGURE_FLAGS="--enable-pic --disable-cli --enable-strip "

# 源码目录;与编译脚本同级目录，编译的中间产物.o,.d也会在这里
SOURCE=
# 编译最终的输出目录；必须为绝对路径，否则生成的库不会到这里去
OUT=$WORK_PATH/"android/build"
# 接受参数 作为编译平台
ARCH=$1
# 编译的API要求
target_API=$2

echo ""
echo "building x264 $ARCH..."
echo ""

# 创建独立工具链
# 通过此种方式执行sh 文件中的export变量才有效。如果换成sh ./do-envbase-tool.sh $ARCH 则不行
. ./android/do-envbase-tool.sh $ARCH


SOURCE="android/forksource/x264-$ARCH"
cd $SOURCE

# 默认为编译动态库
shared_enable="--enable-shared"
static_enable="--disable-static"
# 默认生成动态库时会带版本号，这里通过匹配去掉了版本号
if [ $FF_COMPILE_SHARED == "TRUE" ];then
UNAME_S=$(uname -s)
case "$UNAME_S" in
    Darwin)
        sed -i "" "s/echo \"SONAME=libx264.so.\$API\" >> config.mak/echo \"SONAME=libx264.so\" >> config.mak/g" configure
        sed -i "" "s/ln -f -s \$(SONAME) \$(DESTDIR)\$(libdir)\/libx264.\$(SOSUFFIX)//g" Makefile
    ;;
    Darwin)
        sed -i "s/echo \"SONAME=libx264.so.\$API\" >> config.mak/echo \"SONAME=libx264.so\" >> config.mak/g" configure
        sed -i "s/ln -f -s \$(SONAME) \$(DESTDIR)\$(libdir)\/libx264.\$(SOSUFFIX)//g" Makefile
    ;;
    CYGWIN_NT-*)
        sed -i "s/echo \"SONAME=libx264.so.\$API\" >> config.mak/echo \"SONAME=libx264.so\" >> config.mak/g" configure
        sed -i "s/ln -f -s \$(SONAME) \$(DESTDIR)\$(libdir)\/libx264.\$(SOSUFFIX)//g" Makefile
    ;;
esac
else
shared_enable="--disable-shared"
fi
if [ $FF_COMPILE_STATIC == "TRUE" ];then
static_enable="--enable-static"
fi
CONFIGURE_FLAGS="$CONFIGURE_FLAGS $shared_enable $static_enable"

HOST=""
PREFIX=$OUT/x264-$ARCH
if [ "$ARCH" = "x86_64" ]; then
    HOST="x86_64-linux"
elif [ "$ARCH" = "armv7a" ]; then
    HOST="arm-linux"
elif [ "$ARCH" = "arm64" ]; then
    HOST="aarch64-linux"
else
    HOST="arm-linux"
fi

echo "begin build x264 $ARCH..."
echo ""
echo "CONFIGURE_FLAGS:$CONFIGURE_FLAGS"
echo "sysroot:$FF_SYSROOT"
echo "cross-prefix:$FF_CROSS_PREFIX"
echo "prefix:$PREFIX"
echo "host:$HOST"
echo ""

# 取消外部的干扰
unset CFLAGS
unset CPPFLAGS
unset LDFLAGS

# 效果和./configre .... 一样
./configure \
  ${CONFIGURE_FLAGS} \
  --prefix=$PREFIX \
  --host=$HOST \
  --cross-prefix=$FF_CROSS_PREFIX- \
  --extra-cflags="-D__ANDROID_API__=$FF_ANDROID_API" \
  --sysroot=$FF_SYSROOT || exit 1
make $FF_MAKE_FLAGS install
cd -
