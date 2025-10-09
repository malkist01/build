#!/usr/bin/env bash
rm -rf kernel
git clone $REPO -b $BRANCH kernel 
cd kernel
echo "Nuke previous toolchains"
rm -rf toolchain out AnyKernel
echo "cleaned up"
echo "Cloning toolchain"
if [ "$is_test" = true ]; then
     echo "Its alpha test build"
     unset chat_id
     unset token
     export chat_id=${my_id}
     export token=${nToken}
else
     echo "Its beta release build"
fi
SHA=$(echo $DRONE_COMMIT_SHA | cut -c 1-8)
IMAGE=$(pwd)/out/arch/arm/boot/zImage
DATE=$(date +'%H%M-%d%m%y')
START=$(date +"%s")
CODENAME=j6primelte
DEF=j6primelte_defconfig
export PATH=$(pwd)/proton-clang/bin:$PATH
export CROSS_COMPILE=$(pwd)/proton-clang/bin/arm-linux-gnueabi-
ARCH=arm
CC=clang
CCOMP=arm-linux-gnueabi-
export ARCH=arm
export KBUILD_BUILD_USER=malkist
export KBUILD_BUILD_HOST=android
# Push kernel to channel
function push() {
    cd AnyKernel || exit 1
    ZIP=$(echo *.zip)
    curl -F document=@$ZIP "https://api.telegram.org/bot$token/sendDocument" \
        -F chat_id="$chat_id" \
        -F "disable_web_page_preview=true" \
        -F "parse_mode=html" \
        -F caption="Build took $(($DIFF / 60)) minute(s) and $(($DIFF % 60)) second(s). | For <b>Samsung J6+</b>"
}
# Compile plox
function compile() {
# Make .config
     make -C $(pwd) O=out ${DEF}
     make -j64 -C $(pwd) O=out
     ARCH=$ARCH
     CC=$CC \
     HOSTCC=$CC \
     CROSS_COMPILE=$CCOMP \

# Compile Kernel
     make -C $(pwd) O=out ${DEF}
     make -j64 -C $(pwd) O=out
     ARCH=$ARCH \
     CC=$CC \
     HOSTCC=$CC \
     CROSS_COMPILE=$CCOMP

     if ! [ -a "$IMAGE" ]; then
        finderr
        exit 1
     fi
    git clone --depth=1 https://github.com/malkist01/anykernel3.git AnyKernel -b master
    cp out/arch/arm/boot/zImage AnyKernel
}
# Zipping
zipping() {
    cd AnyKernel || exit 1
    zip -r9 Teletubies-"${CODENAME}"-"${ARCH}"-"${DATE}".zip ./*
    cd ..
}
compile
zipping
END=$(date +"%s")
DIFF=$(($END - $START))
push
