###################################################################
# File Name: create_GitProject.sh
# Author: 徐丽雅
# mail: xuliya@wingtech.com
# Created Time: 2017年09月30日 星期六 15时22分07秒
#=============================================================
#!/bin/bash

#参数初始化
repo_url=$1
project_list=$2
specified=$3
codetype=$4

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


#遍历list、建库和分支
fixed_name=""
for name in $list
do
    #处理project_name
    name=${name#platform/}
    name=${name#android/}
    name=${name#qcom_amss/}
    name=${name#amss/}
    if [ "$codetype" = "android" ];then
        name="platform/${name}"
    else
        name="qcom_amss/${name}"
    fi
    fixed_name=${fixed_name}${name}" "
    #建库和master分支(库可能存在)
    ssh -p 29418 -n $IP gerrit create-project --empty-commit $name
    #建项目分支
    if [ "$specified" != "" ];then
        ssh -p 29418 -n $IP gerrit set-head $name --new-head $specified
        ssh -p 29418 -n $IP gerrit create-branch $name $default HEAD
        ssh -p 29418 -n $IP gerrit set-head $name --new-head master
    else
        #确保HEAD指向master
        ssh -p 29418 -n $IP gerrit set-head $name --new-head master
        ssh -p 29418 -n $IP gerrit create-branch $name $default HEAD
    fi
    #若是在30.13上建库还需创建mirror分支(mirror分支可能存在)
    if [ "$IP" = "192.168.30.13" ];then
        ssh -p 29418 -n $IP gerrit create-branch $name mirror HEAD
    fi
done

#修改manifest
cd .repo/manifests
sed -i '/<\/manifest>/d' $m
sed -i '/^$/d' $m
for name in $fixed_name
do
    #处理project_name和project_path
    if [ "$codetype" = "android" ];then
        path="android/${name#platform/}"
    else
        path="amss/${name#qcom_amss/}"
    fi
    echo "<project name=\"$name\" path=\"${path}\" />" >> $m
done
echo "</manifest>" >> $m

#验证是否成功建库
cd ../../
result=true
for name in $fixed_name
do
    repo sync -c $name
    if [ "$?" != "0" ];then
        result=false
    fi
done
if [ "$result" != "true" ];then
    echo "建库失败！"
    exit 1
fi

#提交manifest
cd .repo/manifests
git status
git add $m
git commit -m "在${m}上增加库：${fixed_name}"
git remote add ssh-m ssh://${IP}:29418/manifest.git
git push ssh-m HEAD:refs/for/$b                                                                                   

