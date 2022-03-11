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

GCF_LIST_VERSION_MIN=3
GCF_LLVM_MAX=14
GCF_LLVM_MIN=11

gcf_info() {
	echo -e ">>> [GCF] ${@}"
}

gcf_warn() {
	echo -e ">>> \e[30m\e[43m[GCF]\e[0m ${@}"
}

gcf_error() {
	echo -e ">>> \e[30m\e[41m[GCF]\e[0m ${@}"
}

gcf_append_ldflags() {
	export LDFLAGS="${LDFLAGS} ${@}"
	export CGO_LDFLAGS="${CGO_LDFLAGS} ${@}"
}

gcf_print_flags() {
	[[ -z "${GCF_SHOW_FLAGS}" || "${GCF_SHOW_FLAGS}" != "1" ]] && return
	gcf_info "COMMON_FLAGS=${COMMON_FLAGS}"
	gcf_info "CFLAGS=${CFLAGS}"
	gcf_info "CXXFLAGS=${CXXFLAGS}"
	gcf_info "FCFLAGS=${FCFLAGS}"
	gcf_info "FFLAGS=${FFLAGS}"
	gcf_info "LDFLAGS=${LDFLAGS}"
	gcf_info "CGO_CFLAGS=${CGO_CFLAGS}"
	gcf_info "CGO_CXXFLAGS=${CGO_CXXFLAGS}"
	gcf_info "CGO_LDFLAGS=${CGO_LDFLAGS}"
	gcf_info "DIST_MAKE=${DIST_MAKE}"
}

gcf_append_flags() {
	export COMMON_FLAGS="${COMMON_FLAGS} ${@}"
	export CFLAGS="${CFLAGS} ${@}"
	export CXXFLAGS="${CXXFLAGS} ${@}"
	export FCFLAGS="${FCFLAGS} ${@}"
	export FFLAGS="${FFLAGS} ${@}"
	export LDFLAGS="${LDFLAGS} ${@}"
	export CGO_CFLAGS="${CGO_CFLAGS} ${@}"
	export CGO_CXXFLAGS="${CGO_CXXFLAGS} ${@}"
	export CGO_LDFLAGS="${CGO_LDFLAGS} ${@}"

	# For the perl-module.eclass
	export DIST_MAKE="${DIST_MAKE} ${@}"
}

_gcf_replace_flag() {
	local i="${1}"
	local o="${2}"
	export COMMON_FLAGS=$(echo "${COMMON_FLAGS}" | sed -r -e "s/${i}/${o}/g")
	export CFLAGS=$(echo "${CFLAGS}" | sed -e "s|${i}|${o}|g")
	export CXXFLAGS=$(echo "${CXXFLAGS}" | sed -e "s|${i}|${o}|g")
	export FCFLAGS=$(echo "${FCFLAGS}" | sed -e "s|${i}|${o}|g")
	export FFLAGS=$(echo "${FFLAGS}" | sed -e "s|${i}|${o}|g")
	export LDFLAGS=$(echo "${LDFLAGS}" | sed -r -e "s/(^| )${i}/${o}/g")
	export CGO_CFLAGS=$(echo "${CGO_CFLAGS}" | sed -e "s|${i}|${o}|g")
	export CGO_CXXFLAGS=$(echo "${CGO_CXXFLAGS}" | sed -e "s|${i}|${o}|g")
	export CGO_LDFLAGS=$(echo "${CGO_LDFLAGS}" | sed -r -e "s/(^| )${i}/${o}/g")

	# For the perl-module.eclass
	export DIST_MAKE=$(echo "${DIST_MAKE}" | sed -r -e "s/${i}/${o}/g")
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
	if [[ "${CC}" == "clang" || "${CXX}" == "clang++" ]] \
		&& [[ "${CFLAGS}" =~ "-mindirect-branch=thunk" \
			|| "${CXXFLAGS}" =~ "-mindirect-branch=thunk" ]] ; then
		# implicit
		_gcf_translate_to_clang_retpoline
	elif [[ ( -z "${CC}" && -z "${CXX}" ) || "${CC}" == "gcc" || "${CXX}" == "g++" ]] \
		&& [[ "${CFLAGS}" =~ "-mretpoline" \
			|| "${CXXFLAGS}" =~ "-mretpoline" ]] ; then
		# implicit
		_gcf_translate_to_gcc_retpoline
	fi
}

gcf_strip_no_inline() {
	if [[ "${CFLAGS}" =~ "-fno-inline" \
		&& ( "${CFLAGS}" =~ ("-Ofast"|"-O2"|"O3") \
			|| ( "${DISABLE_NO_INLINE}" == "1" ) \
		) ]] ; then
		gcf_info "Removing -fno-inline from *FLAGS"
		_gcf_replace_flag "-fno-inline" ""
	fi
}

gcf_strip_no_plt() {
	if [[ "${DISABLE_FNO_PLT}" == "1" ]] ; then
		gcf_info "Removing -fno-plt from *FLAGS"
		_gcf_replace_flag "-fno-plt" ""
	fi
}

gcf_strip_gcc_flags() {
	local gcc_flags=(
		-fopt-info-inline
		-fopt-info-loop
		-fopt-info-vec
		-fprefetch-loop-arrays
		-frename-registers
		-freorder-blocks-algorithm=simple
		-freorder-blocks-algorithm=stc
	)

	if [[ "${DISABLE_GCC_FLAGS}" == "1" \
		|| "${CC}" == "clang" ]] ; then
		gcf_info "Removing ${gcc_flags[@]} from *FLAGS"
		for f in ${gcc_flags[@]} ; do
			_gcf_replace_flag "${f}" ""
		done
	fi
}

gcf_strip_z_retpolineplt() {
	if [[ "${DISABLE_Z_RETPOLINEPLT}" == "1" ]] ; then
		gcf_info "Removing -Wl,-z,retpolineplt from LDFLAGS"
		export LDFLAGS=$(echo "${LDFLAGS}" | sed -e "s|-Wl,-z,retpolineplt||g")
		export CGO_LDFLAGS=$(echo "${CGO_LDFLAGS}" | sed -e "s|-Wl,-z,retpolineplt||g")
	fi
	if [[ -z "${USE_THINLTO}" || "${USE_THINLTO}" != "1" ]] ; then
		_gcf_replace_flag "-Wl,-z,retpolineplt" ""
	fi
}

gcf_met_clang_thinlto_requirement() {
	local llvm_slots=($(seq ${GCF_LLVM_MAX} -1 ${GCF_LLVM_MIN}))
	has_version "sys-devel/llvm" || return 1

	local found=1
	for s in ${llvm_slots[@]} ; do
		if ( has_version "sys-devel/llvm:${s}" \
			&& has_version "sys-devel/clang:${s}" \
			&& has_version ">=sys-devel/lld-${s}" ) ; then
			(( ${s} <= ${LLVM_MAX_SLOT:=${GCF_LLVM_MAX}} )) && found=0
		fi
	done
	return ${found}
}

gcf_met_clang_goldlto_requirement() {
	local llvm_slots=($(seq ${GCF_LLVM_MAX} -1 ${GCF_LLVM_MIN}))
	has_version "sys-devel/llvm" || return 1

	local found=1
	for s in ${llvm_slots[@]} ; do
		if ( ( has_version "sys-devel/llvm:${s}[gold]" || has_version "sys-devel/llvm:${s}[binutils-plugin]" ) \
			&& has_version "sys-devel/binutils[plugins,gold]" \
			&& has_version ">=sys-devel/llvmgold-${s}" ) ; then
			(( ${s} <= ${LLVM_MAX_SLOT:=${GCF_LLVM_MAX}} )) && found=0
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

gcf_met_clang_bfdlto_requirement() {
	has_version "sys-devel/clang" || return 1

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

gcf_is_clang_ready() {
	which clang 2>/dev/null 1>/dev/null || return 1
	which clang --help 2>&1 | grep -q -e "symbol lookup error" || return 1
	return 0
}

gcf_is_clang_slot_ready() {
	local slot="${1}"
	which clang-${slot} 2>/dev/null 1>/dev/null || return 1
	which clang-${slot} --help 2>&1 | grep -q -e "symbol lookup error" || return 1
	return 0
}

gcf_is_cc_lto_ready() {
	which "${CC_LTO}" 2>/dev/null 1>/dev/null || return 1
	which "${CC_LTO}" --help 2>&1 | grep -q -e "symbol lookup error" || return 1
	return 0
}
gcf_use_clang() {
	gcf_is_clang_ready || return
	gcf_info "Switching to clang"
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
}

gcf_use_thinlto() {
	gcf_info "Switching to ThinLTO"
	LDFLAGS="${LDFLAGS} -fuse-ld=lld"
	gcf_append_flags "-flto=thin"
}

gcf_use_clang_goldlto() {
	gcf_info "Switching to Clang Gold LTO"
	LDFLAGS="${LDFLAGS} -fuse-ld=gold"
	gcf_append_flags "-flto=full"
}

gcf_use_gcc_goldlto() {
	gcf_info "Switching to GCC Gold LTO"
	LDFLAGS="${LDFLAGS} -fuse-ld=gold"
	gcf_append_flags "-flto"
}

gcf_use_gcc_bfdlto() {
	gcf_info "Switching to GCC BFD LTO"
	LDFLAGS="${LDFLAGS} -fuse-ld=bfd"
	gcf_append_flags "-flto"
}

gcf_use_clang_bfdlto() {
	gcf_info "Switching to Clang BFD LTO"
	LDFLAGS="${LDFLAGS} -fuse-ld=bfd"
	gcf_append_flags "-flto=full"
}

gcf_is_package_no_lto() {
	local emerge_set
	local p
	local type
	for emerge_set in system world ; do
		for type in no-lto ; do
			local L=($(cat /etc/portage/emerge-${emerge_set}-${type}.lst))
			for p in ${L[@]} ; do
				[[ "${p}" == "${CATEGORY}/${PN}" ]] && return 0
			done
		done
	done
	return 1
}

gcf_is_package_missing_in_lto_lists() {
	local emerge_set
	local p
	local type
	for emerge_set in system world ; do
		for type in lto-agnostic lto-restricted no-data no-lto ; do
			local L=($(cat /etc/portage/emerge-${emerge_set}-${type}.lst))
			for p in ${L[@]} ; do
				[[ "${p}" == "${CATEGORY}/${PN}" ]] && return 1
			done
		done
	done
	return 0
}

gcf_is_package_in_lto_blacklists() {
	local emerge_set
	local p
	for emerge_set in system world ; do
		local L=($(cat /etc/portage/emerge-${emerge_set}-no-lto.lst))
		for p in ${L[@]} ; do
			[[ "${p}" == "${CATEGORY}/${PN}" ]] && return 0
		done
	done
	return 1
}

gcf_is_package_lto_agnostic() {
	local emerge_set
	local p
	for emerge_set in system world ; do
		local L=($(cat /etc/portage/emerge-${emerge_set}-lto-agnostic.lst))
		for p in ${L[@]} ; do
			[[ "${p}" == "${CATEGORY}/${PN}" ]] && return 0
		done
	done
	return 1
}

gcf_is_package_lto_agnostic_world() {
	local emerge_set
	local p
	local L=($(cat /etc/portage/emerge-world-lto-agnostic.lst))
	for p in ${L[@]} ; do
		[[ "${p}" == "${CATEGORY}/${PN}" ]] && return 0
	done
	return 1
}

gcf_is_package_lto_agnostic_system() {
	local emerge_set
	local p
	local L=($(cat /etc/portage/emerge-system-lto-agnostic.lst))
	for p in ${L[@]} ; do
		[[ "${p}" == "${CATEGORY}/${PN}" ]] && return 0
	done
	return 1
}

gcf_is_package_lto_restricted() {
	local emerge_set
	local p
	for emerge_set in system world ; do
		local L=($(cat /etc/portage/emerge-${emerge_set}-lto-restricted.lst))
		for p in ${L[@]} ; do
			[[ "${p}" == "${CATEGORY}/${PN}" ]] && return 0
		done
	done
	return 1
}

gcf_is_package_lto_restricted_world() {
	local emerge_set
	local p
	local L=($(cat /etc/portage/emerge-world-lto-restricted.lst))
	for p in ${L[@]} ; do
		[[ "${p}" == "${CATEGORY}/${PN}" ]] && return 0
	done
	return 1
}

gcf_is_package_lto_restricted_system() {
	local emerge_set
	local p
	local L=($(cat /etc/portage/emerge-world-lto-restricted.lst))
	for p in ${L[@]} ; do
		[[ "${p}" == "${CATEGORY}/${PN}" ]] && return 0
	done
	return 1
}

gcf_is_package_lto_unknown() {
	local emerge_set
	local p
	for emerge_set in system world ; do
		local L=($(cat /etc/portage/emerge-${emerge_set}-no-data.lst))
		for p in ${L[@]} ; do
			[[ "${p}" == "${CATEGORY}/${PN}" ]] && return 0
		done
	done
	return 1
}

gcf_is_clang_cfi() {
	[[ "${USE_CLANG_CFI}" == "1" ]] && return 0
	return 1
}

gcf_is_ubsan() {
	[[ "${LINK_UBSAN}" == "1" ]] && return 0
	return 1
}

gcf_is_skipless() {
	[[ "${USE_CLANG_CFI}" == "1" ]] && return 1
	gcf_is_ubsan && return 1

	if [[ "${FORCE_PREFETCH_LOOP_ARRAYS}" == "1" ]] ; then
		return 0
	elif [[ "${GCF_IS_SKIPLESS}" == "1" ]] ; then
		return 0
	fi
	return 1
}

gcf_is_lto_skippable() {
	local emerge_set
	local p
	for emerge_set in system world ; do
		local L=($(cat /etc/portage/emerge-${emerge_set}-lto-skip.lst))
		for p in ${L[@]} ; do
			[[ "${p}" == "${CATEGORY}/${PN}" ]] && return 0
		done
	done
	return 1
}

gcf_is_cfi_skippable() {
	local emerge_set
	local p
	for emerge_set in system world ; do
		local L=($(cat /etc/portage/emerge-cfi-skip.lst))
		for p in ${L[@]} ; do
			[[ "${p}" == "${CATEGORY}/${PN}" ]] && return 0
		done
	done
	return 1
}

gcf_is_cfiable() {
	if grep -q -e "${CATEGORY}/${PN}:" /etc/portage/emerge-{cfi-system,cfi-world}.lst 2>/dev/null ; then
		return 0
	fi
	return 1
}

gcf_is_cfiable_world() {
	if grep -q -e "${CATEGORY}/${PN}:" /etc/portage/emerge-cfi-world.lst 2>/dev/null ; then
		return 0
	fi
	return 1
}

gcf_is_cfiable_system() {
	if grep -q -e "${CATEGORY}/${PN}:" /etc/portage/emerge-cfi-system.lst 2>/dev/null ; then
		return 0
	fi
	return 1
}

get_cfi_flags() {
	if grep -q -e "${CATEGORY}/${PN}:.*" /etc/portage/emerge-{cfi-system,cfi-world}.lst ; then
		grep -e "${CATEGORY}/${PN}:.*" /etc/portage/emerge-{cfi-system,cfi-world}.lst | head -n 1 | cut -f 2- -d ":" | cut -f 2 -d ":"
	fi
}

get_cfi_flags_world() {
	if grep -q -e "${CATEGORY}/${PN}:.*" /etc/portage/emerge-cfi-world.lst ; then
		grep -e "${CATEGORY}/${PN}:.*" /etc/portage/emerge-cfi-world.lst | head -n 1 | cut -f 2- -d ":" | cut -f 2 -d ":"
	fi
}

get_cfi_flags_system() {
	if grep -q -e "${CATEGORY}/${PN}:.*" /etc/portage/emerge-cfi-system.lst ; then
		grep -e "${CATEGORY}/${PN}:.*" /etc/portage/emerge-cfi-system.lst | head -n 1 | cut -f 2- -d ":" | cut -f 2 -d ":"
	fi
}

gcf_is_clang_cfi_ready() {
	local llvm_slots=($(seq ${GCF_LLVM_MAX} -1 ${GCF_LLVM_MIN}))
	has_version "sys-devel/llvm" || return 1

	if [[ "${CC_LTO}" == "clang" && "${CXX_LTO}" == "clang++" ]] ; then
		:;
	else
gcf_error "CC_LTO=clang and CXX_LTO=clang++ must be the systemwide default."
gcf_error "Disabling Clang CFI support."
		return 1
	fi

	local found=1
	for s in ${llvm_slots[@]} ; do
		if (       has_version "sys-devel/clang:${s}" \
			&& has_version "=sys-devel/clang-runtime-${s}*[compiler-rt,sanitize]" \
			&& has_version "=sys-libs/compiler-rt-${s}*" \
			&& ( \
				( has_version ">=sys-devel/lld-${s}" ) \
					|| \
				( ( has_version "sys-devel/llvm:${s}[gold]" \
					|| has_version "sys-devel/llvm:${s}[binutils-plugin]" ) \
		                        && has_version "sys-devel/binutils[plugins,gold]" \
                		        && has_version ">=sys-devel/llvmgold-${s}" ) \
			) \
			&& has_version "=sys-libs/compiler-rt-sanitizers-${s}*[cfi,ubsan]" \
			&& has_version "sys-devel/llvm:${s}" \
			&& gcf_is_clang_slot_ready "${s}" \
		) ; then
			(( ${s} <= ${LLVM_MAX_SLOT:=${GCF_LLVM_MAX}} )) && found=0
		fi
	done
	return ${found}
}

gcf_check_emerge_list_ready() {
	if ! find /etc/portage/emerge*.lst 2>/dev/null 1>/dev/null ; then
gcf_error "Missing lto lists.  Use gen_pkg_lists.sh to generate them"
		die
	else
		if ! grep -q -e "# version " $(find /etc/portage/emerge*.lst | head -n1) ; then
gcf_error "The generated list is missing the version header.  Use the"
gcf_error "gen_pkg_lists.sh to generate them."
			die
		fi

		local gcf_list_ver=$(grep -e "# version " /etc/portage/emerge*.lst \
			| head -n 1 | cut -f 2- -d ":" | cut -f 3 -d " ")
		if (( ${gcf_list_ver} < ${GCF_LIST_VERSION_MIN} )) ; then
gcf_error "The generated list version header is too old.  Use the"
gcf_error "gen_pkg_lists.sh to generate a compatible list."
			die
		fi
	fi
}

gcf_lto() {
	[[ "${DISABLE_GCF_LTO}" == "1" ]] && return

	_gcf_strip_lto_flags() {
		local flag_names=(
			COMMON_FLAGS
			CFLAGS
			CXXFLAGS
			FCFLAGS
			FFLAGS
			LDFLAGS
			CGO_CFLAGS
			CGO_CXXFLAGS
			CGO_LDFLAGS
			DIST_MAKE
		)
		local f
		for f in ${flag_names[@]} ; do
			eval "export ${f}=\$("\
"echo \"\$${f}\" "\
"  |  sed -r -e  's/-flto( |\$)//g' "\
"            -e \"s/-flto=[0-9]+//g\" "\
"            -e \"s/-flto=(auto|jobserver|thin|full)//g\" "\
"            -e \"s/-fuse-ld=(lld|bfd|gold)//g\" "\
"                                           )"
		done
	}

	if gcf_is_lto_skippable ; then
		# For packages that use compiler checks but don't install
		# binaries.
gcf_info "Skipping package for LTO"
		if [[ -z "${CC}" || -z "${CXX}" ]] ; then
			export CC="${CC_LIBC:=gcc}"
			export CXX="${CXX_LIBC:=g++}"
		fi
		_gcf_strip_lto_flags
		[[ "${CC}" == "clang" || "${CXX}" == "clang++" ]] && gcf_use_clang
		return
	fi

	if ! has_version "sys-devel/binutils[plugins]" ; then
gcf_warn "The plugins USE flag must be enabled in sys-devel/binutils for LTO to work."
	fi

	gcf_check_emerge_list_ready

	# New packages do not get LTO initially because it simplifies this script.
	# New packages from the no-data list will get moved into agnostic, no-lto,
	#   or lto-restricted list via generator script.
	if gcf_is_package_in_lto_blacklists \
		|| gcf_is_package_lto_unknown \
		|| gcf_is_package_missing_in_lto_lists ; then
		# Design notes:
		# The dev-perl/* packages are known to fail.  It was decided
		# that auto enabled LTO for temp packages will not be supported
		# because this script may rely on grepping the emerge*cfi*lst
		# parts.  Also, if auto enabled, this may cause these packages
		# to be unCFIed AND LTOed which may be a security risk.
		gcf_error "Stripping LTO flags for blacklisted, missing install file list"
		_gcf_strip_lto_flags
		if has lto ${IUSE_EFFECTIVE} && use lto ; then
gcf_error "Possible IR incompatibility.  Please disable the lto USE flag, or"
gcf_error "re-categorize or add the package to /etc/portage/emerge*lst for LTO"
gcf_error "(and CFI)."
			die
		fi
	fi

	if gcf_is_package_lto_restricted_world ; then
gcf_warn "This package requires -flto stripped and lto USE disabled if there is"
gcf_warn "a future hard dependency on a specific compiler differing from"
gcf_warn "CC_LTO=${CC_LTO} when linking static-libs."
	fi

	if has lto ${IUSE_EFFECTIVE} && [[ "${DISABLE_LTO_STRIPPING}" != "1" ]] ; then
		# Prioritize the lto USE flag over make.conf/package.env.
		# Some build systems are designed to ignore *FLAGS provided by \
		#   make.conf/package.env.
		# Some packages want to manipulate LTO -O* flags.
gcf_info "Removing -flto from *FLAGS.  Using the USE flag setting instead."
		_gcf_strip_lto_flags
	fi

	if [[ "${CFLAGS}" =~ "-flto" ]] || ( has lto ${IUSE_EFFECTIVE} && use lto ) ; then
		local pkg_flags=$(get_cfi_flags)

		if [[ "${USE_CLANG}" == "1" ]] && ! gcf_is_clang_ready ; then
gcf_info "The clang compiler is broken and needs to be recompiled."
		fi

		if [[ "${USE_CLANG}" == "1" ]] && gcf_is_clang_ready ; then
			CC="clang"
			CXX="clang++"
		elif [[ "${USE_GCC}" == "1" ]] ; then
			CC="gcc"
			CXX="g++"
		elif [[ "${USE_CLANG_CFI_AT_SYSTEM}" == "1" ]] \
			&& gcf_is_package_lto_agnostic_system \
			&& gcf_is_clang_cfi \
			&& gcf_is_clang_cfi_ready \
			&& [[ "${DISABLE_CFI_AT_SYSTEM}" != "1" ]] ; then
			CC="clang"
			CXX="clang++"
		elif gcf_is_package_lto_agnostic_world \
			&& gcf_is_clang_cfi \
			&& gcf_is_clang_cfi_ready \
			&& [[ ! ( "${pkg_flags}" =~ "A" ) ]] ; then
			CC="clang"
			CXX="clang++"
		elif gcf_is_skipless ; then
			gcf_info "Detected skipless"
			CC="gcc"
			CXX="g++"
		elif gcf_is_package_lto_agnostic_system ; then
			# Disallow compiler autodetect
			CC="${CC_LIBC:=gcc}"
			CXX="${CXX_LIBC:=g++}"
		elif ( gcf_is_package_lto_restricted_world || gcf_is_package_lto_agnostic_world ) && gcf_is_cc_lto_ready ; then
			CC="${CC_LTO}"
			CXX="${CXX_LTO}"
		else
			CC="${CC_LIBC:=gcc}"
			CXX="${CXX_LIBC:=g++}"
		fi
		[[ "${CC}" == "clang" || "${CXX}" == "clang++" ]] && gcf_use_clang
	fi
	[[ -z "${CC}" || -z "${CXX}" ]] && gcf_is_ubsan && gcf_use_clang

	local linker=""
	if gcf_is_package_in_lto_blacklists \
		|| gcf_is_package_lto_unknown \
		|| gcf_is_package_missing_in_lto_lists ; then
		linker="no-lto"
	elif gcf_is_package_lto_agnostic \
		|| gcf_is_package_lto_restricted ; then
		if [[ "${CC}" == "clang" && "${USE_THINLTO}" == "1" ]] ; then
			linker="thinlto"
		elif [[ "${CC}" == "clang" && "${USE_GOLDLTO}" == "1" ]] ; then
			linker="clang-goldlto"
		elif [[ "${CC}" == "gcc" && "${USE_GOLDLTO}" == "1" ]] ; then
			linker="gcc-goldlto"
		elif [[ "${CC}" == "clang" ]] ; then
			linker="clang-bfdlto"
		elif [[ "${CC}" == "gcc" ]] ; then
			linker="gcc-bfdlto"
		fi
	fi

	if gcf_is_package_lto_agnostic && gcf_is_skipless ; then
		if [[ "${USE_GOLDLTO}" == "1" ]] ; then
			linker="gcc-goldlto"
		else
			linker="gcc-bfdlto"
		fi
	elif ! gcf_is_package_lto_agnostic && gcf_is_skipless ; then
		linker="no-lto"
	fi

	if [[ "${CFLAGS}" =~ "-flto" || "${CXXFLAGS}" =~ "-flto" ]] ; then
		# A reminder that you can only use one LTO implementation as the
		# default systemwide.

		if [[ "${linker}" == "thinlto" ]] \
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
		elif [[ "${linker}" == "clang-goldlto" ]] \
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
		elif [[ "${linker}" == "gcc-goldlto" ]] \
			&& gcf_met_gcc_goldlto_requirement ; then
			_gcf_strip_lto_flags
			gcf_use_gcc_goldlto
		elif [[ "${linker}" == "gcc-bfdlto" ]] \
			&& gcf_met_gcc_bfdlto_requirement ; then
			_gcf_strip_lto_flags
			gcf_use_gcc_bfdlto
		elif [[ "${linker}" == "clang-bfdlto" ]] \
			&& gcf_met_clang_bfdlto_requirement ; then
			_gcf_strip_lto_flags
			gcf_use_clang_bfdlto
		elif [[ "${linker}" == "no-lto" ]] ; then
			:;
		else
			gcf_warn "Did not meet LTO requirements."
			if [[ "${ALLOW_LTO_REQUIREMENTS_NOT_MET_TRACKING}" == "1" ]] ; then
echo "${CATEGORY}/${PN}" >> /etc/portage/emerge-requirements-not-met.lst
			fi
		fi

		# It's okay to use GCC+BFD LTO or WPA-LTO for small packages,
		# but not okay to mix and switch LTO IR.
		if [[ "${DISABLE_GCC_LTO}" == "1" \
			&& ( "${CC}" == "gcc" || "${CXX}" == "g++" \
				|| ( -z "${CC}" && -z "${CXX}" ) ) ]] ; then
			# This should be disabled for packages that take
			# literally most of the day or more to complete with
			# GCC LTO.
			# Auto switching to ThinLTO for larger packages instead.
			gcf_info "Forced removal of -flto from *FLAGS for gcc"
			_gcf_strip_lto_flags
		fi

		if [[ "${DISABLE_CLANG_LTO}" == "1" \
			&& ( "${CC}" == "clang" || "${CXX}" == "clang++" ) ]] ; then
			gcf_info "Forced removal of -flto from *FLAGS for clang"
			_gcf_strip_lto_flags
		fi

		# Remove all LTO flags
		if [[ "${DISABLE_LTO}" == "1" ]] ; then
			gcf_info "Forced removal of -flto from *FLAGS"
			_gcf_strip_lto_flags
		fi
	fi

	export CC
	export CXX
	export COMMON_FLAGS
	export CFLAGS
	export CXXFLAGS
	export FCFLAGS
	export FFLAGS
	export LDFLAGS
	export CGO_CFLAGS
	export CGO_CXXFLAGS
	export CGO_LDFLAGS
	export DIST_MAKE
}

gcf_replace_flags()
{
	if [[ "${OPT_LEVEL}" =~ ("-O0"|"-O1"|"-O2"|"-O3"|"-O4"|"-Ofast"|"-Oz"|"-Os") ]] ; then
		_gcf_replace_flag "${DEFAULT_OPT_LEVEL}" "${OPT_LEVEL}"
	fi
}

gcf_strip_lossy()
{
	if [[ "${I_WANT_LOSSLESS}" == "1" ]] ; then
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
	[[ "${FORCE_OS}" == "1" ]] && return
	[[ "${FORCE_OZ}" == "1" ]] && return
	if [[ ( "${CC}" == "clang" || "${CXX}" == "clang++" ) && "${CFLAGS}" =~ "-Os" ]] ; then
		gcf_info "Detected clang.  Converting -Os -> -Oz"
		_gcf_replace_flag "-Os" "-Oz"
	fi
	if [[ ( "${CC}" == "gcc" || "${CXX}" == "g++" || ( -z "${CC}" && -z "${CXX}" ) ) && "${CFLAGS}" =~ "-Oz" ]] ; then
		gcf_info "Detected gcc.  Converting -Oz -> -Os"
		_gcf_replace_flag "-Oz" "-Os"
	fi
}

gcf_has_static_lib() {
	if gcf_is_package_lto_restricted || gcf_is_package_no_lto ; then
		return 0
	fi
	return 1
}

gcf_bolt_prepare() {
	if ( gcf_has_static_lib && [[ "${GCF_BOLT_PREP}" == "1" ]] ) || [[ "${BOLT_OPTIMIZED_APP}" == "1" ]] ; then
		# See https://github.com/llvm/llvm-project/tree/main/bolt#input-binary-requirements for status
		_gcf_replace_flag "-freorder-blocks-and-partition" ""
		_gcf_replace_flag "-freorder-blocks-algorithm=simple" ""
		_gcf_replace_flag "-freorder-blocks-algorithm=stc" ""
		gcf_append_flags -fno-reorder-blocks-and-partition
	fi
}

gcf_replace_freorder_blocks_algorithm()
{
	if [[ "${FREORDER_BLOCKS_ALGORITHM}" == "stc" ]] ; then
		_gcf_replace_flag "-freorder-blocks-algorithm=simple" "-freorder-blocks-algorithm=stc"
	fi
}

_gcf_adjust_makeopts_gcc() {
	if [[ "${MAKEOPTS_MODE_GCC:=normal}" == "normal" ]] ; then
		n=$(python -c "import math;print(int(round(${NCORES} * ${MPROCS})))")
		(( ${n} <= 0 )) && n=1
	elif [[ "${MAKEOPTS_MODE_GCC}" == "swappy" ]] ; then
		n=$((${NCORES} / 2))
		(( ${n} <= 0 )) && n=1
	elif [[ "${MAKEOPTS_MODE_GCC}" == "plain" ]] ; then
		n=${NCORES}
	elif [[ "${MAKEOPTS_MODE_GCC}" == "oom" \
		|| "${MAKEOPTS_MODE_GCC}" == "broken" \
		|| "${MAKEOPTS_MODE_GCC}" == "severe-swapping" ]] ; then
		n=1
	fi
}

_gcf_adjust_makeopts_clang() {
	if [[ "${MAKEOPTS_MODE_CLANG:=normal}" == "normal" ]] ; then
		n=$(python -c "import math;print(int(round(${NCORES} * ${MPROCS})))")
		(( ${n} <= 0 )) && n=1
	elif [[ "${MAKEOPTS_MODE_CLANG}" == "swappy" ]] ; then
		n=$((${NCORES} / 2))
		(( ${n} <= 0 )) && n=1
	elif [[ "${MAKEOPTS_MODE_CLANG}" == "plain" ]] ; then
		n=${NCORES}
	elif [[ "${MAKEOPTS_MODE_CLANG}" == "oom" \
		|| "${MAKEOPTS_MODE_CLANG}" == "broken" \
		|| "${MAKEOPTS_MODE_CLANG}" == "severe-swapping" ]] ; then
		n=1
	fi
}

_gcf_adjust_makeopts_any() {
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
}

has_defined_makeopts_gcc() {
	if [[ "${MAKEOPTS_MODE_GCC}" == "normal" ]] ; then
		return 0
	elif [[ "${MAKEOPTS_MODE_GCC}" == "swappy" ]] ; then
		return 0
	elif [[ "${MAKEOPTS_MODE_GCC}" == "plain" ]] ; then
		return 0
	elif [[ "${MAKEOPTS_MODE_GCC}" == "oom" \
		|| "${MAKEOPTS_MODE_GCC}" == "broken" \
		|| "${MAKEOPTS_MODE_GCC}" == "severe-swapping" ]] ; then
		return 0
	fi
	return 1
}

has_defined_makeopts_clang() {
	if [[ "${MAKEOPTS_MODE_CLANG}" == "normal" ]] ; then
		return 0
	elif [[ "${MAKEOPTS_MODE_CLANG}" == "swappy" ]] ; then
		return 0
	elif [[ "${MAKEOPTS_MODE_CLANG}" == "plain" ]] ; then
		return 0
	elif [[ "${MAKEOPTS_MODE_CLANG}" == "oom" \
		|| "${MAKEOPTS_MODE_CLANG}" == "broken" \
		|| "${MAKEOPTS_MODE_CLANG}" == "severe-swapping" ]] ; then
		return 0
	fi
	return 1
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
	local n=1
	if [[ -z "${CC}" ]] ; then
		CC="gcc"
		CXX="g++"
	fi
	if [[ "${CC}" == "gcc" ]] && has_defined_makeopts_gcc ; then
		_gcf_adjust_makeopts_gcc
	elif [[ "${CC}" == "clang" ]] && has_defined_makeopts_clang ; then
		_gcf_adjust_makeopts_clang
	else
		_gcf_adjust_makeopts_any
	fi
	export MAKEOPTS="-j${n}"
	export MAKEFLAGS="-j${n}"
	gcf_info "MAKEOPTS_MODE is ${MAKEOPTS_MODE} (-j${n})"
	if [[ "${MAKEOPTS_MODE}" == "severe-swapping" ]] ; then
gcf_warn "Please close all web browsers, downloaders, and large programs to"
gcf_warn "speed up linking time."
	fi
}



gcf_strip_retpoline()
{
	if [[ "${DISABLE_RETPOLINE}" == "1" ]] ; then
		_gcf_replace_flag "-mindirect-branch=thunk" ""
		_gcf_replace_flag "-mretpoline" ""
		_gcf_replace_flag "-mindirect-branch-register" ""
		_gcf_replace_flag "-Wl,-z,retpolineplt" ""
	fi
}

gcf_record_start_time()
{
	export GCF_START_EMERGE_TIME=$(date +%s)
}

gcf_translate_no_inline()
{
	if [[ ( "${CFLAGS}" =~ "-fno-inline" || "${CXXFLAGS}" =~ "-fno-inline" ) \
		&& ( "${CC}" == "clang" || "${CXX}" == "clang++" ) ]] ; then
		# Test with metalog package
		gcf_info "Detected clang.  Converting -fno-inline -> -fno-inline-functions"
		_gcf_replace_flag "-fno-inline" "-fno-inline-functions"
	fi
}

gcf_add_cfi_flags() {
	#
	# The configure, compile, and installs for shared- and static-libs
	# should totally isolated due to the -fvisibility changes and
	# disallowing -fsanitize-cfi-cross-dso for object files for
	# static-libs.
	#
	# This means that CFI Cross-DSO and basic CFI are mutually exclusive
	# at current state of this distro.  If a static-lib is detected, then
	# CFI may have be disabled.
	#
	# CFI requires static linking (with -static for static executables or
	# -Wl,-Bstatic with static-libs) for Basic CFI or building with
	# -fsanitize-cfi-cross-dso for shared-libs.
	#
	local flags=$(get_cfi_flags)
	gcf_info "Package flags: ${flags}"
	if [[ "${flags}" =~ "A" ]] ; then
		gcf_info "Found static-libs in package.  Disabling CFI."
	elif [[ ( "${flags}" =~ "S" || "${flags}" =~ "X" ) && ! ( "${flags}" =~ "A" ) ]] ; then
		if gcf_is_cfiable_system ; then
			gcf_info "Allowing @system package to be CFIed"
		fi
		gcf_info "Adding base CFI flags"
		gcf_append_flags -fsanitize=${CFI_BASELINE}
		# CFI_BASELINE, CFI_EXCEPTIONS, USE_CFI_IGNORE_LIST can be per package customizable.
		if [[ "${USE_CFI_IGNORE_LIST}" == "1" ]] ; then
			gcf_info "FEATURES=${FEATURES}"
			if [[ -e "/etc/portage/package.cfi_ignore/${CATEGORY}/${PN}" ]] ; then
				local p="/etc/portage/package.cfi_ignore/${CATEGORY}/${PN}"
				gcf_append_flags -fsanitize-ignorelist=${p}
				export CCACHE_EXTRAFILES="${CCACHE_EXTRAFILES}:${p}" # add to hash calculation
			fi
			if [[ -e "/etc/portage/package.cfi_ignore/${CATEGORY}/${PN}-${PV}" ]] ; then
				local p="/etc/portage/package.cfi_ignore/${CATEGORY}/${PN}-${PV}"
				gcf_append_flags -fsanitize-ignorelist=${p}
				export CCACHE_EXTRAFILES="${CCACHE_EXTRAFILES}:${p}" # add to hash calculation
			fi
			if [[ -e "/etc/portage/package.cfi_ignore/${CATEGORY}/${PN}-${PVR}" ]] ; then
				local p="/etc/portage/package.cfi_ignore/${CATEGORY}/${PN}-${PVR}"
				gcf_append_flags -fsanitize-ignorelist=${p}
				export CCACHE_EXTRAFILES="${CCACHE_EXTRAFILES}:${p}" # add to hash calculation
			fi
		fi

		# As a precaution, add the systewide ignore list.
		local clang_v=$(clang --version | head -n 1 | cut -f 3 -d " ")
		local p="/usr/lib/clang/${clang_v}/share/cfi_ignorelist.txt"
		export CCACHE_EXTRAFILES="${CCACHE_EXTRAFILES}:${p}" # add to hash calculation
		export CCACHE_EXTRAFILES=$(echo "${CCACHE_EXTRAFILES}" \
			| sed -r -e 's|[:]+|:|g' -e "s|^:||" -e 's|:$||') # trim and simplify

		local cfi_exceptions=()
		[[ "${CFI_CAST_STRICT}" == "1" ]] && gcf_append_flags -fsanitize=cfi-cast-strict
		[[ -n "${CFI_EXCEPTIONS}" ]] && cfi_exceptions+=( ${CFI_EXCEPTIONS} )
		[[ "${NO_CFI_CAST}" == "1" ]] && cfi_exceptions+=( cfi-derived-cast cfi-unrelated-cast )
		[[ "${NO_CFI_DERIVED_CAST}" == "1" ]] && cfi_exceptions+=( cfi-derived-cast )
		[[ "${NO_CFI_ICALL}" == "1" || ! ( "${flags}" =~ "I" ) ]] && cfi_exceptions+=( cfi-icall )
		[[ "${NO_CFI_MFCALL}" == "1" ]] && cfi_exceptions+=( cfi-mfcall )
		[[ "${NO_CFI_NVCALL}" == "1" ]] && cfi_exceptions+=( cfi-nvcall )
		[[ "${NO_CFI_UNRELATED_CAST}" == "1" ]] && cfi_exceptions+=( cfi-unrelated-cast )
		[[ "${NO_CFI_VCALL}" == "1" ]] && cfi_exceptions+=( cfi-vcall )

		gcf_info "Adding CFI Cross-DSO flags"
		gcf_append_flags -fvisibility=default
		gcf_append_flags -fsanitize-cfi-cross-dso

		if [[ "${CFI_CANONICAL_JUMP_TABLES}" == "0" ]] ; then
			# Used for efficiency benefits or change technique of passing cfi checks
			# based on function declaration signature (default on) or by function
			# body address (setting below).
			gcf_append_flags -fno-sanitize-cfi-canonical-jump-tables
		fi

		if [[ "${GCF_CFI_DEBUG}" == "1" ]] ; then
			gcf_warn "CFI debug is enabled.  Turn it off in production."
			gcf_append_flags -fno-sanitize-trap=cfi
		fi

		if (( ${#cfi_exceptions[@]} > 0 )) ; then
			gcf_info "Adding CFI exception flags"
			gcf_append_flags -fno-sanitize=$(echo "${cfi_exceptions[@]}" | tr " " ",")
		fi

		if [[ "${flags}" =~ "S" || "${flags}" =~ "X" ]] ; then
			gcf_info "Auto linking to UBSan"
			gcf_append_ldflags -Wl,-lubsan
			export GCF_UBSAN_LINKED="1"
		fi

		export GCF_CFI="1"
	fi
}

gcf_add_clang_cfi() {
	[[ "${DISABLE_CLANG_LTO}" == "1" ]] && return
	[[ -z "${USE_CLANG_CFI}" || "${USE_CLANG_CFI}" == "0" ]] && return
	[[ "${CC}" == "clang" && "${CXX}" == "clang++" ]] || return
	if ! gcf_is_clang_cfi_ready ; then
		gcf_error "Skipping CFI because missing toolchain support."
		return
	fi
	if ! which clang 2>/dev/null 1>/dev/null ; then
		gcf_error "Skipping CFI because missing toolchain support."
		return
	fi

	if [[ "${CFLAGS}" =~ "-flto" \
		|| "${CXXFLAGS}" =~ "-flto" ]] \
		|| ( has lto ${IUSE_EFFECTIVE} && use lto ) ; then
		:;
	else
		# Clang CFI requires LTO
		gcf_warn "Skipping CFI because it requires LTO."
		return
	fi
	if ! gcf_is_clang_ready ; then
		# Symbol error.  It is assumed that the person will fix this problem immediately.
		# All new or upgraded dependencies need to be rebuilt after clang is rebuilt.
		gcf_warn "Skipping CFI because the clang compiler needs to be rebuilt."
		return
	fi
	local llvm_v=$(clang --version | grep "clang version" | cut -f 3 -d " " | cut -f 1 -d ".")

	if ! has_version "=sys-libs/compiler-rt-sanitizers-${llvm_v}*[cfi,ubsan]" ; then
		gcf_error "Skipping CFI because missing toolchain support."
		return
	fi

	gcf_check_emerge_list_ready

	if gcf_is_cfiable ; then
		gcf_warn "Clang Cross-DSO CFI is experimental and buggy"
		gcf_add_cfi_flags
	fi
}

gcf_catch_errors() {
	gcf_info "Called gcf_catch_errors()"
	if [[ -e "${PWD}/config.log" ]] ; then
		if grep -q -F -e "Assertion \`(cfi_check & (kShadowAlign - 1)) == 0' failed" "${PWD}/config.log" ; then
			# Test package: app-editors/leafpad
			# This is a bug in the config test.
gcf_error "Detected a Clang CFI bug.  Use the sys-libs/compiler-rt-sanitizers"
gcf_error "package from oiledmachine-overlay that disables this assert."
			# Portage will terminate after showing this.
		fi
		if grep -q -F -e "gcc: error: unrecognized argument to '-fsanitize=' option: 'cfi-vcall'" "${PWD}/config.log" ; then
			# Test package: media-libs/opus
gcf_error "Clang CFI is not supported by GCC or the lto flag has been stripped"
gcf_error "by the ebuild.  Please switch to clang for this package or disable"
gcf_error "CFI flags."
			# Portage will terminate after showing this.
		fi
	fi
	if grep -q -E -e "lto-llvm-[a-z0-9]+.o: relocation .* against hidden symbol \`__typeid__.*_align' can not be used when making a shared object" \
		"${T}/build.log" ; then
gcf_error "Try disabling cfi-icall first, then more cfi related flags like"
gcf_error "cfi-nvcall, cfi-vcall."
			# Portage will terminate after showing this.
	fi
	if grep -q -E -e "undefined reference to \`__ubsan_handle_cfi_check_fail_abort'" "${T}/build.log" ; then
gcf_error "Detected possible dead end that may require some rollback."
gcf_error
gcf_error "Steps to resolve in order with one re-emerge per case:"
gcf_error
gcf_error "(1) Try re-emerging the shared-lib with auto or forced -Wl,-lubsan."
gcf_error "(2) Manually recategorize the package in /etc/portage/emerge*.lst if"
gcf_error "temporarly blocked."
gcf_error "(3) Try disabling all CFI flags first, and if it works then converge"
gcf_error "towards the minimal CFI exception set for this package."
gcf_error "(4) Switch back to GCC if all clang flags were all disabled.  It"
gcf_error "could be a clang bug or source code incompatibility with clang."
gcf_error "(5) UBSan may still need to be linked in dependencies of the package"
gcf_error "that have missing symbols.  Re-emerge these dependency packages"
gcf_error "using step 1."
gcf_error "(6) Disable CFI for this package."
gcf_error "If this package is has a noreserve or CFI init problem"
gcf_error "corresponding to [Err 7] and [Err 13] in package.env, disable CFI"
gcf_error "in each named dependency temporary until this package is emerged"
gcf_error "then re-emerge back the dependencies with CFI.  When you rollback,"
gcf_error "this may cause CFI missing symbols."
gcf_error
gcf_error "For case 6 use \`equery b libfile\` to determine the package"
gcf_error "and \`emerge -1vO depend_pkg_name\` to revert with package.env"
gcf_error "changes"
			# Portage will terminate after showing this.
	fi
	if grep -q -E -e "(/usr/lib.*/.*+0x[0-9a-z]+): note: .* defined here" "${T}/build.log" \
		&& grep -q -e "control flow integrity check for type '.*' failed during indirect function call" "${T}/build.log" ; then
		# It will verify by function body address not by function declaration.
gcf_error "Detected external function.  Try rebuilding with"
gcf_error "-fno-sanitize-cfi-canonical-jump-tables with the package containing"
gcf_error "the source binary when using assembly, a non C family language,"
gcf_error "or referencing an external function in the destination lib."
			# Portage will terminate after showing this.
	fi
	if grep -q -e ".a: error adding symbols: file format not recognized" "${T}/build.log" ; then
gcf_error "Detected static-libs IR incompatibility.  Please disable LTO on"
gcf_error "packages that contain .a files listed in the build.log."
gcf_error "Use \`equery b static-lib\` to find those packages."
			# Portage will terminate after showing this.
	fi
	gcf_force_llvm_toolchain_in_perl_module_check_fail
	if grep -q -e "clang.*: error: unknown argument" "${T}/build.log" ; then
gcf_error "Add this package either with use-gcc.conf to /etc/portage/package.env"
gcf_error "or manually categorize this package in both CFI and LTO in"
gcf_error "/etc/portage/emerge*.lst with the latter preferred."
			# Portage will terminate after showing this.
	fi
}

gcf_setup_traps() {
	register_die_hook gcf_catch_errors
}

gcf_use_ubsan() {
	# We would like to disable CFI but link to UBSan to avoid missing symbols.

	# If a program is not linked with CFI, it may still need to be linked to
	# UBSan to avoid linking errors:
	# undefined symbol: __ubsan_handle_cfi_check_fail_abort
	# undefined symbol: __ubsan_handle_cfi_check_fail_minimal_abort

	[[ "${GCF_UBSAN_LINKED}" == "1" ]] && return # Already linked

	local has_ubsan=0
	gcf_is_clang_ready || return
	local s=$(clang --version | grep "clang version" | cut -f 3 -d " " | cut -f 1 -d ".")
	has_version "=sys-libs/compiler-rt-sanitizers-${s}*[ubsan]" && has_ubsan=1

	if [[ "${CC}" == "clang" || "${CXX}" == "clang++" ]] \
		&& (( ${has_ubsan} == 1 )) ; then

		# We would like to apply UBSan to packages that are above the
		# @system set, use clang, have static-libs but still have either
		# shared-libs or executables, skipped being CFIed.

		# Link to UBSan anyway if CFI disabled
		local flags=$(get_cfi_flags_world)
		if [[ "${LINK_UBSAN}" == "1" || "${USE_CLANG_CFI}" == "0" \
			|| ( "${flags}" =~ "A" && ( "${flags}" =~ "X" || "${flags}" =~ "S" ) ) ]] ; then
			gcf_info "Linking to UBSan"
			gcf_append_ldflags -Wl,-lubsan
		fi
	fi
}

gcf_linker_errors_as_warnings() {
	if [[ "${LINKER_ERRORS_AS_WARNINGS}" == "1" ]] ; then
		gcf_append_ldflags -Wl,--warn-unresolved-symbols
	fi
}

gcf_errors_as_warnings() {
	if [[ "${ERRORS_AS_WARNINGS}" == "1" ]] ; then
		gcf_append_flags -Wno-error
	fi
}

gcf_split_lto_unit() {
	[[ "${DISABLE_SPLIT_LTO_UNIT}" == "1" ]] && return
	[[ -z "${CC}" || -z "${CXX}" || "${CC}" == "gcc" || "${CXX}" == "g++" ]] && return
	local require_lto_split=0
	# Applies to packages with static-libs
	if gcf_is_package_lto_restricted \
		&& [[ "${CC}" == "clang" || "${CXX}" == "clang++" ]] ; then
		if [[ "${CFLAGS}" =~ "-flto" ]] \
			|| ( has lto ${IUSE_EFFECTIVE} && use lto ) ; then
			# Auto apply split-lto-unit
			require_lto_split=1
		fi
	fi

	# Force split-lto-unit
	# For ebuilds or build scripts that switch to clang and auto add LTO flags.
	[[ "${SPLIT_LTO_UNIT}" == "1" ]] && require_lto_split=1

	(( ${require_lto_split} == 1 )) && gcf_append_flags -fsplit-lto-unit
}

gcf_singlefy_spaces() {
	local flag_names=(
		COMMON_FLAGS
		CFLAGS
		CXXFLAGS
		FCFLAGS
		FFLAGS
		LDFLAGS
		CGO_CFLAGS
		CGO_CXXFLAGS
		CGO_LDFLAGS
		DIST_MAKE
	)
	local f
	for f in ${flag_names[@]} ; do
		eval "export ${f}=\$("\
"echo \"\$${f}\" "\
"  | sed -E -e 's/[ ]+/ /g' "\
"                                   )"
	done
}

gcf_print_compiler() {
	if [[ "${CC}" =~ "gcc" ]] ; then
		gcf_info "GCC version:  "$(${CC} --version \
			| head -n 1 \
			| grep -o -E -e ") [0-9.]+" \
			| cut -f 2 -d " ")
	fi
	if [[ "${CC}" =~ "clang" ]] ; then
		gcf_info "Clang version:  "$(${CC} --version \
			| head -n 1 \
			| cut -f 3 -d " ")
	fi
}

gcf_print_path() {
	gcf_info "PATH: ${PATH}"
}

gcf_use_slotted_compiler() {
	if [[ -n "${USE_GCC_SLOT}" ]] ; then
		export CC=$(basename /usr/bin/gcc-${USE_GCC_SLOT}*)
		export CPP=$(basename /usr/bin/cpp-${USE_GCC_SLOT}*)
		export CXX=$(basename /usr/bin/g++-${USE_GCC_SLOT}*)
		gcf_info "Switched to gcc:${USE_GCC_SLOT}"
	fi
	if [[ -n "${USE_CLANG_SLOT}" ]] && gcf_is_clang_slot_ready "${USE_CLANG_SLOT}" ; then
		local _PATH=$(echo "${PATH}" | tr ":" "\n" | sed -E -e "\|llvm\/[0-9]+|d")
		_PATH=$(echo -e "${_PATH}\n/usr/lib/llvm/${USE_CLANG_SLOT}/bin" | tr "\n" ":")
		export PATH="${_PATH}"
		[[ -z "${CC}" ]] && gcf_use_clang
		gcf_info "Switched to clang:${USE_CLANG_SLOT}"
		# Add lld path
		local s_lld=$(ver_cut 1 $(best_version "sys-devel/lld" | sed -e "s|sys-devel/lld-||"))
		s_lld=$(ver_cut 1 "${s_lld}")
		export PATH+=":/usr/lib/llvm/${s_lld}/bin"
	fi
	gcf_info "CC=${CC}"
	gcf_info "CPP=${CPP}"
	gcf_info "CXX=${CXX}"
}

gcf_disable_integrated_as() {
	[[ "${DISABLE_INTEGRATED_AS}" == "1" ]] && gcf_append_flags -no-integrated-as
}

gcf_check_packages() {
	if ! has_version "dev-libs/libgcrypt[o-flag-munging]" \
		&& [[ "${CC}" =~ "clang" \
			&& "${CATEGORY}/${PN}" == "dev-libs/libgcrypt" ]] ; then
		die "You must enable dev-libs/libgcrypt[o-flag-munging]"
	fi
}

gcf_force_llvm_toolchain_in_perl_module_check_fail() {
	if [[ "${CATEGORY}" == "dev-perl" || "${CATEGORY}" == "perl-core" || "${PERL_MAKEMAKER_AUTOEDIT}" == "1" ]] ; then
		if grep -q grep -q -e "cc='clang'" $(realpath /usr/lib*/perl*/*/*/Config_heavy.pl) \
			-e ".o: file not recognized: file format not recognized" "${T}/build.log" ; then
gcf_error "The package must be built with Clang LTO and if CFI is enabled with"
gcf_error " CFI edits on in /etc/portage/emerge*lst."
		fi
	fi
}

gcf_force_llvm_toolchain_in_perl_module_setup() {
	if [[ "${CATEGORY}" == "dev-perl" || "${CATEGORY}" == "perl-core" || "${PERL_MAKEMAKER_AUTOEDIT}" == "1" ]] ; then
		if grep -q -e "cc='clang'" $(realpath /usr/lib*/perl*/*/*/Config_heavy.pl) && [[ -z "${CC}" ]] ; then
			gcf_warn "Forcing clang"
			gcf_use_clang
		fi
	fi
}

gcf_force_llvm_toolchain_in_perl_module_configure() {
	# When building these perl modules, they use the same CC, CFLAGS as
	# dev-lang/perl.  This code block will override those flags with our
	# custom flags.
	[[ "${PERL_MAKEMAKER_AUTOEDIT}" == "0" ]] && return
	if [[ "${CATEGORY}" == "dev-perl" || "${CATEGORY}" == "perl-core" || "${PERL_MAKEMAKER_AUTOEDIT}" == "1" ]] ; then
		gcf_info "Scanning perl module for MakeMaker Makefile"
		for f in $(grep -l -r -e "generated automatically by MakeMaker version" "${WORKDIR}" ) ; do
			# Always assume matching compiler with built perl
			sed -i -E -e "s|LDDLFLAGS = (-shared)?.*|LDDLFLAGS = \1 ${CFLAGS}|" "${f}" || die
			sed -i -e "s|LDFLAGS = .*|LDFLAGS = ${LDFLAGS}|" "${f}" || die
			sed -i -e "s|OPTIMIZE = .*|OPTIMIZE = ${CFLAGS}|" "${f}" || die
		done
	fi
}

gcf_strip_omit_frame_pointer() {
	[[ "${REMOVE_OMIT_FRAME_POINTER}" == "1" ]] && _gcf_replace_flag "-fomit-frame-pointer" ""
}

gcf_use_libcxx() {
	local nfiles=$(find "${WORKDIR}" \
		-iname "*.c++" \
		-o -iname "*.cc" \
		-o -iname "*.cpp" \
		-o -iname "*.cxx" \
		-o -iname "*.h++" \
		-o -iname "*.hh" \
		-o -iname "*.hpp" \
		-o -iname "*.hxx" \
		2>/dev/null | wc -l)
	if (( ${nfiles} > 0 )) && [[ "${USE_LIBCXX_AS_DEFAULT}" == "1" && "${CXX}" =~ "clang++" ]] ; then
		if has libcxx ${IUSE_EFFECTIVE} ; then
			# Use the USE flag if it exists.
			:;
		else
			gcf_warn "Auto switching to libstdcxx -> libc++ (EXPERIMENTAL, UNTESTED SYSTEMWIDE)"
			gcf_append_flags -stdlib=libc++
			gcf_append_ldflags -lc++
			# gcf_append_ldflags -static-libstdc++ # for CFI Basic mode only
		fi
	fi
}

gcf_measure_peak_mem() {
	[[ "${DISABLE_SWAP_REPORT}" == "1" ]] && return
	#gcf_info "Sampled peak memory"

	# For some reason size will spike to ~67118676.
	local a=($(ps -o size --sort rss -p $(pgrep -G portage) 2>/dev/null \
                | sed -r -e "s|[ ]+|\t|g" | sed -e "s|SIZE|0|g" | sort -h | sed -e "/^$/d"))

	local total_all=0
	for x in ${a[@]} ; do
		total_all=$((${total_all} + ${x}))
	done

	# Raw total including outliers
	echo "${total_all}" >> "${GCF_MEASURE_PEAK_MEM_LOG}"
}

gcf_report_peak_mem() {
	[[ "${DISABLE_SWAP_REPORT}" == "1" ]] && return
	rm -rf "${GCF_MEASURE_PEAK_MEM_LOG}-activated"
	sleep 1

	local nseconds_light_swapping=0
	local nseconds_severe_swapping=0
	local a=($(cat "${GCF_MEASURE_PEAK_MEM_LOG}"))

	local _a=$(echo "${a[@]}" | tr " " ",")
	local avg_mean=$(python -c "import statistics;print(statistics.mean([${_a}]))")
	local sd=$(python -c "import statistics;print(statistics.stdev([${_a}]))")
	# Trim outside 95% (or 2 standard deviations)
	local a2=$(python -c \
"
avg_mean=${avg_mean};
sd=${sd};
a=[${_a}];
a1=[x for x in a if (x > avg_mean - 2 * sd and x < avg_mean + 2 * sd)];
print(a1)
" \
	)
	local a_trimmed=($(echo "${a2}" | sed -e "s|,||g" -e "s|\[||g" -e "s|\]||g"))

	local peak_memory=$(echo "${a_trimmed[@]}" | tr " " "\n" | sort -h | tail -n 1)
	# This logged info could be used to autoscale makeopts in future runs
	# with a few changes to this bashrc to avoid trashing.
	gcf_info "Peak memory:  ${peak_memory} KiB"

	local light_swap_margin=${LIGHT_SWAP_MARGIN:="${NCORES} * ${GIB_PER_CORE} - 1.6"} # \
	# in GiB, 1.6 comes from total RSS (from one liner below) while not emerging with browser playing 1 tab of video
	# t=0; for x in $(ps -A -o rss --sort rss); do t=$((${t}+${x})); done ; echo "${t}" # in KiB

	local heavy_swap_margin=${HEAVY_SWAP_MARGIN:="${NCORES} * ${GIB_PER_CORE} * 1.5"} # \
	# in GiB, 1.5 comes from (6 GiB of all compiler instances while freezing or not responsive window switching) / 4 GiB RAM
	# You can also obtain the number from the one liner below.
	# t=0; for x in $(ps -o size --sort size $(pgrep -G portage)); do t=$((${t}+${x})); done ; echo "${t}" # in KiB

	for l in ${a_trimmed[@]} ; do
		[[ -z "${l}" ]] && continue
		if which bc 2>/dev/null 1>/dev/null ; then
			# Faster load time.
			if (( ${l} > $(echo "(${heavy_swap_margin}) * 1048576" | bc | cut -f 1 -d ".") )) ; then
				nseconds_severe_swapping=$(( ${nseconds_severe_swapping} + 1 ))
			elif (( ${l} > $(echo "(${light_swap_margin}) * 1048576" | bc | cut -f 1 -d ".") )) ; then
				nseconds_light_swapping=$(( ${nseconds_light_swapping} + 1 ))
			fi
		else
			# Slower load time.
			if (( ${l} > $(python -c "print(int((${heavy_swap_margin}) * 1048576))") )) ; then
				nseconds_severe_swapping=$(( ${nseconds_severe_swapping} + 1 ))
			elif (( ${l} > $(python -c "print(int((${light_swap_margin}) * 1048576))") )) ; then
				nseconds_light_swapping=$(( ${nseconds_light_swapping} + 1 ))
			fi
		fi
	done

	# Used to adjust makeopts on future runs.  Grep the logs for these
	# messages in /var/log/emerge/build-logs.
	#
	# It doesn't matter when asleep or when unattended, but it will matter
	# when multitasking while building.
	if (( ${nseconds_severe_swapping} > ${NSEC_FREEZE} )) ; then
gcf_error "Detected more than ${NSEC_FREEZE} seconds of severe swapping.  Try"
gcf_error "makeopts-severe-swapping.conf"
	elif (( ${nseconds_light_swapping} > ${NSEC_LAG} )) ; then
gcf_warn "Detected more than ${NSEC_LAG} seconds of light swapping.  Try"
gcf_warn "makeopts-swappy.conf"
	fi
}

_gcf_start_measure_peak_mem_proc() {
	while [[ -e "${GCF_MEASURE_PEAK_MEM_LOG}-activated" ]] ; do
		gcf_measure_peak_mem
		sleep 1
	done
}

gcf_init_measure_peak_mem() {
	[[ "${DISABLE_SWAP_REPORT}" == "1" ]] && return
	export GCF_MEASURE_PEAK_MEM_LOG="${T}/measured-peak-mem"
	echo "0" > "${GCF_MEASURE_PEAK_MEM_LOG}"
	echo "0" >> "${GCF_MEASURE_PEAK_MEM_LOG}"
	echo "" > "${GCF_MEASURE_PEAK_MEM_LOG}-activated"
}

gcf_start_measure_peak_mem() {
	[[ "${DISABLE_SWAP_REPORT}" == "1" ]] && return
	gcf_info "Starting to measure peak memory"
	_gcf_start_measure_peak_mem_proc &
}

_gcf_add_system_ignorelist() {
	local name="${1}"
	# The FORCE_ADD_SYSTEMWIDE_IGNORELIST is a per-package environment variable.
	if ( has ${name} ${IUSE_EFFECTIVE} && use ${name} ) \
		|| [[ "${FORCE_ADD_SYSTEMWIDE_IGNORELIST:=none}" == "${name}" ]] ; then
		gcf_is_clang_ready || return
		local clang_v=$(clang --version | head -n 1 | cut -f 3 -d " ")
		local p="/usr/lib/clang/${clang_v}/share/${name}_ignorelist.txt"
		export CCACHE_EXTRAFILES="${CCACHE_EXTRAFILES}:${p}" # add to hash calculation
	fi
}

gcf_setup_ccache() {
	# Fix flaws with this ccache
	# As a precaution, add the systewide ignore lists if use flag activated.
	_gcf_add_system_ignorelist "asan"
	_gcf_add_system_ignorelist "dfsan"
	_gcf_add_system_ignorelist "hwasan"
	_gcf_add_system_ignorelist "msan"
	export CCACHE_EXTRAFILES=$(echo "${CCACHE_EXTRAFILES}" \
		| sed -r -e 's|[:]+|:|g' -e "s|^:||" -e 's|:$||') # trim and simplify
}

gcf_print_ccache_extrafiles() {
	# Print to verify ccache determinism with path args with variant data.
	# Any missed -f...=<path> when path is not added to hash
	# calculation can cause repeat build failures.
	# TODO autoverify this is populated when sanitizers with non CFI ignorelists
	gcf_info "CCACHE_EXTRAFILES:  ${CCACHE_EXTRAFILES}"
}

gcf_use_souper() {
	if [[ "${USE_SOUPER}" == "1" ]] ; then
		if has_version "sys-devel/souper" \
			&& has_version "sys-devel/llvm[souper]" ; then
			:;
		else
			gcf_warn "Souper requirements not met.  Skipping."
			return
		fi
		if [[ "${CC}" =~ "gcc" ]] ; then
			gcf_warn "Use Clang in order to use Souper.  Skipping."
			return
		fi
		gcf_is_clang_ready || return
		local s_llvm
		if [[ -n "${USE_CLANG_SLOT}" ]] ; then
			s_llvm="${USE_CLANG_SLOT}"
		else
			s_llvm=$(clang --version | grep "clang version" \
				| cut -f 3 -d " " | cut -f 1 -d ".")
		fi
		gcf_append_flags "-Xclang -load -Xclang "$(realpath /usr/lib/souper/${s_llvm}/*/libsouperPass.so)
		if [[ "${USE_SOUPER_SIZE}" ]] \
			&& has_version "sys-devel/souper[external-cache]" \
			&& has_version "dev-db/redis" ; then
			gcf_append_flags -mllvm -souper-static-profile
		elif [[ "${USE_SOUPER_SIZE}" ]] ; then
gcf_warn "Missing sys-devel/souper[external-cache].  Skipping static profile flags for"
gcf_warn "size reduction counting."
		fi
		if [[ "${USE_SOUPER_SPEED}" ]] \
			&& has_version "sys-devel/souper[external-cache]" \
			&& has_version "dev-db/redis" ; then
			gcf_append_flags -g -mllvm -souper-dynamic-profile
		elif [[ "${USE_SOUPER_SPEED}" ]] ; then
gcf_warn "Missing sys-devel/souper[external-cache].  Skipping dynamic profile flags for"
gcf_warn "execution speed counting."
		fi
	fi
}

pre_pkg_setup()
{
	gcf_info "Running pre_pkg_setup()"
	gcf_setup_ccache
	gcf_setup_traps
	gcf_disable_integrated_as
	gcf_replace_flags
	gcf_lto
	gcf_force_llvm_toolchain_in_perl_module_setup
	gcf_check_packages
	gcf_split_lto_unit
	gcf_add_clang_cfi
	gcf_retpoline_translate
	gcf_strip_no_plt
	gcf_strip_gcc_flags
	gcf_strip_z_retpolineplt
	gcf_strip_retpoline
	gcf_strip_no_inline
	gcf_strip_lossy
	gcf_strip_omit_frame_pointer
	gcf_use_Oz
	gcf_use_ubsan
	gcf_translate_no_inline
	gcf_replace_freorder_blocks_algorithm
	gcf_bolt_prepare
	gcf_use_souper
	gcf_linker_errors_as_warnings
	gcf_errors_as_warnings
	gcf_adjust_makeopts
	gcf_singlefy_spaces
	gcf_record_start_time
	gcf_print_flags
	gcf_use_slotted_compiler
	gcf_print_compiler
	gcf_print_path
	gcf_print_ccache_extrafiles
	gcf_init_measure_peak_mem
}

gcf_check_Ofast_safety()
{
	[[ "${DISABLE_FALLOW_STORE_DATA_RACES_CHECK}" == "1" ]] && return
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

gcf_check_ebuild_compiler_override() {
	[[ "${DISABLE_OVERRIDE_COMPILER_CHECK}" == "1" ]] && return
	gcf_is_lto_skippable && return

	_gcf_ir_message_incompatible() {
gcf_error
gcf_error "Detected possible ebuild override of CC/CXX with incompatible IR."
gcf_error "It is recommended disable LTO for this package."
gcf_error
gcf_error "CC=${CC}"
gcf_error "CXX=${CXX}"
gcf_error
gcf_error "You may supply DISABLE_OVERRIDE_COMPILER_CHECK=1 in the package.env"
gcf_error "if it is a false-positive."
gcf_error
			die
	}

	if ( [[ "${CFLAGS}" =~ "-flto" ]] || ( has lto ${IUSE_EFFECTIVE} && use lto ) ) \
		&& gcf_is_package_lto_restricted ; then
		gcf_info "Running gcf_check_ebuild_compiler_override()"

		# The ebuild author can override with ${CHOST}-clang or ${CHOST}-gcc.
		# Sample of possible values:
		# gcc, ${CHOST}-gcc, gcc-11.2.0, ${CHOST}-gcc-11.2.0, unset CC # normalizes to gcc
		# clang, ${CHOST}-clang, clang-14, ${CHOST}-clang-14 # normalizes to clang
		# g++, ${CHOST}-g++, ${CHOST}-g++-11.2.0, unset CXX # normalizes to g++
		# clang++, ${CHOST}-clang++, ${CHOST}-clang++-14 # normalizes to clang
		#
		# g++ and clang++ are ambiguous in substring search.
		#
		local cc
		local cxx
		# Simplify / Normalize the above cases
		if [[ "${CC}" =~ "gcc" || -z "${CC}" ]] ; then # trivial
			cc="gcc"
		elif [[ "${CC}" =~ "clang" ]] ; then # trivial
			cc="clang"
		fi

		if [[ "g++" =~ (^|-| )"${CXX}"( |-|$) || -z "${CXX}" ]] ; then # not trivial
			cxx="g++"
		elif [[ "${CXX}" =~ "clang++" ]] ; then # trivial
			cxx="clang++"
		fi

		if [[ ! ( "${cc}" == "${CC_LTO}" ) || ! ( "${cxx}" == "${CXX_LTO}" ) ]] ; then
			_gcf_ir_message_incompatible
		fi
		local start=$(grep -n "Compiling source in" "${T}/build.log" | head -n 1 | cut -f 1 -d ":")
		local end=$(grep -n "Source compiled" "${T}/build.log" | head -n 1 | cut -f 1 -d ":")
		[[ -z "${end}" ]] && end=$(wc -l "${T}/build.log")
		if [[ -n "${start}" && ( ! "${CC_LIBC}" == "${CC_LTO}" ) ]] \
			&& (( $(sed -n ${start},${end}p "${T}/build.log" \
				| grep -e "${CC_LIBC}" \
				| wc -l) >= 1 )) ; then
			CC=${CC_LIBC}
			CXX=${CXX_LIBC}
			_gcf_ir_message_incompatible
		fi
		# non trivial
		if [[ -n "${start}" && ! ( "${CXX_LIBC}" == "${CXX_LTO}" ) ]] \
			&& (( $(sed -n ${start},${end}p "${T}/build.log" \
				| grep -E -e "(^|-| )${CXX_LIBC//+/\\+}( |-|$)" \
				| wc -l) >= 1 )) ; then
			CC=${CC_LIBC}
			CXX=${CXX_LIBC}
			_gcf_ir_message_incompatible
		fi

		# TODO: auto inspect packages that turn off compiler verbosity.
	fi
}

gcf_check_external_linkage_for_cfi() {
	[[ -n "${CFI_CANONICAL_JUMP_TABLES}" ]] && return
	local nfiles=$(find "${WORKDIR}" -name "*.asm" -o -name "*.S" -o -name "*.s" 2>/dev/null | wc -l)
	if (( ${nfiles} > 0 )) ; then
gcf_warn "Detected assembly file(s).  A -fno-sanitize-cfi-canonical-jump-tables"
gcf_warn "may needed to be added to per-package *FLAGS to fix a external or"
gcf_warn "indirect CFI function violation.  If no problems are encountered,"
gcf_warn "you may skip this recommendation.  See docs for additional info."
	fi
}

post_src_unpack() {
	gcf_check_external_linkage_for_cfi
	gcf_use_libcxx
}

post_src_prepare() {
	:;
}

post_src_configure() {
	gcf_force_llvm_toolchain_in_perl_module_configure
}

pre_src_compile() {
	gcf_info "Running pre_src_compile()"
	gcf_check_ebuild_compiler_override
	gcf_start_measure_peak_mem
}

post_src_compile() {
	gcf_info "Running post_src_compile()"
	gcf_check_ebuild_compiler_override
}

pre_src_install() {
	gcf_info "Running pre_src_install()"
	gcf_check_Ofast_safety
}

gcf_report_emerge_time() {
	# Can used by log filtering
	local now=$(date +%s)
	local elapsed_time=$((${now} - ${GCF_START_EMERGE_TIME}))
	local et_days=$(( ${elapsed_time} / 86400  ))
	local et_hours=$(( ${elapsed_time} % 86400 / 3600 ))
	local et_min=$(( ${elapsed_time} % 3600 / 60 ))
	local et_sec=$(( ${elapsed_time} % 60 ))
	gcf_info "Completion Time: ${elapsed_time} seconds ( ${et_days} days ${et_hours} hours ${et_min} minutes ${et_sec} seconds )"
	if (( ${et_days} >= 1 || ${et_hours} >= 18 )) ; then # 3/4 of a day.
		# More than 1 day is not acceptable.  If updates are monotasking, it blocks
		# security updates for critical 0-day exploits.  Critical updates require
		# updates within a day.
		gcf_warn "The MAKEOPTS value may need to be reduced to increase goodput or"
		gcf_warn "don't use Full LTO or switch to ThinLTO instead."
	fi
}

_gcf_verify_src() {
	local location="${1}"
	if [[ "${location}" == "ED" ]] ; then
		# Verify in ${ED} when it is not stripped
		find "${ED}" -executable
	elif [[ "${location}" == "EROOT" ]] ; then
		# Verify after strip in ${EROOT}
		cat /var/db/pkg/${CATEGORY}/${PN}-${PVR}/CONTENTS | cut -f 2 -d " "
	fi
}

gcf_verify_cfi() {
	[[ "${DISABLE_CFI_VERIFY}" == "1" ]] && return
	[[ "${GCF_CFI}" == "1" ]] || return
	local location="${1}"

	# Strip may interfere with CFI
	for f in $(_gcf_verify_src "${location}") ; do
		local is_so=0
		local is_exe=0
		file "${f}" | grep -q -e "ELF.*shared object" && is_so=1
		file "${f}" | grep -q -e "ELF.*executable" && is_exe=1

		if (( ${is_so} == 1 )) ; then
			if readelf -Ws "${f}" 2>/dev/null | grep -E -q -e "(cfi_bad_type|cfi_check_fail|__cfi_init)" ; then
				:;
			else
gcf_error "${f} is not Clang CFI protected.  nostrip must be added to"
gcf_error "per-package FEATURES.  You may disable this check by adding"
gcf_error "DISABLE_CFI_VERIFY=1."
				die
			fi
		fi
		# Some exes may or may not be CFIed.  This is why it is currently optional.
		if (( ${is_exe} == 1 )) ; then
			if readelf -Ws "${f}" 2>/dev/null | grep -E -q -e "(cfi_bad_type|cfi_check_fail|__cfi_init)" ; then
				:;
			else
gcf_warn "${f} is not Clang CFI protected."
			fi
		fi
	done
}

gcf_verify_loading_lib() {
	# Check if .so is unbroken after stripping
	[[ "${DISABLE_SO_LOAD_VERIFY}" == "1" ]] && return
	local f
	for f in $(_gcf_verify_src "${location}") ; do
		[[ "${f}" =~ ".so" ]] || continue
		local is_so=0
		file "${f}" | grep -q -e "ELF.*shared object" && is_so=1
		if (( ${is_so} == 1 )) ; then
			if ldd "${f}" | grep -q -e "not a dynamic executable" ; then
gcf_error "${f} is an unloadable.  Add no stripping (no-strip.conf) to fix"
gcf_error "ldd check and re-emerge this package."
				die
			fi
		fi
	done
}

post_src_install() {
	gcf_info "Running post_src_install()"
	gcf_report_emerge_time
	gcf_report_peak_mem
	gcf_verify_cfi "ED"
}

pre_pkg_postinst() {
	gcf_info "Running pre_pkg_postinst()"
	gcf_verify_cfi "EROOT"
	gcf_verify_loading_lib "EROOT"
}
