#!/usr/bin/env bash
#
rm -rf kernel
git clone $REPO -b $BRANCH kernel 
cd kernel
SECONDS=0
ZIPNAME="Neophyte-Apollo-Q-Ginkgo-$(TZ=Asia/Jakarta date +"%Y%m%d-%H%M").zip"
TC_DIR="$(pwd)/../tc/"
CLANG_DIR="${TC_DIR}clang"
GCC_64_DIR="${TC_DIR}aarch64-linux-android-4.9"
GCC_32_DIR="${TC_DIR}arm-linux-androideabi-4.9"
AK3_DIR="$HOME/AnyKernel3"
DEFCONFIG="vendor/ginkgo_defconfig"
ARCH=arm64
export ARCH
export DEFCONFIG="vendor/ginkgo_defconfig"
export ARCH="arm64"
IMAGE=$(pwd)/out/arch/arm64/boot/Image.gz-dtb
DTBO=$(pwd)/out/arch/arm64/boot/dtbo.img

# ===== Set timezone =====
sudo timedatectl set-timezone Asia/Jakarta

# ===== TELEGRAM CONFIG =====
BOT_TOKEN="7596553794:AAGoeg4VypmUfBqfUML5VWt5mjivN5-3ah8"
CHAT_ID="-1002287610863"
API_URL="https://api.telegram.org/bot${BOT_TOKEN}"

tg_msg() {
curl -s -X POST "${API_URL}/sendMessage" \
-d chat_id="${CHAT_ID}" \
-d text="$1" \
-d parse_mode=HTML > /dev/null
}

tg_file() {
curl -s -X POST "${API_URL}/sendDocument" \
-F chat_id="${CHAT_ID}" \
-F document=@"$1" \
-F caption="$2" > /dev/null
}

# ===== ENV =====
export PATH="$CLANG_DIR/bin:$PATH"
export LD_LIBRARY_PATH="$CLANG_DIR/lib:$LD_LIBRARY_PATH"
export KBUILD_BUILD_VERSION="1"
export LOCALVERSION

# ===== START NOTIF =====
tg_msg "🚀 <b>Kernel Build Started</b>
Device: <b>Redmi Note 8 (Ginkgo)</b>
Time: <code>$(date)</code>"

# ===== CLANG =====
if ! [ -d "${CLANG_DIR}" ]; then
tg_msg "⚙️ Cloning Clang..."
git clone --depth=1 https://gitlab.com/nekoprjkt/aosp-clang ${CLANG_DIR} || {
tg_msg "❌ <b>Failed cloning Clang</b>"
}
fi

# ===== GCC 64 =====
if ! [ -d "${GCC_64_DIR}" ]; then
tg_msg "⚙️ Cloning GCC 64..."
git git clone --depth=1 -b main https://github.com/greenforce-project/gcc-arm64 \
${GCC_64_DIR} || {
tg_msg "❌ <b>Failed cloning GCC 64</b>"
}
fi

# ===== GCC 32 =====
if ! [ -d "${GCC_32_DIR}" ]; then
tg_msg "⚙️ Cloning GCC 32..."
git clone --depth=1 -b main https://github.com/greenforce-project/gcc-arm \
${GCC_32_DIR} || {
tg_msg "❌ <b>Failed cloning GCC 32</b>"
}
fi

mkdir -p out
make O=out ARCH=arm64 $DEFCONFIG

# ===== BUILD =====
tg_msg "🔨 <b>Compilation Started</b>"
make O=out ARCH="${ARCH}" "${DEFCONFIG}"
make -j"${PROCS}" O=out \
ARCH=arm64 \
CC=clang \
LD=ld.lld \
AR=llvm-ar \
AS=llvm-as \
NM=llvm-nm \
OBJCOPY=llvm-objcopy \
OBJDUMP=llvm-objdump \
STRIP=llvm-strip \
CLANG_TRIPLE="aarch64-linux-gnu-" \
CROSS_COMPILE="$GCC_64_DIR/bin/aarch64-linux-android-" \
CROSS_COMPILE_ARM32="$GCC_32_DIR/bin/arm-linux-gnueabi-" \
Image.gz-dtb \
dtbo.img 2>&1 | tee log.txt

# ===== CHECK RESULT =====
if ! [ -f "${IMAGE}" && -f "${DTBO}" && -f "${DTB}"]; then
        finderr
        exit 1
fi
tg_msg "✅ <b>Build Success</b>
Zipping kernel..."

if [ -d "$AK3_DIR" ]; then
cp -r $AK3_DIR AnyKernel3
else
git clone -q https://github.com/neophyteprjkt/AnyKernel3 || {
tg_msg "❌ Failed cloning AnyKernel3"
}
fi

cp out/arch/arm64/boot/Image.gz-dtb AnyKernel3
cp out/arch/arm64/boot/dtbo.img AnyKernel3

rm -rf *zip
cd AnyKernel3
git checkout main &> /dev/null
zip -r9 "../$ZIPNAME" * -x '*.git*' README.md *placeholder
cd ..

# ===== SEND ZIP =====
tg_file "$ZIPNAME" "📦 Kernel Build Finished
⏱ Time: $((SECONDS / 60))m $((SECONDS % 60))s"

rm -rf AnyKernel3
rm -rf out/arch/arm64/boot
else
tg_msg "❌ <b>Build Failed</b>
Check <code>log.txt</code>"
fi

tg_msg "🎉 <b>Done!</b>"