#!/bin/bash
#Author : zahi0 @ github
#Date : 20220113
#Description : 内核编译脚本，这个脚本可以在github action和自己的pc都可以使用
clang_path="${PWD}/proton-clang/bin"
gcc_path="${clang_path}/aarch64-linux-gnu-"
gcc_32_path="${clang_path}/arm-linux-gnueabi-"
date="`date +"%Y%m%d%H%M"`"
args="-j$(nproc --all) O=out ARCH=arm64 SUBARCH=arm64 "

print (){
case ${2} in
	"red")
	echo -e "\033[31m $1 \033[0m";;
	"blue")
	echo -e "\033[34m $1 \033[0m";;
	"yellow")
	echo -e "\033[33m $1 \033[0m";;
	"purple")
	echo -e "\033[35m $1 \033[0m";;
	"sky")
	echo -e "\033[36m $1 \033[0m";;
	"green")
	echo -e "\033[32m $1 \033[0m";;
	*)
	echo $1
	;;
	esac
}
clean(){
	rm -rf out
	mkdir out
	make mrproper
	make $args mrproper
}
build_kernel(){
	export KBUILD_BUILD_USER="hushunz"
	export KBUILD_BUILD_HOST="github-actions"

	# ====== 关键：使用 vendor/cezanne_user_defconfig ======
	# MT6885 = cezanne (Redmi Note 10 Pro / xaga)
	# 原来的 k6889v1_64_defconfig 在源码中不存在
	make $args vendor/cezanne_user_defconfig
	if [ $? -ne 0 ]; then
		print "defconfig 加载失败!" red
		exit 1
	fi

	echo
	echo
	make $args
	if [ $? -ne 0 ]; then
		echo
		echo "====================================="
		print "************编译失败!***************" red
		echo "====================================="
		exit 1
	else
		echo
		echo "====================================="
		print "************编译成功!***************" green
		echo "====================================="
	fi
	echo
}

echo
echo "====================================="
print "****开始编译内核***** version:$date" yellow
echo "====================================="

# ====== 编译参数 ======
# -no-integrated-as: 禁用 clang 集成汇编器（clang14 的 IAS 会破坏 4.14 汇编代码）
# 配合 as-wrapper 脚本，将 -EL 路由到 aarch64-linux-gnu-as
# KCFLAGS/KAFLAGS: 确保所有编译/汇编都使用外部 GNU as
args+="CC=${clang_path}/clang \
CLANG_TRIPLE=aarch64-linux-gnu- \
HOSTCC=${clang_path}/clang \
HOSTCXX=${clang_path}/clang++ \
LLVM_AR=${clang_path}/llvm-ar \
LLVM_NM=${clang_path}/llvm-nm \
OBJCOPY=${clang_path}/llvm-objcopy \
OBJDUMP=${clang_path}/llvm-objdump \
STRIP=${clang_path}/llvm-strip \
CROSS_COMPILE=$gcc_path \
LD=${clang_path}/ld.lld \
CROSS_COMPILE_ARM32=$gcc_32_path"

# 确保 clang 不使用集成汇编器，而是调用外部 as（被 as-wrapper 路由到 GNU as）
export KCFLAGS="-no-integrated-as"
export KAFLAGS="-no-integrated-as"

cd kernel_src
clean
build_kernel

# ====== 拷贝产物 ======
cp ./out/arch/arm64/boot/Image.gz Image.gz 2>/dev/null || echo "警告: Image.gz 未找到"
cp ./out/arch/arm64/boot/Image Image 2>/dev/null || true
# dtb/dtbo 可能在不同路径，尝试拷贝
find ./out/arch/arm64/boot -name "*.dtb" -exec cp {} dtb \; 2>/dev/null || true
find ./out/arch/arm64/boot -name "dtbo.img" -exec cp {} dtbo.img \; 2>/dev/null || true

cd ..
echo
print "产物已拷贝到 kernel_src/ 目录" sky
ls -la kernel_src/Image* kernel_src/dtb* 2>/dev/null || true
