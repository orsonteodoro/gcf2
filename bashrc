#
# Copy the following inside /etc/portage/bashrc:
#
# or
#
# Copy this file as /etc/portage/gcf-bashrc
# then add this line:
#
#   source /etc/portage/gcf-bashrc
#
# in /etc/portage/bashrc.
#

_gcf_replace_flag() {
	local i="${1}"
	local o="${2}"
	export CFLAGS=$(echo "${CFLAGS}" | sed -e "s|${i}|${o}|g")
	export CXXFLAGS=$(echo "${CXXFLAGS}" | sed -e "s|${i}|${o}|g")
	export FCFLAGS=$(echo "${FCFLAGS}" | sed -e "s|${i}|${o}|g")
	export FFLAGS=$(echo "${FFLAGS}" | sed -e "s|${i}|${o}|g")
	export LDFLAGS=$(echo "${LDFLAGS}" | sed -r -e "s/(^| )${i}/${o}/g")
}

_gcf_translate_to_gcc_retpoline() {
	einfo
	einfo "Auto translating retpoline for gcc"
	einfo
	_gcf_replace_flag "-mretpoline" "-mindirect-branch=thunk -mindirect-branch-register"
}

_gcf_translate_to_clang_retpoline() {
	einfo
	einfo "Auto translating retpoline for clang"
	einfo
	_gcf_replace_flag "-mindirect-branch=thunk" "-mretpoline"
	_gcf_replace_flag "-mindirect-branch-register" ""
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

gcf_strip_no_inline() {
	if [[ "${CFLAGS}" =~ "-fno-inline" \
		&& ( "${CFLAGS}" =~ ("-Ofast"|"-O2"|"O3") \
			|| ( -n "${DISABLE_NO_INLINE}" && "${DISABLE_NO_INLINE}" == "1" ) \
			|| ( "${CC}" =~ "clang" || "${CXX}" =~ "clang++" ) \
		) ]] ; then
		einfo
		einfo "Removing -fno-inline from *FLAGS"
		einfo
		_gcf_replace_flag "-fno-inline" ""
	fi
}

gcf_strip_no_plt() {
	if [[ -n "${DISABLE_FNO_PLT}" && "${DISABLE_FNO_PLT}" == "1" ]] ; then
		einfo
		einfo "Removing -fno-plt from *FLAGS"
		einfo
		_gcf_replace_flag "-fno-plt" ""
	fi
}

gcf_strip_gcc_flags() {
	local gcc_flags=(
		-fopt-info-vec
		-fopt-info-inline
		-frename-registers
	)

	if [[ ( -n "${DISABLE_GCC_FLAGS}" && "${DISABLE_GCC_FLAGS}" == "1" ) \
		|| ( -n "${_GCF_SWITCHED_TO_THINLTO}" && "${_GCF_SWITCHED_TO_THINLTO}" == "1" ) ]] ; then
		einfo
		einfo "Removing ${gcc_flags[@]} from *FLAGS"
		einfo
		for f in ${gcc_flags[@]} ; do
			_gcf_replace_flag "${f}" ""
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
			(( ${s} <= ${LLVM_MAX_SLOT:=14} )) && found=1
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

	# It's okay to use GCC+BFD LTO or WPA-LTO for small packages.
	if [[ ( -n "${DISABLE_GCC_LTO}" && "${DISABLE_GCC_LTO}" == "1" ) ]] ; then
		# This should be disabled for packages that take literally most of the day or more to complete with GCC LTO.
		# Auto switching to ThinLTO for larger packages instead.
		_gcf_strip_lto_flags
	fi

	if [[ -z "${DISABLE_CLANG_LTO}" || ( -n "${DISABLE_CLANG_LTO}" && "${DISABLE_CLANG_LTO}" != "1" ) ]] \
		&& gcf_is_thinlto_allowed \
		&& gcf_met_lto_requirement ; then
		einfo
		einfo "Auto switching to clang for ThinLTO"
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
		export _GCF_SWITCHED_TO_THINLTO=1

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
		einfo "Forced removal of -flto from *FLAGS"
		einfo
		_gcf_strip_lto_flags
	elif has lto ${IUSE_EFFECTIVE} ; then
		# Prioritize the lto USE flag over make.conf/package.env.
		# Some build systems are designed to ignore *FLAGS provided by make.conf/package.env.
		einfo
		einfo "Removing -flto from *FLAGS.  Using the USE flag setting instead."
		einfo
		_gcf_strip_lto_flags
	fi
	export CFLAGS
	export CXXFLAGS
	export FCFLAGS
	export FFLAGS
	export LDFLAGS
}

gcf_replace_flags()
{
	if [[ -n "${OPT_LEVEL}" && "${OPT_LEVEL}" =~ ("-O0"|"-O1"|"-O2"|"-O3"|"-O4"|"-Ofast"|"-Oz"|"-Os") ]] ; then
		_gcf_replace_flag "${DEFAULT_OPT_LEVEL}" "${OPT_LEVEL}"
	fi
}

gcf_strip_lossy()
{
	if [[ -n "${I_WANT_LOSSLESS}" && "${I_WANT_LOSSLESS}" == "1" ]] ; then
		if [[ "${CFLAGS}" =~ "-Ofast" ]] ; then
			einfo
			einfo "Converting -Ofast -> -O3"
			einfo
			_gcf_replace_flag "-Ofast" "-O3"
		fi

		if [[ "${CFLAGS}" =~ "-ffast-math" ]] ; then
			einfo
			einfo "Stripping -ffast-math"
			einfo
			_gcf_replace_flag "-ffast-math" ""
		fi
	fi
}

gcf_use_Oz()
{
	if [[ ( "${CC}" == "clang" || "${CXX}" == "clang++" ) && "${CFLAGS}" =~ "-Os" ]] ; then
		einfo
		einfo "Detected clang.  Converting -Os -> -Oz"
		einfo
		_gcf_replace_flag "-Os" "-Oz"
	fi
	if [[ ( "${CC}" == "gcc" || "${CXX}" == "g++" ) && "${CFLAGS}" =~ "-Oz" ]] ; then
		einfo
		einfo "Detected gcc.  Converting -Oz -> -Os"
		einfo
		_gcf_replace_flag "-Oz" "-Os"
	fi
}

gcf_replace_freorder_blocks_algorithm()
{
	if [[ "FREORDER_BLOCKS_ALGORITHM" == "stc" ]] ; then
		_gcf_replace_flag "-freorder-blocks-algorithm=simple" "-freorder-blocks-algorithm=stc"
	fi
}

gcf_adjust_makeopts()
{
	if [[ -z "${NCORES}" ]] ; then
eerror
eerror "Set NCORES in the /etc/portage/make.conf.  Set the number of CPU cores"
eerror "not multiplying the threads per core."
eerror
		die
	fi
	if [[ -z "${MPROCS}" ]] ; then
eerror
eerror "Set MPROCS in the /etc/portage/make.conf.  2 is recommended."
eerror
		die
	fi
	if [[ "${MAKEOPTS_MODE:=normal}" == "normal" ]] ; then
		local n=$((${NCORES} * ${MPROCS}))
		export MAKEOPTS="-j${n}"
		export MAKEFLAGS="-j${n}"
	elif [[ "${MAKEOPTS_MODE}" == "swappy" ]] ; then
		local n=$((${NCORES} / 2))
		(( ${n} <= 0 )) && n=1
		export MAKEOPTS="-j${n}"
		export MAKEFLAGS="-j${n}"
	elif [[ "${MAKEOPTS_MODE}" == "plain" ]] ; then
		export MAKEOPTS="-j${NCORES}"
		export MAKEFLAGS="-j${NCORES}"
	elif [[ "${MAKEOPTS_MODE}" == "oom" || "${MAKEOPTS_MODE}" == "broken" ]] ; then
		export MAKEOPTS="-j1"
		export MAKEFLAGS="-j1"
	fi
	einfo
	einfo "MAKEOPTS_MODE is ${MAKEOPTS_MODE} (-j${n})"
	einfo
}

pre_pkg_setup()
{
	einfo
	einfo "Running pre_pkg_setup()"
	einfo
	gcf_replace_flags
	gcf_lto
	gcf_retpoline_translate
	gcf_strip_no_plt
	gcf_strip_gcc_flags
	gcf_strip_z_retpolineplt
	gcf_strip_no_inline
	gcf_strip_lossy
	gcf_use_Oz
	gcf_replace_freorder_blocks_algorithm
	gcf_adjust_makeopts
}

gcf_check_Ofast_safety()
{
	[[ -n "${DISABLE_FALLOW_STORE_DATA_RACES_CHECK}" && "${DISABLE_FALLOW_STORE_DATA_RACES_CHECK}" == "1" ]] && return
	if [[ "${OPT_LEVEL}" == "-Ofast" && -e "${T}/build.log" ]] ; then
		if grep -q -E -e "(-lboost_thread|-lgthread|-lomp|-pthread|-lpthread|-ltbb)" "${T}/build.log" ; then
eerror
eerror "Detected thread use.  Disable -Ofast or add DISABLE_FALLOW_STORE_DATA_RACES_CHECK=1 as a per-package envvar."
eerror
			die
		fi
	fi
	if [[ "${CFLAGS}" =~ "-fallow-store-data-races" && -e "${T}/build.log" ]] ; then
		if grep -q -E -e "(-lboost_thread|-lgthread|-lomp|-pthread|-lpthread|-ltbb)" "${T}/build.log" ; then
eerror
eerror "Detected thread use.  Disable -fallow-store-data-races or add DISABLE_FALLOW_STORE_DATA_RACES_CHECK=1 as a per-package envvar."
eerror
			die
		fi
	fi
}

pre_src_install() {
	einfo
	einfo "Running pre_src_install()"
	einfo
	gcf_check_Ofast_safety
}
