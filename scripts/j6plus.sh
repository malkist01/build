#!/usr/bin/env bash
rm -rf kernel
git clone $REPO -b $BRANCH kernel 
cd kernel
git clone --depth=1 https://github.com/malkist01/patch
git submodule add https://github.com/rifsxd/KernelSU-Next
git submodule init && git submodule update
curl -LSs "https://raw.githubusercontent.com/KernelSU-Next/KernelSU-Next/next/kernel/setup.sh" | bash -
#add KSU Config
echo "# CONFIG_KSU_MANUAL_HOOK=°y" >> ./arch/arm/configs/j6primelte_defconfig
echo "# CONFIG_OVERLAY_FS=y" >> ./arch/arm/configs/j6primelte_defconfig
echo "# CONFIG_KPM is not set" >> ./arch/arm/configs/j6primelte_defconfig
echo "CONFIG_KALLSYMS=y" >> ./arch/arm/configs/j6primelte_defconfig
echo "CONFIG_KALLSYMS_ALL=y" >> ./arch/arm/configs/j6primelte_defconfig
echo "CONFIG_LOCAL_VERSION=-Teletubies 🕊️" >> ./arch/arm/configs/j6primelte_defconfig
echo "# CONFIG_LOCAL_VERSION_AUTO is not set" >> ./arch/arm/configs/j6primelte_defconfig
echo "CONFIG_LINUX_COMPILE_BY=malkist" >> ./arch/arm/configs/j6primelte_defconfig
echo "CONFIG_LINUX_COMPILE_HOST=hp jadul" >> ./arch/arm/configs/j6primelte_defconfig
echo "Adding CONFIG_KSU.."
echo "CONFIG_KSU=y" >> ./arch/arm/configs/j6primelte_defconfig
echo "CONFIG_KSU_TRACEPOINT_HOOK=y" >> ./arch/arm/configs/j6primelte_defconfig
rm -rf KernelSU
# Add KernelSU
curl -LSs "https://raw.githubusercontent.com/KernelSU-Next/KernelSU-Next/next/kernel/setup.sh" | bash -s next
echo "Nuke previous toolchains"
rm -rf toolchain out AnyKernel
echo "cleaned up"
echo "Cloning toolchain"
git clone --depth=1 https://github.com/KudProject/arm-linux-androideabi-4.9.git -b master gcc32
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
export CROSS_COMPILE="$(pwd)/gcc32/bin/arm-linux-androideabi-"
export PATH="$(pwd)/gcc32/bin:$PATH"
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
     make -C $(pwd) O=out ${DEF}
     make -j64 -C $(pwd) O=out
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
