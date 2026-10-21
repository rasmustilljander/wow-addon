#!/usr/bin/env bash
# Copies the addons in this repo into the game's AddOns folder, set as
# WOW_ADDONS_DIR in .env (see .env.example). Each addon folder is replaced
# with the repo's copy; other addons and SavedVariables aren't touched.
#
#   ./deploy.sh                  every addon
#   ./deploy.sh TravelLog KillXP only these
#   ./deploy.sh -n               show what would change
set -euo pipefail
cd "$(dirname "$0")"

dry=()
if [[ "${1:-}" == "-n" ]]; then
	dry=(--dry-run)
	shift
fi

if [[ ! -f .env ]]; then
	echo "No .env: copy .env.example to .env and set WOW_ADDONS_DIR." >&2
	exit 1
fi
set -a
source .env
set +a
dest="${WOW_ADDONS_DIR:?WOW_ADDONS_DIR is not set in .env}"
dest="${dest%/}"

# A local folder must exist; user@host:path goes over ssh and rsync checks it.
if [[ "$dest" != *:* || "$dest" == /* ]] && [[ ! -d "$dest" ]]; then
	echo "$dest doesn't exist." >&2
	exit 1
fi

# An addon is a folder with a .toc of the same name.
addons=("$@")
if [[ ${#addons[@]} -eq 0 ]]; then
	for toc in */*.toc; do
		name="${toc%%/*}"
		[[ "$toc" == "$name/$name.toc" ]] && addons+=("$name")
	done
fi

for name in "${addons[@]}"; do
	if [[ ! -f "$name/$name.toc" ]]; then
		echo "$name isn't an addon in this repo." >&2
		exit 1
	fi
	# Folders linked to the repo (see README) are already up to date.
	if [[ -L "$dest/$name" ]]; then
		echo "$name: linked, skipped"
		continue
	fi
	rsync -a --delete --exclude '*.md' "${dry[@]}" --itemize-changes "$name/" "$dest/$name/" | sed "s|^|$name: |"
done

echo "Deployed $(git describe --always --dirty) to $dest. /reload in game to load it."
