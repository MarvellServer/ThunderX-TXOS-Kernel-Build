#!/bin/bash

# stop on errors:
set -e

set -xv

spec_name="SPECS/kernel.spec"
build_arch="aarch64"

build_opts=(--define "%_topdir $PWD")

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
    #sed -i -e 's/CONFIG_ARM64_ILP32=y/# CONFIG_ARM64_ILP32 is not set/g' SOURCES/config-arm64
    :
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


if [ ! -e SOURCES/linux-txos.tar.xz ]; then
(
    topdir=$(pwd)
    mkdir -p SOURCES/linux-txos
    cd SOURCES/linux-txos
    if [ -d .git ]; then
	git fetch origin
    else
	git clone --reference-if-able ${txosgit:-$(cd $topdir/../ThunderX-TXOS; pwd)} \
	    https://github.com/MarvellServer/ThunderX-TXOS.git -n .
    fi
    git checkout ${cid:-origin/next}
    git config tar.tar.xz.command "xz -c"
    git archive HEAD --prefix=linux-txos/ \
	-o $topdir/SOURCES/linux-txos.tar.xz
)
fi

if [ -d SOURCES/linux-txos ]; then
    txos_cid=$(xzcat SOURCES/linux-txos.tar.xz | git get-tar-commit-id)
    [ -n "$txos_cid" ]

    txos=$(
	cd SOURCES/linux-txos
	git describe --match txos-2\*.\* --abbrev=0 --always $txos_cid
    )
    txosfull=$(
	cd SOURCES/linux-txos
	git describe --match txos-2\*.\* --abbrev=12 --always $txos_cid
    )
    pkg=$(
	cd SOURCES/linux-txos
	git describe --match txos-\*-\* --abbrev=0 --always $txos_cid
    )
    pkgfull=$(
	cd SOURCES/linux-txos
	git describe --match txos-\*-\* --abbrev=12 --always $txos_cid
    )

    base=${pkg%-*}
    base=${base#txos-}

    build_opts+=(--define "txos_base $base")
    build_opts+=(--define "txos_patchlevel ${pkg##*-}")

    if [ -n "${txos_release:-}" ]; then
	build_opts+=(--define "txos_release $txos_release")
    elif [ "$txos" = "$txosfull" ]; then
	build_opts+=(--define "txos_release txos${txos#txos-}")
    else
	build_opts+=(--define "txos_release txos${txos#txos-}+")
    fi

    if [ "$pkg" != "$pkgfull" ]; then
	build_opts+=(--define "buildid .g${pkgfull##*-g}")
    fi
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
		--without kabichk \
		--without kernel_abi_whitelists \
		--without cross_headers \
		2>&1 | tee build-out.log
else
    echo build target: $build_target
    echo build arch: $build_arch
    echo build opts: $build_opts
fi
