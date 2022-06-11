#!/bin/bash

# This file is a dependency of gen_package_env.sh

DIR_SCRIPT=$(dirname "$0")

ARCHIVES_SKIP_LARGE=${ARCHIVES_SKIP_LARGE:-1}
ARCHIVES_SKIP_LARGE_CUTOFF_SIZE=${ARCHIVES_SKIP_LARGE_CUTOFF_SIZE:-100000000}
DISTDIR="${DISTDIR:-/var/cache/distfiles}"
FMATH_OPT="${FMATH_OPT:-Ofast-mt.conf}"
LAYMAN_BASEDIR="${LAYMAN_BASEDIR:-/var/lib/layman}"
OILEDMACHINE_OVERLAY_DIR="${OILEDMACHINE_OVERLAY_DIR:-/usr/local/oiledmachine-overlay}"
PORTAGE_DIR="${PORTAGE_DIR:-/usr/portage}"
WOPT=${WOPT:-"20"}
WPKG=${WPKG:-"50"}

get_path_pkg_idx() {
	local manifest_path="${1}"
	echo $(ls "${manifest_path}" | grep -o -e "/" | wc -l)
}

gen_overlay_paths() {
	local _overlay_paths=(
		${PORTAGE_DIR}
		${OILEDMACHINE_OVERLAY_DIR}
		$(find "${LAYMAN_BASEDIR}" -maxdepth 1 -type d \( -name "profiles" -o -name "metadata" \) \
			| sed -r -e "s/(metadata|profiles)//g" \
			| sed -e "s|/$||g" \
			| sort \
			| uniq)
	)
	export OVERLAY_PATHS="${_overlay_paths[@]}"
}

get_cat_p() {
	local tarball_path="${@}"
	local a=$(basename "${tarball_path}")
	local hc="S"$(echo -n "${a}" | sha1sum | cut -f 1 -d " ")
	echo ${A_TO_P[${hc}]}
}

# This is very expensive to do a lookup
gen_tarball_to_p_dict() {
	unset A_TO_P
	declare -Ax A_TO_P
	local cache_path="${DIR_SCRIPT}/a_to_p.cache"
	if [[ -e "${cache_path}" ]] ; then
		local ts=$(stat -c "%W" "${cache_path}")
		local now=$(date +"%s")
		if (( ${ts} + 86400 >= ${now} )) ; then # Expire in 1 day
			echo "Using cached A_TO_P hashmap.  Delete it after emerge --sync."
			eval "$(cat ${cache_path})"
			if ! declare -p A_TO_P 2>&1 > /dev/null ; then
				echo "Failed to init A_TO_P"
				exit 1
			fi
			return
		fi
	fi
	echo "Generating archive to \${CATEGORY}/\${P} hashmap.  Please wait..."
	local op
	for op in ${OVERLAY_PATHS[@]} ; do
		local path
		for path in $(find "${op}" -type f -name "Manifest") ; do
			echo "Inspecting ${path}"
			local idx_pn=$(get_path_pkg_idx "${path}")
			local idx_cat=$(( ${idx_pn} - 1 ))
			local cat_p=$(echo "${path}" | cut -f ${idx_cat}-${idx_pn} -d "/")
			local pn=$(echo "${path}" | cut -f ${idx_pn} -d "/")
			grep -q -e "DIST" "${path}" || continue
			local a=$(grep -e "DIST" "${path}" | cut -f 2 -d " ")
			local hc="S"$(echo -n "${a}" | sha1sum | cut -f 1 -d " ")
			A_TO_P[${hc}]="${cat_p}"
		done
	done
	# Pickle it
	declare -p A_TO_P > "${cache_path}"
}

search() {
	gen_overlay_paths
	gen_tarball_to_p_dict
	local found=()
	local x
	echo "Scanning..."
	echo -n "" > package.env.t
	for x in $(find "${DISTDIR}" -maxdepth 1 -type f \( -name "*tar.*" -o -name "*.zip" \)) ; do
		if [[ "${ARCHIVES_SKIP_LARGE}" == "1" ]] \
			&& (( $(stat -c "%s" ${x} ) >= ${ARCHIVES_SKIP_LARGE_CUTOFF_SIZE} )) ; then
			echo "[warn : search float] Skipped large tarball for ${x}"
			local cat_p=$(get_cat_p "${x}")
			printf "%-${WPKG}s%-${WOPT}s %s\n" "${cat_p}" "# skipped" "# Reason: Large tarball" >> package.env.t
			continue
		fi
		echo "Processing ${x}"
		local paths
		[[ "${x}" =~ "zip"$ ]] && paths=($(unzip -l "${x}" | sed -r -e "s|[0-9]{2}:[0-9]{2}   |;|g" | grep ";" | cut -f 2 -d ";" 2>/dev/null))
		[[ "${x}" =~ "tar" ]] && paths=($(tar -tf "${x}" 2>/dev/null))
		for fpath in ${paths[@]} ; do
			[[ "${fpath}" =~ (\.c|\.cpp|\.C|\.h)$ ]] || continue
			if [[ "${x}" =~ "tar" ]] && tar -xOf "${x}" "${fpath}" | grep -i -q -E -e "(float|double)" ; then
				found+=( "${x}" )
				echo "Found float in ${x}: ${fpath}"
				break
			elif [[ "${x}" =~ ".zip" ]] && unzip -p "${x}" "${fpath}" | grep -i -q -E -e "(float|double)" ; then
				found+=( "${x}" )
				echo "Found float in ${x}: ${fpath}"
				break
			fi
		done
	done
	for x in $(echo ${found[@]} | tr " " "\n" | sort | uniq) ; do
		local cat_p=$(get_cat_p "${x}")
		printf "%-${WPKG}s%-${WOPT}s\n" "${cat_p}" "${FMATH_OPT}" >> package.env.t
	done
}

search
