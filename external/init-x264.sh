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

X264_UPSTREAM=https://git.videolan.org/git/x264.git
X264_LOCAL_REPO=extra/x264
X264_VERSION=stable
X264_COMMIT=remotes/origin/$X264_VERSION

set -e
TOOLS=tools

# $1 编译平台 $2 平台对应的cpu架构类型集合 $3源码fork到本地的路径
PLATPORM=$1
ARCHS=$2
FORK_SOURCE=$3

echo "== pull x264 base =="
# 始终拉取远程最新的
sh $TOOLS/pull-repo-base.sh $X264_UPSTREAM $X264_LOCAL_REPO

# 获取git库的当前分支名
function obtain_git_branch {
  br=`git branch | grep "*"`
  echo ${br/* /}
}

function pull_fork()
{
    echo "== pull x264 fork $1 =="
# pull-repo-ref.sh 是对git clone --referrence的封装。加快clone速度，如果本地IJK_LOCAL_REPO中有，则从本地直接copy，否则从远程IJK_UPSTREAM拉取
#    sh $TOOLS/pull-repo-ref.sh $IJK_UPSTREAM $PLATPORM_build_dir/x264-$1 ${IJK_LOCAL_REPO}
    # 这里直接copy 过去
    if [ -d $FORK_SOURCE/x264-$1 ]; then
        rm -rf $FORK_SOURCE/x264-$1
    fi
    cp -rf $X264_LOCAL_REPO $FORK_SOURCE/x264-$1
    
    # 切换到指定的分支
    result=`obtain_git_branch`
    if [[ $result != $X264_VERSION ]]; then
        cd $FORK_SOURCE/x264-$1
        # 避免再次切换分支会出现 fatal: A branch named xxx already exists 错误；不用管
        git checkout -b $X264_VERSION ${X264_COMMIT}
        cd -
    fi
}

for ARCH in $ARCHS; do
    pull_fork $ARCH
done

