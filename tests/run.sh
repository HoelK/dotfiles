#!/bin/bash

# Tests install.sh inside throwaway Docker containers.
#
#   tests/run.sh               run every test case
#   tests/run.sh backup        run only the cases whose name contains "backup"
#   tests/run.sh --shell       open a shell in a fresh container to explore by hand
#
# Your real files are never touched:
#   - the repo is mounted read-only at /src, each case works on a copy of it
#   - every case runs in a new container, deleted afterwards (--rm)
#   - containers have no network access (--network none)

set -u

#####################
##### VARIABLES #####
#####################

IMAGE="rice-test"
REPO="$(dirname "$(realpath "$0")")/.."

# Must match install.sh
DIRECTORIES=(hypr tmux nvim kitty waybar wlogout)
FILES=(.zshrc)
BACKUP_DIR="config-back"	# inside ~/.config
WALLPAPERS_DIR=".local/share/wallpapers"	# inside ~

DEFAULT=$'\e[0m'
RED=$'\e[0;31m'
GREEN=$'\e[0;32m'
YELLOW=$'\e[0;33m'

#################
##### UTILS #####
#################

# Loaded in every container: the lists above + the helpers from tests/helpers.sh
HELPERS="$(declare -p DIRECTORIES FILES BACKUP_DIR WALLPAPERS_DIR)
source /src/tests/helpers.sh"

# Copies the repo where a real user would have it
SETUP='mkdir -p "$HOME/.config" && cp -r /src "$HOME/.config/rice"'

build_image() {
	echo "Building ${IMAGE} image (cached after the first time)..."
	docker build -q -t "${IMAGE}" "${REPO}/tests" >/dev/null || {
		echo "${RED}Docker build failed${DEFAULT}"
		exit 1
	}
}

# $1 code to run, fed on stdin after the setup and helpers
run_case() {
	docker run --rm --network none -i -v "${REPO}:/src:ro" "${IMAGE}" bash -s <<< "set -u
${HELPERS}
${SETUP}
${1}"
}

# Interactive shell with the helpers loaded. In it, fail only prints
# instead of exiting, so a failed assert doesn't close your shell.
open_shell() {
	docker run --rm --network none -it -e HELPERS="${HELPERS}" -v "${REPO}:/src:ro" "${IMAGE}" \
		bash -c "${SETUP}"' && printf "%s\nfail() { echo \"ASSERT FAILED: \$*\"; return 1; }\n" "$HELPERS" > ~/.helpers && exec bash --rcfile ~/.helpers'
}

######################
##### TEST CASES #####
######################

# Each case: a name and the code run inside a fresh container.
# A case passes if its code exits with 0, exit 77 means skipped.
CASE_NAMES=()
CASE_CODES=()
add_case() { CASE_NAMES+=("$1"); CASE_CODES+=("$2"); }

add_case "script has no syntax error" '
	bash -n "$REPO/install.sh" || fail "bash -n reports a syntax error"
'

add_case "fresh install" '
	install
	assert_installed
	assert_repo_untouched
'

add_case "existing config gets backed up" '
	make_old_config
	install
	assert_backed_up OLD_HYPR
	assert_backed_up OLD_EXTRA
	assert_backed_up OLD_ZSHRC
	assert_installed	# also fails if old files were left mixed with the new ones
'

add_case "running twice is safe" '
	make_old_config
	install
	install
	assert_installed
	assert_wallpapers_installed	# cp -r into an existing folder nests it: wallpapers/wallpapers
	assert_backed_up OLD_HYPR	# the first backup must not be overwritten
	assert_backed_up OLD_ZSHRC
	assert_repo_untouched
'

add_case "each run gets its own backup folder" '
	make_old_config
	install
	echo RUN2_HYPR > "$HOME/.config/hypr/hyprland.conf"	# user edits the installed config
	install
	echo RUN3_HYPR > "$HOME/.config/hypr/hyprland.conf"
	install

	folders=()
	for marker in OLD_HYPR RUN2_HYPR RUN3_HYPR; do
		file=$(grep -rls "$marker" "$HOME/.config/$BACKUP_DIR")
		[[ -n "$file" ]] || fail "backup containing $marker is missing"
		# the backup must keep the structure: <backup>/hypr/hyprland.conf
		[[ "$file" == */hypr/hyprland.conf ]] || fail "$marker backed up as $file, expected .../hypr/hyprland.conf"
		folders+=("$(dirname "$(dirname "$file")")")
	done
	(( $(printf "%s\n" "${folders[@]}" | sort -u | wc -l) == 3 )) || fail "the 3 backups are not in 3 separate folders: ${folders[*]}"
'

add_case "uninstall restores the old config" '
	grep -q -- "--uninstall" "$REPO/install.sh" || { echo "--uninstall not implemented yet"; exit 77; }
	make_old_config
	install
	install --uninstall
	grep -qs OLD_HYPR "$HOME/.config/hypr/hyprland.conf" || fail "old hyprland.conf not restored"
	grep -qs OLD_ZSHRC "$HOME/.zshrc" || fail "old .zshrc not restored"
	assert_no_broken_links
'

add_case "uninstall after a fresh install removes the rice" '
	grep -q -- "--uninstall" "$REPO/install.sh" || { echo "--uninstall not implemented yet"; exit 77; }
	install
	install --uninstall
	for dir in "${DIRECTORIES[@]}"; do
		[[ ! -e "$HOME/.config/$dir" ]] || fail "~/.config/$dir still installed (no backup existed, so it should be removed)"
	done
	[[ ! -e "$HOME/$WALLPAPERS_DIR" ]] || fail "~/$WALLPAPERS_DIR still installed"
	[[ ! -e "$HOME/.zshrc" ]] || fail "~/.zshrc from the rice still installed"
'

add_case "install twice, uninstall restores the original config" '
	grep -q -- "--uninstall" "$REPO/install.sh" || { echo "--uninstall not implemented yet"; exit 77; }
	make_old_config
	install
	install
	install --uninstall
	grep -qs OLD_HYPR "$HOME/.config/hypr/hyprland.conf" || fail "~/.config/hypr is not the original config: $(head -c 80 "$HOME/.config/hypr/hyprland.conf")"
	grep -qs OLD_ZSHRC "$HOME/.zshrc" || fail "~/.zshrc is not the original one"
'

add_case "existing wallpapers are backed up and restored" '
	grep -q -- "--uninstall" "$REPO/install.sh" || { echo "--uninstall not implemented yet"; exit 77; }
	mkdir -p "$HOME/$WALLPAPERS_DIR"
	echo MY_WALLPAPER > "$HOME/$WALLPAPERS_DIR/mine.png"
	install
	assert_backed_up MY_WALLPAPER
	assert_wallpapers_installed	# also fails if mine.png was left mixed with the rice ones
	install --uninstall
	grep -qs MY_WALLPAPER "$HOME/$WALLPAPERS_DIR/mine.png" || fail "user wallpaper not restored"
	[[ ! -e "$HOME/$WALLPAPERS_DIR/Oneshot1.png" ]] || fail "rice wallpapers still there after uninstall"
'

add_case "uninstall twice keeps the user config" '
	grep -q -- "--uninstall" "$REPO/install.sh" || { echo "--uninstall not implemented yet"; exit 77; }
	make_old_config
	install
	install --uninstall
	install --uninstall	# by mistake
	grep -qs OLD_HYPR "$HOME/.config/hypr/hyprland.conf" || fail "user hyprland.conf deleted by the 2nd uninstall"
	grep -qs OLD_ZSHRC "$HOME/.zshrc" || fail "user .zshrc deleted by the 2nd uninstall"
'

add_case "uninstall without install keeps the user config" '
	grep -q -- "--uninstall" "$REPO/install.sh" || { echo "--uninstall not implemented yet"; exit 77; }
	make_old_config
	install --uninstall	# rice was never installed
	grep -qs OLD_HYPR "$HOME/.config/hypr/hyprland.conf" || fail "user hyprland.conf deleted"
	grep -qs OLD_ZSHRC "$HOME/.zshrc" || fail "user .zshrc deleted"
'

add_case "uninstall after editing the rice loses nothing" '
	grep -q -- "--uninstall" "$REPO/install.sh" || { echo "--uninstall not implemented yet"; exit 77; }
	make_old_config
	install
	echo "# my tweak" >> "$HOME/.config/hypr/hyprland.conf"	# user edits the installed rice
	echo "# my alias" >> "$HOME/.zshrc"
	install --uninstall
	[[ ! -e "$HOME/.config/hypr/hypr" ]] || fail "backup restored INSIDE the edited config: ~/.config/hypr/hypr"
	grep -qs "my tweak" "$HOME/.config/hypr/hyprland.conf" || fail "user edit in hyprland.conf lost"
	grep -qs "my alias" "$HOME/.zshrc" || fail "user edit in .zshrc lost (overwritten by the backup)"
	assert_backed_up OLD_HYPR	# not restored, so the backup must still be there
	assert_backed_up OLD_ZSHRC
'

add_case "a backup with only .zshrc is kept" '
	echo OLD_ZSHRC > "$HOME/.zshrc"	# user has a .zshrc but no other config
	install
	assert_backed_up OLD_ZSHRC
'

# The configs reference wallpapers and assets by path:
# after installing, those paths must exist.
add_case "wallpapers + paths used in configs exist" '
	install
	assert_wallpapers_installed
	assert_config_paths_exist
'

add_case "no broken symlinks after install" '
	make_old_config
	install
	assert_no_broken_links
'

################
##### MAIN #####
################

command -v docker >/dev/null || { echo "${RED}docker is not installed${DEFAULT}"; exit 1; }
build_image

if [[ "${1:-}" == "--shell" ]]; then
	echo "Fresh container, repo copied to ~/.config/rice. Helpers from tests/helpers.sh are loaded."
	echo "Type 'exit' to leave, everything is deleted afterwards."
	open_shell
	exit
fi

filter="${1:-}"
passed=0 failed=0 skipped=0

for i in "${!CASE_NAMES[@]}"; do
	name="${CASE_NAMES[$i]}"
	[[ -n "$filter" && "$name" != *"$filter"* ]] && continue

	output=$(run_case "${CASE_CODES[$i]}" 2>&1)
	status=$?

	if (( status == 0 )); then
		echo "[${GREEN} PASS ${DEFAULT}] ${name}"
		(( passed++ ))
	elif (( status == 77 )); then
		echo "[${YELLOW} SKIP ${DEFAULT}] ${name}: ${output##*$'\n'}"
		(( skipped++ ))
	else
		echo "[${RED} FAIL ${DEFAULT}] ${name}"
		# Show the container output only for failures, indented
		sed 's/^/        | /' <<< "${output}" | tail -n 25
		(( failed++ ))
	fi
done

echo
echo "${passed} passed, ${failed} failed, ${skipped} skipped"
(( failed == 0 ))
