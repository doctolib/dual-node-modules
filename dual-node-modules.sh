#!/bin/bash

set -e

case $(uname) in
	Darwin)
		os_code='bsd'
		;;
	Linux)
		os_code='linux'
		;;
	*)
		echo -e '\x1b[91;1mYour OS is not supported.\x1b[0m'
		;;
esac

make_mounts_bsd() {
	if ! command -v bindfs >/dev/null
	then
		echo -e '\x1b[92;1mWill install bindfs. You will need to reboot.\x1b[0m'
		if brew cask install osxfuse && brew install bindfs
		then
			echo -e '\x1b[92;1mNow you need to reboot.\x1b[0m'
			exit
		else
			echo -e '\x1b[91;1mFailed to install either osxfuse or bindfs.\x1b[0m'
			exit 1
		fi
	fi
	mkdir -p "$dir_original/node_modules" "$dir_mirror" "$dir_node_modules"
	bindfs --no-allow-other "$dir_original" "$dir_mirror"
	bindfs --no-allow-other -o allow_recursion "$dir_node_modules" "$dir_mirror/node_modules"
}

make_mounts_linux() {
	mkdir -p "$dir_original/node_modules" "$dir_mirror" "$dir_node_modules"
	sudo mount --bind "$dir_node_modules" "$dir_original/node_modules"
	sudo mount --bind "$dir_original" "$dir_mirror" # bind mount ignores mounts in source dirtree
}

unmake_mounts_bsd() (
	set +e
	umount "$dir_mirror/node_modules"
	umount "$dir_mirror"
)

unmake_mounts_linux() {
	sudo umount "$dir_mirror"
	sudo umount "$dir_original/node_modules"
}

usage() {
	1>&2 cat <<-EOF
	usage: $0 [DIRECTORY] [on|off]

	Bind-mounts directories so that two Node.JS projects are the same directory
	except for their node_modules directory.
	EOF
}

main() {
	local directory="$1.base"
	local cmd="$2"
	if [[ "$#" != 2 ]]
	then
		usage "$@"
		exit
	elif [[ ! -d "$directory" ]]
	then
		1>&2 echo "Folder '$directory' does not exist."
		exit 1
	elif [[ ! -d "$directory/node_modules" ]]
	then
		1>&2 echo "Directory '$directory' does not have a 'node_modules' sub-directory."
		exit 1
	fi
	cd "$directory/.."
	directory="$(basename "$directory")"
	dir_original="$directory"
	dir_mirror="$1"
	dir_node_modules=".$dir_original.node_modules"
	case $cmd in
		on)
			make_mounts_$os_code "$directory"
			;;
		off)
			unmake_mounts_$os_code "$directory"
			;;
		*)
			usage "$@"
			;;
	esac
}

main "$@"
