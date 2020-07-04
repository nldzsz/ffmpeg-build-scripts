::python解释器的路径
set pythonpath=%1
::ndk的路径
set ndkpath=%2
::cpu平台
set arch=%3
::ndk的api版本
set api=%4
::独立工具链的安装路径
set install_path=%5
::执行独立编译工具
%pythonpath% %ndkpath%/build/tools/make_standalone_toolchain.py --arch %arch% --api %api% --install-dir %install_path%