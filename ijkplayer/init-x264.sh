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

IJK_UPSTREAM=https://git.videolan.org/git/x264.git
IJK_LOCAL_REPO=extra/x264
IJK_FFMPEG_COMMIT=remotes/origin/stable

set -e
TOOLS=tools
PLATPORM=$1
PLATPORM_build_dir=ios
if [ $1 == "android" ]; then
PLATPORM_build_dir=android/contrib
fi
case $PLATPORM in
    "android"|"ios")
        echo "platmform is $PLATPORM"
    ;;
    *)
        echo "invalid platform, must be ios or android"
        exit 1
    ;;
esac

echo "== pull x264 base =="
# 始终拉取远程最新的
sh $TOOLS/pull-repo-base.sh $IJK_UPSTREAM $IJK_LOCAL_REPO

function pull_fork()
{
    echo "== pull x264 fork $1 =="
# pull-repo-ref.sh 是对git clone --referrence的封装。加快clone速度，如果本地IJK_LOCAL_REPO中有，则从本地直接copy，否则从远程IJK_UPSTREAM拉取
    sh $TOOLS/pull-repo-ref.sh $IJK_UPSTREAM $PLATPORM_build_dir/x264-$1 ${IJK_LOCAL_REPO}
    cd $PLATPORM_build_dir/x264-$1
    git checkout -b stable ${IJK_FFMPEG_COMMIT}
    cd -
}

pull_fork x86_64
pull_fork arm64
