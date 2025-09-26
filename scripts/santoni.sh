#!/usr/bin/env bash
# Dependencies
rm -rf kernel
git clone $REPO -b $BRANCH kernel
cd kernel

git clone --depth=1 https://github.com/malkist01/patch
curl -LSs "https://raw.githubusercontent.com/malkist01/patch/main/add/patch.sh" | bash -s main

# Add SukiSU-Ultra
curl -LSs "https://raw.githubusercontent.com/WildKernels/Wild_KSU/wild/kernel/setup.sh" | bash -s wild

#add KSU Config
echo "CONFIG_KPROBES=y" >> ./arch/arm64/configs/santoni_defconfig
echo "CONFIG_LOCAL_VERSION=-Teletubies 🕊️" >> ./arch/arm64/configs/santoni_defconfig
echo "# CONFIG_LOCAL_VERSION_AUTO is not set" >> ./arch/arm64/configs/santoni_defconfig
echo "CONFIG_LINUX_COMPILE_BY=malkist" >> ./arch/arm64/configs/santoni_defconfig
echo "CONFIG_LINUX_COMPILE_HOST=hp jadul" >> ./arch/arm64/configs/santoni_defconfig
echo "CONFIG_CC_STACKPROTECTOR_STRONG=n" >> ./arch/arm64/configs/santoni_defconfig
echo "Adding CONFIG_KSU.."
echo "CONFIG_OVERLAY_FS=y" >> ./arch/arm64/configs/santoni_defconfig
echo "CONFIG_KSU=y" >> ./arch/arm64/configs/santoni_defconfig
echo "CONFIG_KSU_SUSFS=y" >> ./arch/arm64/configs/santoni_defconfig
echo "CONFIG_KSU_TRACEPOINT_HOOK=y" >> ./arch/arm64/configs/santoni_defconfig
clang() {
    echo "Cloning clang"
    if [ ! -d "clang" ]; then
      mkdir -p "clang"
      curl -Lo WeebX-Clang-20.0.0git.tar.gz "https://github.com/XSans0/WeebX-Clang/releases/download/WeebX-Clang-20.0.0git-release/WeebX-Clang-20.0.0git.tar.gz"
      tar -zxf WeebX-Clang-20.0.0git.tar.gz -C "clang" --strip-components=1
        KBUILD_COMPILER_STRING="WeebX-Clang"
        PATH="${PWD}/clang/bin:${PATH}"
    fi
    sudo apt install -y ccache
    echo "Done"
}

IMAGE=$(pwd)/out/arch/arm64/boot/Image.gz-dtb
DATE=$(date +"%Y%m%d-%H%M")
START=$(date +"%s")
KERNEL_DIR=$(pwd)
#Ccache
export USE_CCACHE=1
export CCACHE_COMPILER_CHECK="%compiler% -dumpversion"
export CCACHE_MAXFILES="0"
export CCACHE_NOHASHDIR="true"
export CCACHE_UMASK="0002"
export CCACHE_COMPRESSION="true"
export CCACHE_COMPRESSION_LEVEL="-3"
export CCACHE_NOINODECACHE="true"
export CCACHE_COMPILERTYPE="auto"
export CCACHE_RUN_SECOND_CPP="true"
export CCACHE_SLOPPINESS="file_macro,time_macros,include_file_mtime,include_file_ctime,file_stat_matches"
export TZ=Asia/Jakarta
export KBUILD_COMPILER_STRING
ARCH=arm64
export ARCH
KBUILD_BUILD_HOST="android"
export KBUILD_BUILD_HOST
KBUILD_BUILD_USER="malkist"
export KBUILD_BUILD_USER
DEVICE="Xiaomi Redmi 4X"
export DEVICE
CODENAME="santoni"
export CODENAME
DEFCONFIG="santoni_defconfig"
export DEFCONFIG
COMMIT_HASH=$(git rev-parse --short HEAD)
export COMMIT_HASH
PROCS=$(nproc --all)
export PROCS
STATUS=STABLE
export STATUS
BOT_TOKEN="7596553794:AAGoeg4VypmUfBqfUML5VWt5mjivN5-3ah8"
CHAT_ID="-1002287610863"
source "${HOME}"/.bashrc && source "${HOME}"/.profile
if [ $CACHE = 1 ]; then
    ccache -M 100G
    export USE_CCACHE=1
fi
LC_ALL=C
export LC_ALL

tg() {
    curl -sX POST https://api.telegram.org/bot"${BOT_TOKEN}"/sendMessage -d chat_id="${CHAT_ID}" -d parse_mode=Markdown -d disable_web_page_preview=true -d text="$1" &>/dev/null
}

tgs() {
    MD5=$(md5sum "$1" | cut -d' ' -f1)
    curl -fsSL -X POST -F document=@"$1" https://api.telegram.org/bot"${BOT_TOKEN}"/sendDocument \
        -F "chat_id=${CHAT_ID}" \
        -F "parse_mode=Markdown" \
        -F "caption=$2 | *MD5*: \`$MD5\`"
}

# Send Build Info
sendinfo() {
    tg "
• Compiler Action •
*Building on*: \`Github actions\`
*Date*: \`${DATE}\`
*Device*: \`${DEVICE} (${CODENAME})\`
*Branch*: \`$(git rev-parse --abbrev-ref HEAD)\`
*Last Commit*: [${COMMIT_HASH}](${REPO}/commit/${COMMIT_HASH})
*Compiler*: \`${KBUILD_COMPILER_STRING}\`
*Build Status*: \`${STATUS}\`"
}

# Push kernel to channel
push() {
    cd AnyKernel || exit 1
    ZIP=$(echo *.zip)
    tgs "${ZIP}" "Build took $((DIFF / 60)) minute(s) and $((DIFF % 60)) second(s). | For *${DEVICE} (${CODENAME})* | ${KBUILD_COMPILER_STRING}"
}

# Catch Error
finderr() {
    curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" \
        -d chat_id="$CHAT_ID" \
        -d "disable_web_page_preview=true" \
        -d "parse_mode=markdown" \
        -d sticker="CAADBQADZwADqZrmFoa87YicX2hwAg" \
        -d text="Build throw an error(s)"
    error_sticker
    exit 1
}

# Compile
compile() {

    if [ -d "out" ]; then
        rm -rf out && mkdir -p out
    fi

    make O=out ARCH="${ARCH}" "${DEFCONFIG}"
    make -j"${PROCS}" O=out \
         ARCH=$ARCH \
         CC="clang" \
         CXX="clang++" \
         HOSTCC="clang" \
         HOSTCXX="clang++" \
         AR=llvm-ar \
         AS=llvm-as \
         NM=llvm-nm \
         OBJCOPY=llvm-objcopy \
         OBJDUMP=llvm-objdump \
         STRIP=llvm-strip \
         LLVM=1 \
        CROSS_COMPILE=aarch64-linux-gnu- \
        CROSS_COMPILE_ARM32=arm-linux-gnueabi-

    if ! [ -a "$IMAGE" ]; then
        finderr
        exit 1
    fi

    git clone --depth=1 https://github.com/malkist01/anykernel3.git AnyKernel -b master
    cp out/arch/arm64/boot/Image.gz-dtb AnyKernel
}
# Zipping
zipping() {
    cd AnyKernel || exit 1
    zip -r9 Teletubies-"${BRANCH}"-"${CODENAME}"-"${DATE}".zip ./*
    cd ..
}

clang
sendinfo
compile
zipping
END=$(date +"%s")
DIFF=$((END - START))
push
