###################################################################
# File Name: test.sh
# Author: 徐丽雅
# mail: xuliya@wingtech.com
# Created Time: 2017年09月29日 星期五 22时51分33秒
#=============================================================
#!/bin/bash

#参数初始化
repo_url=$1
new_branch=$2

#解析IP、-b、-m参数
IP=${repo_url#*//}
IP=${IP%%:*}
b=${repo_url#*-b }
b=${b%% -*}
m=${repo_url#*-m }

#若IP是镜像IP
if [ "$IP" = "192.168.6.174" ];then
    IP="192.168.30.13"
fi

#初始化.repo目录，得到.repo/manifest.xml
$repo_url
if [ "$?" != "0" ];then
    echo "初始化失败！"
    exit 1
fi

#获取默认分支名
default=`grep "default revision" .repo/manifest.xml`
default=${default#*revision=\"}
default=${default%%\"*}

获取默认分支上库的revision值
revisionList=`ssh -p 29418 $IP gerrit ls-projects -b ${default}|cut -d ' ' -f 1,2 --output-delimiter='('|sed 's#$#)#g'`

#遍历manifest,在各个库上建立新分支
while read line
do
    if [ "`echo $line|grep "<project"`" != "" ];then
        name=${line#*name=\"}
        name=${name%%\"*}
        if [ "`echo $line|grep revision`" = "" ];then
            #获取该库原分支的revision值
            revision=`echo "$revisionList"|grep "("${name}")"`
            #将库的HEAD指向原分支
            #ssh -p 29418 -n $IP gerrit set-head $name --new-head $default
            #建立新分支
            ssh -p 29418 -n $IP gerrit create-branch $name $new_branch ${revision%%(*}
            #将库的HEAD重新指向master
            #ssh -p 29418 -n $IP gerrit set-head $name --new-head master
        fi
    fi
done < .repo/manifest.xml

#修改manifest,主要是修改default revison="new_branch"
cd .repo/manifests
cp $m $new_branch.xml
sed -i "s#default revision=\"${default}\"#default revision=\"${new_branch}\"#" $new_branch.xml

#验证是否成功创建分支
cd ../../
repo init -m $new_branch.xml
repo sync -c
if [ "$?" != "0" ];then
    echo "创建分支失败！"
    exit 1
fi

#提交manifest
cd .repo/manifests
git status
git add $new_branch.xml
git commit -m "基于${default}分支建立${new_branch}分支"
git remote add ssh-m ssh://${IP}:29418/manifest.git
git push ssh-m HEAD:refs/for/$b
