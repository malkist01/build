#!/usr/bin/env bash

# Dependencies
rm -rf kernel
git clone $REPO -b $BRANCH kernel
cd kernel
LOCAL_DIR="$(pwd)/.."
TC_DIR="${LOCAL_DIR}/toolchain"
CLANG_DIR="${TC_DIR}/clang"
ARCH_DIR="${TC_DIR}/aarch64-linux-android-4.9"
ARM_DIR="${TC_DIR}/arm-linux-androideabi-4.9"
setup() {
  if ! [ -d "${CLANG_DIR}" ]; then
      echo "Clang not found! Downloading Google prebuilt..."
      mkdir -p "${CLANG_DIR}"
      wget -q https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/+archive/4d2864f08ff2c290563fb903a5156e0504620bbe/clang-r563880c.tar.gz -O clang.tar.gz
      if [ $? -ne 0 ]; then
          echo "Download failed! Aborting..."
          exit 1
      fi
        echo "Extracting clang to ${CLANG_DIR}..."
      tar -xf clang.tar.gz -C "${CLANG_DIR}"
    rm -f clang.tar.gz
  fi

  if ! [ -d "${ARCH_DIR}" ]; then
      echo "gcc not found! Cloning to ${ARCH_DIR}..."
      if ! git clone --depth=1 -b lineage-19.1 https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_aarch64_aarch64-linux-android-4.9.git ${ARCH_DIR}; then
          echo "Cloning failed! Aborting..."
          exit 1
      fi
  fi

  if ! [ -d "${ARM_DIR}" ]; then
      echo "gcc_32 not found! Cloning to ${ARM_DIR}..."
      if ! git clone --depth=1 -b lineage-19.1 https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_arm_arm-linux-androideabi-4.9.git ${ARM_DIR}; then
          echo "Cloning failed! Aborting..."
          exit 1
      fi
  fi

  if [[ $1 = "-k" || $1 = "--ksu" ]]; then
      echo -e "\nCleanup KernelSU first on local build\n"
      rm -rf KernelSU drivers/kernelsu

      echo -e "\nKSU Support, let's Make it On\n"
      curl -kLSs "https://raw.githubusercontent.com/KazuyaProject/KernelSU-Next/next-susfs/kernel/setup.sh" | bash -s next-susfs

      sed -i 's/CONFIG_KSU=n/CONFIG_KSU=y/g' arch/arm64/configs/ginkgo_defconfig
  else
      echo -e "\nKSU not Support, let's Skip\n"
  fi
}
IMAGE=$(pwd)/out/arch/arm64/boot/Image.gz-dtb
DTB=$(pwd)/out/arch/arm64/boot/dtbo.img
DATE=$(date +"%Y%m%d-%H%M")
START=$(date +"%s")
KERNEL_DIR=$(pwd)
CACHE=1
export CACHE
export KBUILD_COMPILER_STRING
ARCH=arm64
export ARCH
export DEFCONFIG="vendor/trinket-perf_defconfig"
export ARCH="arm64"
export PATH="$CLANG_DIR/bin:$ARCH_DIR/bin:$ARM_DIR/bin:$PATH"
export LD_LIBRARY_PATH="$CLANG_DIR/lib:$LD_LIBRARY_PATH"
export KBUILD_BUILD_VERSION="1"
DEVICE="Redmi Note 8"
export DEVICE
CODENAME="ginkgo"
export CODENAME
KVERS="TinkyWinky"
export KVERS
AVERS="(10)"
export AVERS
COMMIT_HASH=$(git log --oneline --pretty=tformat:"%h  %s  [%an]" --abbrev-commit --abbrev=1 -1)
export COMMIT_HASH
PROCS=$(nproc --all)
export PROCS
STATUS=STABLE
export STATUS
source "${HOME}"/.bashrc && source "${HOME}"/.profile
if [ $CACHE = 1 ]; then
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

# Send Build Info
sendinfo() {
    tg "
• IMcompiler Action •
*Building on*: \`Github actions\`
*Date*: \`${DATE}\`
*Device*: \`${DEVICE} (${CODENAME})\`
*Branch*: \`$(git rev-parse --abbrev-ref HEAD)\`
*Compiler*: \`${KBUILD_COMPILER_STRING}\`
*Last Commit*: \`${COMMIT_HASH}\`
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
    curl -s -X POST "https://api.telegram.org/bot$token/sendMessage" \
        -d chat_id="$chat_id" \
        -d "disable_web_page_preview=true" \
        -d "parse_mode=markdown" \
        -d sticker="CAACAgIAAxkBAAED3JViAplqY4fom_JEexpe31DcwVZ4ogAC1BAAAiHvsEs7bOVKQsl_OiME" \
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
       ARCH="arm64" \
       CC="clang" \
       LD="ld.lld" \
       AR="llvm-ar" \
       AS="llvm-as" \
       NM="llvm-nm" \
       OBJCOPY="llvm-objcopy" \
       OBJDUMP="llvm-objdump" \
       STRIP="llvm-strip" \
       CLANG_TRIPLE="aarch64-linux-gnu-" \
       CROSS_COMPILE="$ARCH_DIR/bin/aarch64-linux-android-" \
       CROSS_COMPILE_ARM32="$ARM_DIR/bin/arm-linux-androideabi-" \
       Image.gz-dtb \
       dtbo.img \
       CC="${CCACHE} clang" \

    if ! [ -f "${IMAGE}" && -f "${DTBO}"]; then
        finderr
        exit 1
    fi

    git clone --depth=1 https://github.com/malkist01/AnyKernel2.git AnyKernel -b main
    cp out/arch/arm64/boot/Image.gz-dtb AnyKernel
    cp out/arch/arm64/boot/dtbo.img AnyKernel    
}
# Zipping
zipping() {
    cd AnyKernel || exit 1
    zip -r9 Teletubies-"${CODENAME}"-"${DATE}".zip ./*
    cd ..
}

setup
sendinfo
compile
zipping
END=$(date +"%s")
DIFF=$((END - START))
push
