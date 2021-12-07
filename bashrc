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

gcf_info() {
	echo -e ">>> [GCF] ${@}"
}

gcf_warn() {
	echo -e ">>> \e[30m\e[43m[GCF]\e[0m ${@}"
}

gcf_error() {
	echo -e ">>> \e[30m\e[41m[GCF]\e[0m ${@}"
}

_gcf_replace_flag() {
	local i="${1}"
	local o="${2}"
	export COMMON_FLAGS=$(echo "${COMMON_FLAGS}" | sed -r -e "s/(^| )${i}/${o}/g")
	export CFLAGS=$(echo "${CFLAGS}" | sed -e "s|${i}|${o}|g")
	export CXXFLAGS=$(echo "${CXXFLAGS}" | sed -e "s|${i}|${o}|g")
	export FCFLAGS=$(echo "${FCFLAGS}" | sed -e "s|${i}|${o}|g")
	export FFLAGS=$(echo "${FFLAGS}" | sed -e "s|${i}|${o}|g")
	export LDFLAGS=$(echo "${LDFLAGS}" | sed -r -e "s/(^| )${i}/${o}/g")
}

_gcf_translate_to_gcc_retpoline() {
	gcf_info "Auto translating retpoline for gcc"
	_gcf_replace_flag "-mretpoline" "-mindirect-branch=thunk -mindirect-branch-register"
}

_gcf_translate_to_clang_retpoline() {
	gcf_info "Auto translating retpoline for clang"
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
	elif [[ ( -z "${CC}" && -z "${CXX}" ) || "${CC}" =~ "gcc" || "${CXX}" =~ "g++" ]] \
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
		gcf_info "Removing -fno-inline from *FLAGS"
		_gcf_replace_flag "-fno-inline" ""
	fi
}

gcf_strip_no_plt() {
	if [[ -n "${DISABLE_FNO_PLT}" && "${DISABLE_FNO_PLT}" == "1" ]] ; then
		gcf_info "Removing -fno-plt from *FLAGS"
		_gcf_replace_flag "-fno-plt" ""
	fi
}

gcf_strip_gcc_flags() {
	local gcc_flags=(
		-fopt-info-inline
		-fopt-info-loop
		-fopt-info-vec
		-frename-registers
		-freorder-blocks-algorithm=simple
		-freorder-blocks-algorithm=stc
	)

	if [[ ( -n "${DISABLE_GCC_FLAGS}" && "${DISABLE_GCC_FLAGS}" == "1" ) \
		|| ( -n "${_GCF_SWITCHED_TO_THINLTO}" && "${_GCF_SWITCHED_TO_THINLTO}" == "1" ) ]] ; then
		gcf_info "Removing ${gcc_flags[@]} from *FLAGS"
		for f in ${gcc_flags[@]} ; do
			_gcf_replace_flag "${f}" ""
		done
	fi
}

gcf_strip_z_retpolineplt() {
	if [[ -n "${DISABLE_Z_RETPOLINEPLT}" && "${DISABLE_Z_RETPOLINEPLT}" == "1" ]] ; then
		gcf_info "Removing -Wl,-z,retpolineplt from LDFLAGS"
		export LDFLAGS=$(echo "${LDFLAGS}" | sed -e "s|-Wl,-z,retpolineplt||g")
	fi
}

gcf_is_clang_lto_allowed() {
	local blacklisted
	if [[ ! -e "/etc/portage/emerge-system.lst" ]] ; then
gcf_error
gcf_error "Missing /etc/portage/emerge-system.lst."
gcf_error
gcf_error "To generate this file do:"
gcf_error 'emerge -pve system | cut -c 18- | cut -f 1 -d " " | grep "/" | sed -E -e "s|[:]+.*||g" | sed -E -e "s/(-r[0-9]+|_p[0-9]+)+$//g" | sed -E  -e "s|-[.0-9_a-z]+$||g" | sort | uniq > /etc/portage/emerge-system.lst'
gcf_error
		die
	fi
	# Prevent static-libs link and config test problems.
	blacklisted=( $(cat /etc/portage/emerge-system.lst) )

	local p
	for p in ${blacklisted[@]} ; do
		[[ "${p}" == "${CATEGORY}/${PN}" ]] && return 1
	done
	return 0
}

gcf_is_gcc_lto_allowed() {
	local blacklisted=()

	local p
	for p in ${blacklisted[@]} ; do
		[[ "${p}" == "${CATEGORY}/${PN}" ]] && return 1
	done
	return 0
}

gcf_met_clang_lto_requirement() {
	local llvm_slots=(14 13 12 11)
	has_version "sys-devel/llvm" || return 1

	local found=1
	for s in ${llvm_slots[@]} ; do
		if ( has_version "sys-devel/llvm:${s}" \
			&& has_version "sys-devel/clang:${s}" \
			&& has_version ">=sys-devel/lld-${s}" ) ; then
			(( ${s} <= ${LLVM_MAX_SLOT:=14} )) && found=0
		fi
	done
	return ${found}
}

gcf_met_clang_goldlto_requirement() {
	local llvm_slots=(14 13 12 11)
	has_version "sys-devel/llvm" || return 1

	local found=1
	for s in ${llvm_slots[@]} ; do
		if ( ( has_version "sys-devel/llvm:${s}[gold]" || has_version "sys-devel/llvm:${s}[binutils-plugin]" ) \
			&& has_version "sys-devel/binutils[plugins,gold]" \
			&& has_version ">=sys-devel/llvmgold-${s}" ) ; then
			(( ${s} <= ${LLVM_MAX_SLOT:=14} )) && found=0
		fi
	done
	return ${found}
}

gcf_met_gcc_bfdlto_requirement() {
	has_version "sys-devel/gcc" || return 1

	if has_version "sys-devel/binutils[plugins]" ; then
		return 0
	fi
	return 1
}

gcf_met_gcc_goldlto_requirement() {
	has_version "sys-devel/gcc" || return 1

	if has_version "sys-devel/binutils[plugins,gold]" ; then
		return 0
	fi
	return 1
}

gcf_use_clang() {
	gcf_info "Auto switching to clang"
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
}

gcf_use_thinlto() {
	gcf_info "Auto switching to ThinLTO"
	COMMON_FLAGS=$(echo "${COMMON_FLAGS} -flto=thin")
	CFLAGS=$(echo "${CFLAGS} -flto=thin")
	CXXFLAGS=$(echo "${CXXFLAGS} -flto=thin")
	FCFLAGS=$(echo "${FCFLAGS} -flto=thin")
	FFLAGS=$(echo "${FFLAGS} -flto=thin")
	LDFLAGS=$(echo "${LDFLAGS} -fuse-ld=lld -flto=thin")
}

gcf_use_clang_goldlto() {
	gcf_info "Auto switching to Clang Gold LTO"
	COMMON_FLAGS=$(echo "${COMMON_FLAGS} -flto=full")
	CFLAGS=$(echo "${CFLAGS} -flto=full")
	CXXFLAGS=$(echo "${CXXFLAGS} -flto=full")
	FCFLAGS=$(echo "${FCFLAGS} -flto=full")
	FFLAGS=$(echo "${FFLAGS} -flto=full")
	LDFLAGS=$(echo "${LDFLAGS} -fuse-ld=gold -flto=full")
}

gcf_use_gcc_goldlto() {
	gcf_info "Auto switching to GCC Gold LTO"
	COMMON_FLAGS=$(echo "${COMMON_FLAGS} -flto")
	CFLAGS=$(echo "${CFLAGS} -flto")
	CXXFLAGS=$(echo "${CXXFLAGS} -flto")
	FCFLAGS=$(echo "${FCFLAGS} -flto")
	FFLAGS=$(echo "${FFLAGS} -flto")
	LDFLAGS=$(echo "${LDFLAGS} -fuse-ld=gold -flto")
}

gcf_use_gcc_bfdlto() {
	gcf_info "Auto switching to GCC BFD LTO"
	COMMON_FLAGS=$(echo "${COMMON_FLAGS} -flto")
	CFLAGS=$(echo "${CFLAGS} -flto")
	CXXFLAGS=$(echo "${CXXFLAGS} -flto")
	FCFLAGS=$(echo "${FCFLAGS} -flto")
	FFLAGS=$(echo "${FFLAGS} -flto")
	LDFLAGS=$(echo "${LDFLAGS} -fuse-ld=bfd -flto")
}

gcf_lto() {
	[[ -n "${DISABLE_GCF_LTO}" && "${DISABLE_GCF_LTO}" == "1" ]] && return

	if ! has_version "sys-devel/binutils[plugins]" ; then
gcf_warn "The plugins USE flag must be enabled in sys-devel/binutils for LTO to work."
	fi

	_gcf_strip_lto_flags() {
		export COMMON_FLAGS=$(echo "${COMMON_FLAGS}" | sed -r \
			-e 's/-flto( |$)//g' \
			-e "s/-flto=[0-9]+//g" \
			-e "s/-flto=(auto|jobserver|thin|full)//g" \
			-e "s/-fuse-ld=(lld|bfd)//g")
		export CFLAGS=$(echo "${CFLAGS}" | sed -r \
			-e 's/-flto( |$)//g' \
			-e "s/-flto=[0-9]+//g" \
			-e "s/-flto=(auto|jobserver|thin|full)//g" \
			-e "s/-fuse-ld=(lld|bfd)//g")
		export CXXFLAGS=$(echo "${CXXFLAGS}" | sed -r \
			-e 's/-flto( |$)//g' \
			-e "s/-flto=[0-9]+//g" \
			-e "s/-flto=(auto|jobserver|thin|full)//g" \
			-e "s/-fuse-ld=(lld|bfd)//g")
		export FCFLAGS=$(echo "${FCFLAGS}" | sed -r \
			-e 's/-flto( |$)//g' \
			-e "s/-flto=[0-9]+//g" \
			-e "s/-flto=(auto|jobserver|thin|full)//g" \
			-e "s/-fuse-ld=(lld|bfd)//g")
		export FFLAGS=$(echo "${FFLAGS}" | sed -r \
			-e 's/-flto( |$)//g' \
			-e "s/-flto=[0-9]+//g" \
			-e "s/-flto=(auto|jobserver|thin|full)//g" \
			-e "s/-fuse-ld=(lld|bfd)//g")
		export LDFLAGS=$(echo "${LDFLAGS}" | sed -r \
			-e 's/-flto( |$)//g' \
			-e "s/-flto=[0-9]+//g" \
			-e "s/-flto=(auto|jobserver|thin|full)//g" \
			-e "s/-fuse-ld=(lld|bfd)//g")
	}

	if has lto ${IUSE_EFFECTIVE} ; then
		# Prioritize the lto USE flag over make.conf/package.env.
		# Some build systems are designed to ignore *FLAGS provided by \
		#   make.conf/package.env.
		# Some packages want to manipulate LTO -O* flags.
gcf_info "Removing -flto from *FLAGS.  Using the USE flag setting instead."
		_gcf_strip_lto_flags
	else
		# A reminder that you can only use one LTO implementation as the
		# default systemwide.

		if [[      ( -n "${CC_LTO}"  && "${CC_LTO}"  == "clang" ) \
			|| ( -n "${CXX_LTO}" && "${CXX_LTO}" == "clang++" ) ]] \
			&& [[ -n "${USE_THINLTO}" && "${USE_THINLTO}" == "1" ]] \
			&& gcf_is_clang_lto_allowed \
			&& gcf_met_clang_thinlto_requirement ; then
			_gcf_strip_lto_flags
			gcf_use_thinlto
			if gcc --version | grep -q -e "Hardened" ; then
				if clang --version | grep -q -e "Hardened" ; then
				:;
				else
gcf_warn "Non-hardened clang detected.  Use the clang ebuild from the"
gcf_warn "oiledmachine-overlay.  Not doing so can weaken the security."
				fi
			fi
			# Avoiding gcc/lto because of *serious* memory issues \
			# on 1 GIB per core machines.
		elif [[    ( -n "${CC_LTO}"  && "${CC_LTO}"  == "clang" ) \
			|| ( -n "${CXX_LTO}" && "${CXX_LTO}" == "clang++" ) ]] \
			&& [[ -n "${USE_GOLDLTO}" && "${USE_GOLDLTO}" == "1" ]] \
			&& gcf_is_clang_lto_allowed \
			&& gcf_met_clang_goldlto_requirement ; then
			_gcf_strip_lto_flags
			gcf_use_clang_goldlto
			if gcc --version | grep -q -e "Hardened" ; then
				if clang --version | grep -q -e "Hardened" ; then
				:;
				else
gcf_warn "Non-hardened clang detected.  Use the clang ebuild from the"
gcf_warn "oiledmachine-overlay.  Not doing so can weaken the security."
				fi
			fi
		elif [[    ( -n "${CC_LTO}"  && "${CC_LTO}"  == "gcc" ) \
			|| ( -n "${CXX_LTO}" && "${CXX_LTO}" == "g++" ) ]] \
			&& [[ -n "${USE_GOLDLTO}" && "${USE_GOLDLTO}" == "1" ]] \
			&& gcf_is_gcc_lto_allowed \
			&& gcf_met_gcc_goldlto_requirement ; then
			_gcf_strip_lto_flags
			gcf_use_gcc_goldlto
		elif [[    ( -n "${CC_LTO}"  && "${CC_LTO}"  == "gcc" ) \
			|| ( -n "${CXX_LTO}" && "${CXX_LTO}" == "g++" ) ]] \
			&& [[ -z "${USE_GOLDLTO}" || ( -n "${USE_GOLDLTO}" && "${USE_GOLDLTO}" != "1" ) ]] \
			&& gcf_is_gcc_lto_allowed \
			&& gcf_met_gcc_bfdlto_requirement ; then
			_gcf_strip_lto_flags
			gcf_use_gcc_bfdlto
		else
			gcf_warn "Did not meet LTO requirements."
		fi

		# It's okay to use GCC+BFD LTO or WPA-LTO for small packages,
		# but not okay to mix and switch LTO IR.
		if [[ ( -n "${DISABLE_GCC_LTO}" && "${DISABLE_GCC_LTO}" == "1" ) \
			&& ( "${CC}" =~ "gcc" || "${CXX}" =~ "g++" \
				|| ( -z "${CC}" && -z "${CXX}" ) ) ]] ; then
			# This should be disabled for packages that take
			# literally most of the day or more to complete with
			# GCC LTO.
			# Auto switching to ThinLTO for larger packages instead.
			_gcf_strip_lto_flags
		fi

		if [[ -n "${DISABLE_CLANG_LTO}" && "${DISABLE_CLANG_LTO}" == "1" \
			&& ( "${CC}" =~ "clang" || "${CXX}" =~ "clang++" ) ]] ; then
			_gcf_strip_lto_flags
		fi

		# Remove all LTO flags
		if [[ -n "${DISABLE_LTO}" && "${DISABLE_LTO}" == "1" ]] ; then
			gcf_info "Forced removal of -flto from *FLAGS"
			_gcf_strip_lto_flags
		fi
	fi

	if [[ "${CC_LTO}" =~ "clang" || "${CXX_LTO}" =~ "clang++" ]] && ! gcf_is_clang_lto_allowed ; then
		gcf_info "${CATEGORY}/${PN} is blacklisted from LTO.  Stripping LTO flags."
		_gcf_strip_lto_flags
	fi

	if [[ "${CC_LTO}" =~ "g++" || "${CXX_LTO}" =~ "g++" ]] && ! gcf_is_gcc_lto_allowed ; then
		gcf_info "${CATEGORY}/${PN} is blacklisted from LTO.  Stripping LTO flags."
		_gcf_strip_lto_flags
		if has lto ${IUSE_EFFECTIVE} && use lto ; then
			eerror "The lto USE flag must be disabled because of different IR."
			die
		fi
	fi

	export COMMON_FLAGS
	export CFLAGS
	export CXXFLAGS
	export FCFLAGS
	export FFLAGS
	export LDFLAGS

	if [[ "${CFLAGS}" =~ "-flto" ]] ; then
		export CC="${CC_LTO}"
		export CXX="${CXX_LTO}"
		[[ "${CC}" =~ "clang" || "${CXX}" =~ "clang++" ]] && gcf_use_clang
	fi

	export CC
	export CXX
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
			gcf_info "Converting -Ofast -> -O3"
			_gcf_replace_flag "-Ofast" "-O3"
		fi

		if [[ "${CFLAGS}" =~ "-ffast-math" ]] ; then
			gcf_info "Stripping -ffast-math"
			_gcf_replace_flag "-ffast-math" ""
		fi
	fi
}

gcf_use_Oz()
{
	if [[ ( "${CC}" == "clang" || "${CXX}" == "clang++" ) && "${CFLAGS}" =~ "-Os" ]] ; then
		gcf_info "Detected clang.  Converting -Os -> -Oz"
		_gcf_replace_flag "-Os" "-Oz"
	fi
	if [[ ( "${CC}" == "gcc" || "${CXX}" == "g++" || ( -z "${CC}" && -z "${CXX}" ) ) && "${CFLAGS}" =~ "-Oz" ]] ; then
		gcf_info "Detected gcc.  Converting -Oz -> -Os"
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
gcf_error "Set NCORES in the /etc/portage/make.conf.  Set the number of CPU cores"
gcf_error "not multiplying the threads per core."
		die
	fi
	if [[ -z "${MPROCS}" ]] ; then
gcf_error "Set MPROCS in the /etc/portage/make.conf.  2 is recommended."
		die
	fi
	local n
	if [[ "${MAKEOPTS_MODE:=normal}" == "normal" ]] ; then
		n=$(python -c "import math;print(int(round(${NCORES} * ${MPROCS})))")
		(( ${n} <= 0 )) && n=1
	elif [[ "${MAKEOPTS_MODE}" == "swappy" ]] ; then
		n=$((${NCORES} / 2))
		(( ${n} <= 0 )) && n=1
	elif [[ "${MAKEOPTS_MODE}" == "plain" ]] ; then
		n=${NCORES}
	elif [[ "${MAKEOPTS_MODE}" == "oom" \
		|| "${MAKEOPTS_MODE}" == "broken" \
		|| "${MAKEOPTS_MODE}" == "severe-swapping" ]] ; then
		n=1
	fi
	export MAKEOPTS="-j${n}"
	export MAKEFLAGS="-j${n}"
	gcf_info "MAKEOPTS_MODE is ${MAKEOPTS_MODE} (-j${n})"
	if [[ "${MAKEOPTS_MODE}" == "severe-swapping" ]] ; then
gcf_warn "Please close all web browsers and large programs to speed up"
gcf_warn "linking time."
	fi
}

gcf_strip_retpoline()
{
	if [[ -n "${DISABLE_RETPOLINE}" && "${DISABLE_RETPOLINE}" == "1" ]] ; then
			_gcf_replace_flag "-mindirect-branch=thunk" ""
			_gcf_replace_flag "-mretpoline" ""
			_gcf_replace_flag "-mindirect-branch-register" ""
			_gcf_replace_flag "-Wl,-z,retpolineplt" ""
	fi
}

pre_pkg_setup()
{
	gcf_info "Running pre_pkg_setup()"
	gcf_replace_flags
	gcf_lto
	gcf_retpoline_translate
	gcf_strip_no_plt
	gcf_strip_gcc_flags
	gcf_strip_z_retpolineplt
	gcf_strip_retpoline
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
gcf_error "Detected thread use.  Disable -Ofast or add DISABLE_FALLOW_STORE_DATA_RACES_CHECK=1 as a per-package envvar."
			die
		fi
	fi
	if [[ "${CFLAGS}" =~ "-fallow-store-data-races" && -e "${T}/build.log" ]] ; then
		if grep -q -E -e "(-lboost_thread|-lgthread|-lomp|-pthread|-lpthread|-ltbb)" "${T}/build.log" ; then
gcf_error "Detected thread use.  Disable -fallow-store-data-races or add DISABLE_FALLOW_STORE_DATA_RACES_CHECK=1 as a per-package envvar."
			die
		fi
	fi
}

gcf_verify_libraries_built_correctly()
{
	[[ -n "${SKIP_LIB_CORRECTNESS_CHECK}" && "${SKIP_LIB_CORRECTNESS_CHECK}" == "1" ]] && return
	gcf_info "Verifying static/shared library correctness"
	local p
	for p in $(find "${ED}" -type f -regextype 'posix-extended' -regex ".*\.(a|so)[0-9\.]*$") ; do
		if [[ ! -L "${p}" && -e "${p}" ]] ; then
			grep -q -e "https://bugs.gentoo.org/4411" "${p}" && continue
			if ! readelf -h "${p}" 2>/dev/null 1>/dev/null ; then
# static-libs linked with ThinLTO seems broken.
gcf_error "${p} is not built correctly.  You may try to do the following:"
gcf_error ""
gcf_error "  * Remove or change *FLAGS into default or non-optimized form"
gcf_error "  * Contact the ebuild maintainer to get it fixed"
gcf_error "  * Switch to GCC + BFD"
gcf_error "  * Switch to the gold linker if using clang"
gcf_error "  * Disable lto flags and USE flag if using clang"
gcf_error ""
gcf_error "You may pass SKIP_LIB_CORRECTNESS_CHECK=1 to skip this check."
				if [[ -d "/var/db/pkg/${CATEGORY}/${PN}-${PVR}" ]] ; then
# The installed package is not always built correctly.
# Example: static pkgA is broken and user does emerge -vuDN pkgB (parent package)
gcf_warn ""
gcf_warn "Detected a previous installation of =${CATEGORY}/${PN}-${PVR}"
gcf_warn "which may trick the emerge system that the prereq is met but"
gcf_warn "the installed package is actually broken.  If the broken"
gcf_warn "shared/static lib still exists, it could lead to configure time check"
gcf_warn "failures later on.  In other words, re-emerge the package built"
gcf_warn "correctly."
				fi
				die
			fi
		fi
	done
}

gcf_check_lto_ir_compatibility_before_compile() {
	[[ -n "${SKIP_IR_CHECK}" && "${SKIP_IR_CHECK}" == "1" ]] && return

	_gcf_ir_compat_before_with_flag() {
		gcf_error "You must strip -flto.  LLVM IR is incompatible with GCC GIMPLE IR for static-libs."
		gcf_error "You may add SKIP_IR_CHECK=1 to per-package package.env to skip this check."
		die
	}

	_gcf_ir_compat_before_with_use() {
		gcf_error "Detected static-libs USE ON.  The lto USE flag must be disabled because of different IR."
		gcf_error "You may add SKIP_IR_CHECK=1 to per-package package.env to skip this check."
		die
	}

	if [[ "${CFLAGS}" =~ "-flto" || "${CXXFLAGS}" =~ "-flto" ]] \
		&& has static-libs ${IUSE_EFFECTIVE} && use static-libs ; then
		if [[ -n "${CC_LTO}" && "${CC_LTO}" == "gcc" && ( -n "${CC}" && "${CC}" =~ "clang" ) ]] ; then
			_gcf_ir_compat_before_with_flag
		fi
		if [[ -n "${CC_LTO}" && "${CC_LTO}" == "g++" && ( -n "${CXX}" && "${CXX}" =~ "clang++" ) ]] ; then
			_gcf_ir_compat_before_with_flag
		fi

		if [[ -n "${CC_LTO}" && "${CC_LTO}" == "clang" && ( -z "${CC}" || ( "${CC}" =~ "gcc" ) ) ]] ; then
			_gcf_ir_compat_before_with_flag
		fi
		if [[ -n "${CC_LTO}" && "${CC_LTO}" == "clang++" && ( -z "${CXX}" || ( "${CXX}" =~ "g++" ) ) ]] ; then
			_gcf_ir_compat_before_with_flag
		fi

	fi
	if has lto ${IUSE_EFFECTIVE} && use lto \
		&& has static-libs ${IUSE_EFFECTIVE} && use static-libs ; then
		if [[ -n "${CC_LTO}" && "${CC_LTO}" == "gcc" && ( -n "${CC}" && "${CC}" =~ "clang" ) ]] ; then
			_gcf_ir_compat_before_with_use
		fi
		if [[ -n "${CC_LTO}" && "${CC_LTO}" == "g++" && ( -n "${CXX}" && "${CXX}" =~ "clang++" ) ]] ; then
			_gcf_ir_compat_before_with_use
		fi
		if [[ -n "${CC_LTO}" && "${CC_LTO}" == "clang" && ( -z "${CC}" || ( "${CC}" =~ "gcc" ) ) ]] ; then
			_gcf_ir_compat_before_with_use
		fi
		if [[ -n "${CC_LTO}" && "${CC_LTO}" == "clang++" && ( -z "${CXX}" || ( "${CXX}" =~ "g++" ) ) ]] ; then
			_gcf_ir_compat_before_with_use
		fi
	fi
}

gcf_check_lto_ir_compatibility() {
	[[ -n "${SKIP_IR_CHECK}" && "${SKIP_IR_CHECK}" == "1" ]] && return
	local L=($(find "${ED}" -type f -regextype 'posix-extended' -regex ".*\.a$" 2>/dev/null))

	_gcf_ir_compat_msg_with_flag() {
		gcf_error "Detected .a file(s):"
		echo "${L[@]}"
		gcf_error "You must strip -flto.  LLVM IR is incompatible with GCC GIMPLE IR for static-libs."
		gcf_error "You may add SKIP_IR_CHECK=1 to per-package package.env to skip this check."
		die
	}

	_gcf_ir_compat_msg_with_use() {
		gcf_error "Detected .a file(s):"
		echo "${L[@]}"
		gcf_error "The lto USE flag must be disabled because of different IR."
		gcf_error "You may add SKIP_IR_CHECK=1 to per-package package.env to skip this check."
		die
	}

	if [[ "${CFLAGS}" =~ "-flto" || "${CXXFLAGS}" =~ "-flto" ]] \
		&& (( ${#L[@]} > 0 )) ; then
		if [[ -n "${CC_LTO}" && "${CC_LTO}" == "gcc" && ( -n "${CC}" && "${CC}" =~ "clang" ) ]] ; then
			_gcf_ir_compat_msg_with_flag
		fi
		if [[ -n "${CC_LTO}" && "${CC_LTO}" == "g++" && ( -n "${CXX}" && "${CXX}" =~ "clang++" ) ]] ; then
			_gcf_ir_compat_msg_with_flag
		fi

		if [[ -n "${CC_LTO}" && "${CC_LTO}" == "clang" && ( -z "${CC}" || ( "${CC}" =~ "gcc" ) ) ]] ; then
			_gcf_ir_compat_msg_with_flag
		fi
		if [[ -n "${CC_LTO}" && "${CC_LTO}" == "clang++" && ( -z "${CXX}" || ( "${CXX}" =~ "g++" ) ) ]] ; then
			_gcf_ir_compat_msg_with_flag
		fi
	fi
	# Check for things like libpython2.7.a
	if has lto ${IUSE_EFFECTIVE} && use lto \
		&& (( ${#L[@]} > 0 )) ; then
		if [[ -n "${CC_LTO}" && "${CC_LTO}" == "gcc" && ( -n "${CC}" && "${CC}" =~ "clang" ) ]] ; then
			_gcf_ir_compat_msg_with_use
		fi
		if [[ -n "${CC_LTO}" && "${CC_LTO}" == "g++" && ( -n "${CXX}" && "${CXX}" =~ "clang++" ) ]] ; then
			_gcf_ir_compat_msg_with_use
		fi
		if [[ -n "${CC_LTO}" && "${CC_LTO}" == "clang" && ( -z "${CC}" || ( "${CC}" =~ "gcc" ) ) ]] ; then
			_gcf_ir_compat_msg_with_use
		fi
		if [[ -n "${CC_LTO}" && "${CC_LTO}" == "clang++" && ( -z "${CXX}" || ( "${CXX}" =~ "g++" ) ) ]] ; then
			_gcf_ir_compat_msg_with_use
		fi
	fi
}

pre_src_compile() {
	gcf_check_lto_ir_compatibility_before_compile
}

pre_src_install() {
	gcf_info "Running pre_src_install()"
	gcf_check_Ofast_safety
}

post_src_install() {
	gcf_info "Running post_src_install()"
#	gcf_verify_libraries_built_correctly
	gcf_check_lto_ir_compatibility
}
