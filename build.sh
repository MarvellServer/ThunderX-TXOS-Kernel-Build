#!/bin/bash

# stop on errors:
set -e

set -xv

spec_name="SPECS/kernel.spec"
build_arch="aarch64"

build_opts=(--define "%_topdir $PWD")

${cross_compile:""}

if [ -n "${do_release:=}" ]; then
    if ! (echo "$do_release" | sed -e '/^txos2[0-9][.][0-9][0-9]$/Q0;Q1'); then
	echo "Release string '$do_release' does not fit the version format: txos2\\d.\\d\\d"
	exit 1
    fi
    do_build=yes
    txos_release=$do_release
fi

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

if ([ -e SOURCES/linux-txos.tar.xz ] \
    && ([ -n "$do_release" ] || [ -n "${cid:-}" ])); then
    rm SOURCES/linux-txos.tar.xz
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

if [ -e SOURCES/linux-txos.tar.xz ]; then
    txos_cid=$(xzcat SOURCES/linux-txos.tar.xz | git get-tar-commit-id)
fi

if [ -n "${txos_base:-}" ]		&& \
   [ -n "${txos_patchlevel:-}" ]	&& \
   [ -n "${txos_release:-}" ];		then
    : # package information already defined
elif [ -n "$txos_cid:-" ];then
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
	git describe --tags --match txos-\*-\* --abbrev=0 --always $txos_cid
    )
    pkgfull=$(
	cd SOURCES/linux-txos
	git describe --tags --match txos-\*-\* --abbrev=12 --always $txos_cid
    )

    base=${pkg%-*}
    base=${base#txos-}

    txos_base="$base"
    txos_patchlevel="${pkg##*-}"

    if [ -n "${txos_release:-}" ]; then
	txos_release="$txos_release"
    elif [ "$txos" = "$txosfull" ]; then
	txos_release="txos${txos#txos-}"
    else
	txos_release="txos${txos#txos-}+"
    fi

    if [ "$pkg" = "$pkgfull" ]; then
	: # nop
    elif [ -n "$do_release" ]; then
	echo 'A release requires a kernel version tag in the format: txos-<base>-<patchlevel>'
	exit 1
    else
	buildid=".g${pkgfull##*-g}"
    fi
else
    echo "No TXOS package information found"
    exit 1
fi

cat<<EOF >SOURCES/txos.inc
%define txos_base       ${txos_base:?}
%define txos_patchlevel ${txos_patchlevel:?}
%define txos_release    ${txos_release:?}
EOF

if [ -n "${buildid:-}" ]; then
    cat<<EOF >>SOURCES/txos.inc
%define buildid         $buildid
EOF
fi

cat SOURCES/txos.inc

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
