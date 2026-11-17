# Helpers sourced inside the test containers (see tests/run.sh).
# Not meant to be run on your machine.

REPO="${HOME}/.config/rice"

# Stop the test case with a message
fail() {
	echo "ASSERT FAILED: $*"
	exit 1
}

# Run a script from scripts/, from / so it can't rely on the current directory.
# Fails if it exits with an error, logged a FAIL line, or if a command
# inside it printed an error (mv: cannot..., command not found...).
# $1 script name, the rest are its arguments
run_script() {
	local script="$1" output status
	shift
	output=$(cd / && "${REPO}/scripts/${script}" "$@" 2>&1)
	status=$?
	echo "${output}"
	(( status == 0 )) || fail "${script} $* exited with code ${status}"
	# Remove colors before searching the log
	output=$(sed 's/\x1b\[[0-9;]*m//g' <<< "${output}")
	if grep -q '\[ *FAIL *\]' <<< "${output}"; then
		fail "${script} logged: $(grep -m1 '\[ *FAIL *\]' <<< "${output}")"
	fi
	local errors='^(mv|cp|mkdir|ln|rm|ls|cat|xdg-user-dir): |command not found|syntax error|unbound variable'
	if grep -qE "${errors}" <<< "${output}"; then
		fail "a command failed inside ${script}: $(grep -m1 -E "${errors}" <<< "${output}")"
	fi
}

install()	{ run_script install.sh "$@"; }
uninstall()	{ run_script uninstall.sh "$@"; }

# Run diff.sh from /. It exits 1 when something differs, so instead of failing
# it saves its output (without colors) in DIFF_OUTPUT and its exit code in DIFF_STATUS.
# Fails only on an error (exit code 2+, or a command inside it printed an error).
run_diff() {
	DIFF_OUTPUT=$(cd / && "${REPO}/scripts/diff.sh" "$@" 2>&1)
	DIFF_STATUS=$?
	DIFF_OUTPUT=$(sed 's/\x1b\[[0-9;]*m//g' <<< "${DIFF_OUTPUT}")
	echo "${DIFF_OUTPUT}"
	(( DIFF_STATUS <= 1 )) || fail "diff.sh $* exited with code ${DIFF_STATUS}"
	local errors='^(find|cmp|diff|sed): |command not found|syntax error|unbound variable'
	if grep -qE "${errors}" <<< "${DIFF_OUTPUT}"; then
		fail "a command failed inside diff.sh: $(grep -m1 -E "${errors}" <<< "${DIFF_OUTPUT}")"
	fi
}

# check.sh runs with this folder as its only PATH, so its result
# depends on the fake programs put in it, not on the machine.
FAKE_BIN="${HOME}/fake-bin"

# Puts in FAKE_BIN the basic tools check.sh needs and a fake version of each given program
# $@ programs to fake
fake_programs() {
	local tool
	mkdir -p "${FAKE_BIN}"
	for tool in dirname realpath grep sort; do
		ln -sf "$(command -v "${tool}")" "${FAKE_BIN}/${tool}"
	done
	for tool in "$@"; do
		printf '#!/bin/sh\n' > "${FAKE_BIN}/${tool}"
		chmod +x "${FAKE_BIN}/${tool}"
	done
}

# Puts a fake fc-list in FAKE_BIN: it finds every font and icon, or none with "none"
fake_fonts() {
	mkdir -p "${FAKE_BIN}"
	if [[ "${1:-}" == none ]]; then
		printf '#!/bin/sh\n' > "${FAKE_BIN}/fc-list"
	else
		printf '#!/bin/sh\necho "Fake Font"\n' > "${FAKE_BIN}/fc-list"
	fi
	chmod +x "${FAKE_BIN}/fc-list"
}

# Prints the needed (not optional) programs listed in check.sh, one per line
required_programs() {
	sed -n '/^PROGRAMS=(/,/^)/s/^\t"\([^|]*\)|.*/\1/p' "${REPO}/scripts/check.sh"
}

# Run check.sh from /, with FAKE_BIN as PATH. It exits 1 when something is missing,
# so instead of failing it saves its output (without colors) in CHECK_OUTPUT and
# its exit code in CHECK_STATUS.
# Fails only on an error (exit code 2+, or a command inside it printed an error).
run_check() {
	CHECK_OUTPUT=$(cd / && PATH="${FAKE_BIN}" "${REPO}/scripts/check.sh" "$@" 2>&1)
	CHECK_STATUS=$?
	CHECK_OUTPUT=$(sed 's/\x1b\[[0-9;]*m//g' <<< "${CHECK_OUTPUT}")
	echo "${CHECK_OUTPUT}"
	(( CHECK_STATUS <= 1 )) || fail "check.sh $* exited with code ${CHECK_STATUS}"
	local errors='^(grep|sort|fc-list): |command not found|syntax error|unbound variable'
	if grep -qE "${errors}" <<< "${CHECK_OUTPUT}"; then
		fail "a command failed inside check.sh: $(grep -m1 -E "${errors}" <<< "${CHECK_OUTPUT}")"
	fi
}

# Every config from the repo must be installed and identical
assert_installed() {
	local dir file
	for dir in "${DIRECTORIES[@]}"; do
		diff -r "${REPO}/config/${dir}" "${HOME}/.config/${dir}" || fail "~/.config/${dir} differs from the repo"
	done
	for file in "${FILES[@]}"; do
		diff "${REPO}/config/${file}" "${HOME}/${file}" || fail "~/${file} differs from the repo"
	done
}

# Some file in the backup folder must contain the given text
assert_backed_up() {
	grep -rqs "$1" "${HOME}/.config/${BACKUP_DIR}" || fail "'$1' not found in ~/.config/${BACKUP_DIR}"
}

# The scripts must never modify the repo itself
assert_repo_untouched() {
	diff -r /src "${REPO}" || fail "the repo copy was modified"
}

# Wallpapers must be installed and identical to the repo
assert_wallpapers_installed() {
	diff -r "${REPO}/wallpapers" "${HOME}/${WALLPAPERS_DIR}" || fail "~/${WALLPAPERS_DIR} differs from the repo"
}

# Every path written in the installed configs (~/..., $HOME/..., /home/...)
# must exist, otherwise a program will look for a file that isn't there.
assert_config_paths_exist() {
	local configs=() path real missing=""
	for dir in "${DIRECTORIES[@]}"; do
		configs+=("${HOME}/.config/${dir}")
	done

	while read -r path; do
		real="${path/#\~/${HOME}}"
		real="${real/#\$\{HOME\}/${HOME}}"
		real="${real/#\$HOME/${HOME}}"
		[[ -e "${real}" ]] || missing+=$'\n'"    ${path}"
	done < <(grep -rhoE '(~|\$\{?HOME\}?|/home/[^/[:space:]]+)/[^"'\''[:space:]);,]+' "${configs[@]}" | sort -u)

	[[ -z "${missing}" ]] || fail "paths used in the configs don't exist:${missing}"
}

# Nothing in the home should point to a file that doesn't exist
assert_no_broken_links() {
	local broken
	broken=$(find "${HOME}" -xtype l)
	[[ -z "${broken}" ]] || fail "broken symlinks: ${broken}"
}

#####################
###### FIREFOX ######
#####################

# Fake Firefox profiles: Firefox isn't installed in the container,
# install.sh only needs profiles.ini and the profile folder.
FF_PROFILE="abcd1234.default-release"	# the one Firefox really uses
FF_DECOY="zzzz9999.default"			# listed first, as Profile0 with Default=1

# $1 Firefox dir (e.g. ~/.mozilla/firefox)
# Creates the real profile and a decoy one. Only the [Install...] section
# says which profile Firefox opens: picking Profile0 or Default=1 is wrong.
make_ff_profile() {
	local ff_dir="$1"
	mkdir -p "${ff_dir}/${FF_DECOY}" "${ff_dir}/${FF_PROFILE}"
	echo 'user_pref("browser.startup.page", 3);' > "${ff_dir}/${FF_PROFILE}/prefs.js"
	cat > "${ff_dir}/profiles.ini" <<-EOF
		[Profile0]
		Name=default
		IsRelative=1
		Path=${FF_DECOY}
		Default=1

		[Profile1]
		Name=default-release
		IsRelative=1
		Path=${FF_PROFILE}

		[General]
		StartWithLastProfile=1
		Version=2

		[Install4F96D1932A9F858E]
		Default=${FF_PROFILE}
		Locked=1
	EOF
}

# $1 profile folder: user.js and chrome/ must be there and identical to the repo
assert_ff_installed() {
	diff "${REPO}/config/firefox/user.js" "$1/user.js" || fail "$1/user.js differs from the repo"
	diff -r "${REPO}/config/firefox/chrome" "$1/chrome" || fail "$1/chrome differs from the repo"
}

# $1 profile folder: nothing from the rice must be there
assert_ff_not_installed() {
	[[ ! -e "$1/user.js" ]] || fail "$1/user.js exists, it should not"
	[[ ! -e "$1/chrome" ]] || fail "$1/chrome exists, it should not"
}

# Simulate a user who already has their own config
make_old_config() {
	mkdir -p "${HOME}/.config/hypr"
	echo OLD_HYPR > "${HOME}/.config/hypr/hyprland.conf"
	echo OLD_EXTRA > "${HOME}/.config/hypr/only-in-old-config.conf"
	echo OLD_ZSHRC > "${HOME}/.zshrc"
}
