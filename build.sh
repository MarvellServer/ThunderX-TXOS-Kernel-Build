#!/bin/bash

set -xv

kversion=5.4.29_TXOS_20.04

spec_name="SPECS/kernel-aarch64.spec"
build_arch="aarch64"

build_opts=(--define "%_topdir $PWD")
build_opts+=(--define "%kern_version $kversion")

${cross_compile:""}

if [ x"$do_build" == x"clean" ]; then
    pushd BUILD
    rm -rf ./*
    popd 
    pushd BUILDROOT
    rm -rf ./*
    popd
    pushd RPMS
    rm -rf ./*
    popd
    pushd SRPMS
    rm -rf ./*
    popd
    exit 0;
fi

# select cavium compiler if ilp32 is requested
if [ x"$ilp32" == x"yes" ]; then
    build_arch="aarch64-thunderx"
    build_opts+=(--define "ilp32_build 1")
    no_deps="yes"
    no_debug="yes"
    no_perf="yes"
    sed -i -e 's/# CONFIG_ARM64_ILP32 is not set/CONFIG_ARM64_ILP32=y/g' SOURCES/config-arm64
else
    sed -i -e 's/CONFIG_ARM64_ILP32=y/# CONFIG_ARM64_ILP32 is not set/g' SOURCES/config-arm64
fi

cross_compile=${build_arch}-linux

build_target=${build_arch}-linux

host_type=`uname -m`

if [ x"$host_type" != x"aarch64" -o x"$ilp32" == x"yes" ]; then
    export CROSS_COMPILE=${cross_compile}-gnu-
    export ARCH=arm64
    build_opts+=(--define "__strip ${cross_compile}-gnu-strip")
fi

build_opts+=(--target "${build_target}")
build_opts+=(--define "_build_arch ${build_arch}")

if [ x"$no_deps" == x"yes" ]; then
    build_opts+=(--nodeps)
fi

if [ x"$no_perf" == x"yes" ]; then
    build_opts+=(--without=perf)
fi

if [ x"$no_debug" == x"yes" ]; then
    build_opts+=(--without=debug --without=debuginfo)
fi


if [ ! -e SOURCES/linux-$kversion.tar.xz ]; then
    pushd SOURCES
    git clone https://github.com/MarvellServer/ThunderX-TXOS.git -b next linux-$kversion
    tar -cJf linux-$kversion.tar.xz linux-$kversion
    popd
fi

echo "PWD:${PWD}"
echo build_opts:${build_opts[@]}

if [ x"$do_build" == x"srpm" ]; then
    rpmbuild "${build_opts[@]}" \
		-bs ${spec_name} \
		2>&1 | tee build-out.log
    exit 0;
fi

if [ x"$do_build" == x"yes" ]; then
    rpmbuild "${build_opts[@]}" \
		-ba ${spec_name} \
		2>&1 | tee build-out.log
else
    echo build target: $build_target
    echo build arch: $build_arch
    echo build opts: $build_opts
fi
