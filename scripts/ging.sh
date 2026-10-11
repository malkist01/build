#!/usr/bin/env bash

# Konfigurasikan 
git config --global user.name "user.build"
git config --global user.email "user@soulvibe.atlassian.net"

# Hapus folder kernel yang ada (jika ada)
if [ -d "kernel" ]; then
    echo "Menghapus folder kernel yang ada..."
    rm -rf kernel
fi

# Clone repositori kernel (jika belum ada)
if [ ! -d "kernel" ]; then
    echo "Mengkloning repositori kernel..."
    git clone --single-branch --depth=1 https://github.com/malkist01/android_kernel_xiaomi_sm6125 -b lineage-24.0 kernel
else
    echo "Folder kernel sudah ada, tidak perlu mengkloning ulang."
fi

cd kernel 

clang() {
    rm -rf clang
    echo "Cloning clang"
    if [ ! -d "clang" ]; then
        git clone -q https://gitlab.com/PixelOS-Devices/playgroundtc.git --depth=1 -b 17 clang
        KBUILD_COMPILER_STRING="Playground clang 17.0"
        export PATH="${PWD}/clang/bin:${PATH}"  # Add clang bin to PATH for current shell
    fi
    sudo apt install -y ccache
    echo "Done"
}

IMAGE=$(pwd)/out/arch/arm64/boot/Image.gz-dtb
IMAGE2=$(pwd)/out/arch/arm64/boot/dtbo.img
DATE=$(date +"%Y%m%d-%H%M")
START=$(date +"%s")
KERNEL_DIR=$(pwd)
CACHE=1
token=8691384652:AAHbKtOpbMp-Kc9JvKyil4aPsMfo5hdA-F8
chat_id=-5173179904
export token
export chat_id
RELEASE_VER=$(git rev-parse --abbrev-ref HEAD)
export RELEASE_VER
export CACHE
export KBUILD_COMPILER_STRING
ARCH=arm64
export ARCH
KBUILD_BUILD_HOST="soulvibe-atlassian"
export KBUILD_BUILD_HOST
KBUILD_BUILD_USER="user"
export KBUILD_BUILD_USER
DEVICE="Xiaomi Redmi Note 8"
export DEVICE
CODENAME="ginkgo"
export CODENAME
DEFCONFIG="vendor/trinket-perf_defconfig"
export DEFCONFIG
CONFIG="vendor/xiaomi-trinket.config"
export CONFIG
CONF="vendor/ginkgo.config"
export CONF
COMMIT_HASH=$(git rev-parse --short HEAD)
export COMMIT_HASH
PROCS=$(nproc --all)
export PROCS
STATUS=TEST
export STATUS
source "$HOME"/.bashrc && source "$HOME"/.profile
if [[ $CACHE -eq 1 ]]; then
    ccache -M 130G
    export USE_CCACHE=1
fi
LC_ALL=C
export LC_ALL

tg() { # Mengirim pesan teks ke Telegram
    curl -sX POST "https://api.telegram.org/bot${token}/sendMessage" \
        -d chat_id="${chat_id}" \
        -d parse_mode=Markdown \
        -d disable_web_page_preview=true \
        -d text="$1" &>/dev/null
}

tgs() { # Mengirim file ke Telegram
    MD5=$(md5sum "$1" | cut -d' ' -f1)
    curl -fsSL -X POST -F document=@"$1" "https://api.telegram.org/bot${token}/sendDocument" \
        -F "chat_id=${chat_id}" \
        -F "parse_mode=Markdown" \
        -F "caption=$2 | *MD5*: \`$MD5\`"
}

# Send Build Info
sendinfo() {
    NEOFETCH_OUTPUT=$(neofetch --stdout) 
    tg "
• *SOULVIBE BUILDER BOT* •

*Building on*: \`Soulvibe Server\`
*Date*: \`${DATE}\`
*Device*: \`${DEVICE} (${CODENAME})\`
*Branch*: \`$RELEASE_VER\`  
*Last Commit*: [${COMMIT_HASH}](https://github.com/malkist01/android_kernel_xiaomi_sm6125/commit/${COMMIT_HASH})
*Compiler*: \`${KBUILD_COMPILER_STRING}\`
*Build Status*: \`${STATUS}\`
*System Info*:
\`\`\`
${NEOFETCH_OUTPUT}
\`\`\`
"
}

# Push kernel to channel
push() {
    cd AnyKernel || exit 1
    ZIP=$(echo *.zip)
    tgs "${ZIP}" "Build took $((DIFF / 60)) minute(s) and $((DIFF % 60)) second(s). | For *${DEVICE} (${CODENAME})* | ${TIME}"
}

# Catch Error
finderr() {
    curl -s -X POST "https://api.telegram.org/bot$token/sendMessage" \
        -d chat_id="$chat_id" \
        -d "disable_web_page_preview=true" \
        -d "parse_mode=markdown" \
        -d sticker="CAACAgIAAxkBAAED3JViAplqY4fom_JEexpe31DcwVZ4ogAC1BAAAiHvsEs7bOVKQsl_OiME" \
        -d text="Build throw an error(s)"
    error_sticker
    exit 1
}

setup_kernelsu() {
    echo -e "Patching Kernel for KernelSU..."

    # Download and apply KernelSU setup script, capture errors
    curl -LSs "https://raw.githubusercontent.com/backslashxx/KernelSU/kernel/setup.sh" | bash -s master
    # Force enable CONFIG_KSU if it's not already set or is set to 'n'
    sed -i 's/# CONFIG_KSU_TAMPER_SYSCALL_TABLE is not set/CONFIG_KSU_TAMPER_SYSCALL_TABLE=y/' arch/${ARCH}/configs/${DEFCONFIG}
    sed -i 's/CONFIG_KSU=n/CONFIG_KSU=y/' arch/${ARCH}/configs/${DEFCONFIG}
}

# Compile
compile() {

    rm -rf out && mkdir -p out

    make O=out ARCH="${ARCH}" "$DEFCONFIG" "$CONFIG" "$CONF"
    make -j"${PROCS}" O=out \
        ARCH=arm64 \
        LLVM=1 \
        LLVM_IAS=1 \
        AR=llvm-ar \
        NM=llvm-nm \
        LD=ld.lld \
        OBJCOPY=llvm-objcopy \
        OBJDUMP=llvm-objdump \
        STRIP=llvm-strip \
        CC=clang \
        CROSS_COMPILE=aarch64-linux-gnu- \
        CROSS_COMPILE_ARM32=arm-linux-gnueabi 2> compile_error.log || {
            tg "Kernel compilation failed! Check compile_error.log"
            tgs "compile_error.log" "Kernel compilation error log" 
            exit 1 
        }
    if ! [ -a "$IMAGE" ]; then
        finderr
        exit 1
    fi

    git clone --depth=1 -b ginkgo https://github.com/malkist01/Anykernel3.git AnyKernel 
    cp out/arch/arm64/boot/Image.gz-dtb AnyKernel
    cp out/arch/arm64/boot/dtbo.img AnyKernel
    cp out/arch/arm64/boot/dtb.img AnyKernel
}

# Zipping
zipping() {
    cd AnyKernel || exit 1
    zip -r9 "ParadoX:[Hera!]-${RELEASE_VER}-${CODENAME}-${DATE}-KSU.zip" ./*
    cd ..
}

clang
sendinfo
setup_kernelsu
compile
zipping
END=$(date +"%s")
DIFF=$((END - START))
push
