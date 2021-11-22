#
# Copy the following inside /etc/portage/bashrc:
#
# or
#
# Copy this file as /etc/portage/gcf-bashrc
# then add source /etc/portage/gcf-bashrc
# /etc/portage/bashrc
#

_gcf_translate_to_gcc_retpoline() {
	einfo
	einfo "Auto translating retpoline for gcc"
	einfo
	export CFLAGS=$(echo "${CFLAGS}" | sed -e "s|-mretpoline|-mindirect-branch=thunk -mindirect-branch-register|g")
	export CXXFLAGS=$(echo "${CXXFLAGS}" | sed -e "s|-mretpoline|-mindirect-branch=thunk -mindirect-branch-register|g")
	export LDFLAGS=$(echo "${LDFLAGS}" | sed -e "s|-mretpoline|-mindirect-branch=thunk -mindirect-branch-register|g")
}

_gcf_translate_to_clang_retpoline() {
	einfo
	einfo "Auto translating retpoline for clang"
	einfo
	export CFLAGS=$(echo "${CFLAGS}" | sed -e "s|-mindirect-branch=thunk|-mretpoline|g" -e "s|-mindirect-branch-register||g")
	export CXXFLAGS=$(echo "${CXXFLAGS}" | sed -e "s|-mindirect-branch=thunk|-mretpoline|g" -e "s|-mindirect-branch-register||g")
	export LDFLAGS=$(echo "${LDFLAGS}" | sed -e "s|-mindirect-branch=thunk|-mretpoline|g" -e "s|-mindirect-branch-register||g")
}

gcf_retpoline_translate() {
	if [[ -n "${USE_CLANG}" && "${USE_CLANG}" == "1" ]] ; then
		# explicit
		_gcf_translate_to_clang_retpoline
	elif [[ -n "${USE_GCC}" && "${USE_GCC}" == "1" ]] ; then
		# explicit
		_gcf_translate_to_gcc_retpoline
	elif [[ "${CC}" =~ "clang" || "${CXX}" =~ "clang++" ]] \
		&& [[ "${CFLAGS}" =~ "-mindirect-branch=thunk" \
			|| "${CXXFLAGS}" =~ "-mindirect-branch=thunk" ]] ; then
		# implicit
		_gcf_translate_to_clang_retpoline
	elif [[ "${CC}" =~ "gcc" || "${CXX}" =~ "g++" ]] \
		&& [[ "${CFLAGS}" =~ "-mretpoline" \
			|| "${CXXFLAGS}" =~ "-mretpoline" ]] ; then
		# implicit
		_gcf_translate_to_gcc_retpoline
	fi
}

gcf_strip_no_plt() {
	if [[ -n "${DISABLE_FNO_PLT}" && "${DISABLE_FNO_PLT}" == "1" ]] ; then
		einfo
		einfo "Removing -fno-plt from ${C,CXX,LD}FLAGS"
		einfo
		export CFLAGS=$(echo "${CFLAGS}" | sed -e "s|-fno-plt||g")
		export CXXFLAGS=$(echo "${CXXFLAGS}" | sed -e "s|-fno-plt||g")
		export LDFLAGS=$(echo "${LDFLAGS}" | sed -e "s|-fno-plt||g")
	fi
}

gcf_strip_gcc_flags() {
	local gcc_flags=(
		-fopt-info-vec
		-fopt-info-inline
		-frename-registers
	)

	if [[ -n "${DISABLE_GCC_FLAGS}" && "${DISABLE_GCC_FLAGS}" == "1" ]] ; then
		einfo
		einfo "Removing ${gcc_flags[@]} from ${C,CXX,LD}FLAGS"
		einfo
		for f in ${gcc_flags[@]} ; do
			export CFLAGS=$(echo "${CFLAGS}" | sed -e "s|${f}||g")
			export CXXFLAGS=$(echo "${CXXFLAGS}" | sed -e "s|${f}||g")
			export LDFLAGS=$(echo "${LDFLAGS}" | sed -e "s|${f}||g")
		done
	fi
}

gcf_strip_z_retpolineplt() {
	if [[ -n "${DISABLE_Z_RETPOLINEPLT}" && "${DISABLE_Z_RETPOLINEPLT}" == "1" ]] ; then
		einfo
		einfo "Removing -Wl,-z,retpolineplt from LDFLAGS"
		einfo
		export LDFLAGS=$(echo "${LDFLAGS}" | sed -e "s|-Wl,-z,retpolineplt||g")
	fi
}

gcf_is_thinlto_allowed() {
	local blacklisted=(
		"sys-devel/gcc"
		"sys-libs/glibc"
	)

	local p
	for p in ${blacklisted[@]} ; do
		[[ "${p}" == "${CATEGORY}/${PN}" ]] && return 1
	done
	return 0
}

gcf_met_lto_requirement() {
	local llvm_slots=(11 12 13 14)
	has_version "sys-devel/llvm" || return 1

	local found=0
	for s in ${llvm_slots[@]} ; do
		if ( has_version "sys-devel/llvm:${s}" \
			&& has_version "sys-devel/clang:${s}" \
			&& has_version ">=sys-devel/lld-${s}" ) ; then
			ver_test ${s} -le ${LLVM_MAX_SLOT:=14} && found=1
		fi
	done
	return ${found}
}

gcf_lto() {
	[[ -n "${DISABLE_GCF_LTO}" && "${DISABLE_GCF_LTO}" == "1" ]] && return

	_gcf_strip_lto_flags() {
		export CFLAGS=$(echo "${CFLAGS}" | sed -r -e 's/-flto( |$)//g' -e "s/-flto=[0-9]+//g" -e "s/-flto=(auto|jobserver|thin|full)//g" -e "s/-fuse-ld=(lld|bfd)//g")
		export CXXFLAGS=$(echo "${CXXFLAGS}" | sed -r -e 's/-flto( |$)//g' -e "s/-flto=[0-9]+//g" -e "s/-flto=(auto|jobserver|thin|full)//g" -e "s/-fuse-ld=(lld|bfd)//g")
		export FCFLAGS=$(echo "${FCFLAGS}" | sed -r -e 's/-flto( |$)//g' -e "s/-flto=[0-9]+//g" -e "s/-flto=(auto|jobserver|thin|full)//g" -e "s/-fuse-ld=(lld|bfd)//g")
		export FFLAGS=$(echo "${FFLAGS}" | sed -r -e 's/-flto( |$)//g' -e "s/-flto=[0-9]+//g" -e "s/-flto=(auto|jobserver|thin|full)//g" -e "s/-fuse-ld=(lld|bfd)//g")
		export LDFLAGS=$(echo "${LDFLAGS}" | sed -r -e 's/-flto( |$)//g' -e "s/-flto=[0-9]+//g" -e "s/-flto=(auto|jobserver|thin|full)//g" -e "s/-fuse-ld=(lld|bfd)//g")
	}

	if [[ -z "${DISABLE_LTO}" || ( -n "${DISABLE_LTO}" && "${DISABLE_LTO}" != "1" ) ]] \
		&& gcf_is_thinlto_allowed \
		&& gcf_met_lto_requirement ; then
		einfo
		einfo "Switching to clang for ThinLTO"
		einfo
		export CC=clang
		export CXX=clang++
		export CPP=clang-cpp
		export AR=llvm-ar
		export AS=llvm-as
		export NM=llvm-nm
		export OBJCOPY=llvm-objcopy
		export OBJDUMP=llvm-objdump
		export RANLIB=llvm-ranlib
		export READELF=llvm-readelf
		export STRIP=llvm-strip

		einfo
		einfo "Auto switching to ThinLTO"
		einfo
		_gcf_strip_lto_flags
		CFLAGS=$(echo "${CFLAGS} -flto=thin")
		CXXFLAGS=$(echo "${CXXFLAGS} -flto=thin")
		FCFLAGS=$(echo "${FCFLAGS} -flto=thin")
		FFLAGS=$(echo "${FFLAGS} -flto=thin")
		LDFLAGS=$(echo "${LDFLAGS} -fuse-ld=lld -flto=thin")

		if gcc --version | grep -q -e "Hardened" ; then
			if clang --version | grep -q -e "Hardened" ; then
				:;
			else
ewarn
ewarn "Non-hardened clang detected.  Use the clang ebuild from the"
ewarn "oiledmachine-overlay.  Not doing so can weaken the security."
ewarn
			fi
		fi
	fi
	# Avoiding gcc/lto because of *serious* memory issues on 1 GIB per core machines.

	if [[ -n "${DISABLE_LTO_STRIPPING}" && "${DISABLE_LTO_STRIPPING}" == "1" ]] ; then
		:;
	elif [[ -n "${DISABLE_LTO}" && "${DISABLE_LTO}" == "1" ]] ; then
		einfo
		einfo "Forced removal of -flto from {C,CXX,LD}FLAGS"
		einfo
		_gcf_strip_lto_flags
	elif has lto ${IUSE_EFFECTIVE} ; then
		# Prioritize the lto USE flag over make.conf/package.env.
		# Some build systems are designed to ignore *FLAGS provided by make.conf/package.env.
		einfo
		einfo "Removing -flto from {C,CXX,LD}FLAGS.  Using the USE flag setting instead."
		einfo
		_gcf_strip_lto_flags
	fi
	export CFLAGS
	export CXXFLAGS
	export FCFLAGS
	export FFLAGS
	export LDFLAGS
}

pre_pkg_setup()
{
	einfo
	einfo "Running pre_pkg_setup()"
	einfo
	gcf_lto
}

pre_src_configure()
{
	einfo
	einfo "Running pre_src_configure()"
	einfo
	gcf_retpoline_translate
	gcf_strip_no_plt
	gcf_strip_gcc_flags
	gcf_strip_z_retpolineplt
}
