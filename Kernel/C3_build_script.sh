#!/usr/bin/env bash

# Dependencies
deps() {
    echo "Cloning dependencies"
    
    if [ -d "AnyKernel" ];then
	rm -rf AnyKernel
	git clone --depth=1 https://github.com/sarthakroy2002/AnyKernel3.git AnyKernel
    fi
    
    if [ ! -d "clang" ];then
	if [ "${BRANCH}" = "R" ];then
	    git clone --depth=1 https://github.com/kdrag0n/proton-clang clang
	else
	    git clone --depth=1 https://github.com/sarthakroy2002/android_prebuilts_clang_host_linux-x86_clang-7612306 clang
    
	    if [ ! -d "los-4.9-64" ];then
		git clone --depth=1 https://github.com/sarthakroy2002/prebuilts_gcc_linux-x86_aarch64_aarch64-linaro-7 los-4.9-64
	    fi
	    
	    if [ ! -d "los-4.9-32" ];then
		git clone --depth=1 https://github.com/sarthakroy2002/linaro_arm-linux-gnueabihf-7.5 los-4.9-32
	    fi
	fi
    fi
    
    echo "Done"
}

IMAGE=$(pwd)/out/arch/arm64/boot/Image.gz-dtb
DATE=$(date +"%Y%m%d-%H%M")
START=$(date +"%s")
KERNEL_DIR=$(pwd)
CACHE=0
export CACHE
if [ "${BRANCH}" = "R" ];then
    PATH="${PWD}/clang/bin:${PATH}"
else
    PATH="${PWD}/clang/bin:${PATH}:${PWD}/los-4.9-32/bin:${PATH}:${PWD}/los-4.9-64/bin:${PATH}"
fi
KBUILD_COMPILER_STRING=$("${KERNEL_DIR}"/clang/bin/clang --version | head -n 1 | perl -pe 's/\(http.*?\)//gs' | sed -e 's/  */ /g')
export KBUILD_COMPILER_STRING
ARCH=arm64
export ARCH
KBUILD_BUILD_HOST=neolit
export KBUILD_BUILD_HOST
KBUILD_BUILD_USER="sarthakroy2002"
export KBUILD_BUILD_USER
REPO_URL="https://github.com/sarthakroy2002/kernel_realme_RMX2020"
export REPO_URL
DEVICE="Realme C3/Narzo 10A"
export DEVICE
CODENAME="RMX2020"
export CODENAME
COMMIT_HASH=$(git rev-parse --short HEAD)
export COMMIT_HASH
PROCS=$(nproc --all)
export PROCS
STATUS=BETA
export STATUS
source "${HOME}"/.bashrc && source "${HOME}"/.profile
if [ $CACHE = 1 ];then
    ccache -M 100G
    export USE_CCACHE=1
fi
LC_ALL=C
export LC_ALL

tg() {
    curl -sX POST https://api.telegram.org/bot"${token}"/sendMessage -d chat_id="${chat_id}" -d parse_mode=Markdown -d disable_web_page_preview=true -d text="$1" &>/dev/null
}

tgs() {
        MD5=$(md5sum "$1" | cut -d' ' -f1)
        curl -fsSL -X POST -F document=@"$1" https://api.telegram.org/bot"${token}"/sendDocument \
             -F "chat_id=${chat_id}" \
             -F "parse_mode=Markdown" \
             -F "caption=$2 | *MD5*: \`$MD5\`"
}

# sticker plox
sticker() {
    curl -s -X POST "https://api.telegram.org/bot$token/sendSticker" \
        -d sticker="CAACAgQAAxkBAAED3JFiApkFOuZg8zt0-WNrfEGwrvoRuAACAQoAAoEcoFINevKyLXEDhSME" \
        -d chat_id="${chat_id}"
}
# Send info plox channel
sendinfo() {
    tg "
• CI Build •
*Building on*: \`server\`
*Date*: \`${DATE}\`
*Device*: \`${DEVICE} (${CODENAME})\`
*Branch*: \`$(git rev-parse --abbrev-ref HEAD)\`
*Last Commit*: [${COMMIT_HASH}](${REPO_URL}/commit/${COMMIT_HASH})
*Compiler*: \`${KBUILD_COMPILER_STRING}\`
*Build Status*: \`${STATUS}\`"
}
# Push kernel to channel
push() {
    cd AnyKernel || exit 1
    ZIP=$(echo *.zip)
    tgs "${ZIP}" "Build took $(($DIFF / 60)) minute(s) and $(($DIFF % 60)) second(s). | For *${DEVICE} (${CODENAME})* | ${KBUILD_COMPILER_STRING}"
}
# Find Error
finderr() {
    curl -s -X POST "https://api.telegram.org/bot$token/sendMessage" \
        -d chat_id="$chat_id" \
        -d "disable_web_page_preview=true" \
        -d "parse_mode=markdown" \
	-d sticker="CAACAgIAAxkBAAED3JViAplqY4fom_JEexpe31DcwVZ4ogAC1BAAAiHvsEs7bOVKQsl_OiME" \
        -d text="Build throw an error(s)"
    exit 1
}
# Compile plox
compile() {

    if [ -d "out" ];then
	rm -rf out && mkdir -p out
    fi
    
make O=out ARCH="${ARCH}" "${DEFCONFIG}"

if [ "${BRANCH}" = "R" ]; then
	make -j"${PROCS}" O=out \
                      	ARCH=$ARCH \
                      	CC="clang" \
                      	CROSS_COMPILE=aarch64-linux-gnu- \
                      	CROSS_COMPILE_ARM32=arm-linux-gnueabi- \
                      	LD=ld.lld \
                      	AS=llvm-as \
		      	AR=llvm-ar \
		      	NM=llvm-nm \
		      	OBJCOPY=llvm-objcopy \
                   	CONFIG_NO_ERROR_ON_MISMATCH=y
else
	make -j"${PROCS}" O=out \
                      	ARCH=$ARCH \
                      	CC="clang" \
                      	CLANG_TRIPLE=aarch64-linux-gnu- \
                      	CROSS_COMPILE="${PWD}/los-4.9-64/bin/aarch64-linux-gnu-" \
                      	CROSS_COMPILE_ARM32="${PWD}/los-4.9-32/bin/arm-linux-gnueabihf-" \
                      	CONFIG_NO_ERROR_ON_MISMATCH=y
fi

    if ! [ -a "$IMAGE" ]; then
        finderr
        exit 1
    fi
    
    cp out/arch/${ARCH}/boot/${IMAGE} AnyKernel
}
# Zipping
zipping() {
    cd AnyKernel || exit 1
    zip -r9 NEOLIT-Test-OSS-"${BRANCH}"-KERNEL-"${CODENAME}"-"${DATE}".zip ./*
    curl -sL https://git.io/file-transfer | sh
    ./transfer wet NEOLIT-Test-OSS-"${BRANCH}"-KERNEL-"${CODENAME}"-"${DATE}".zip
    cd ..
}

deps
sendinfo
compile
zipping
END=$(date +"%s")
DIFF=$(($END - $START))
push
