#!/usr/bin/env bash
## ###
# IP: GHIDRA
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
##
set -euo pipefail
# Creates a .pdb.xml file next to every .pdb file found (recursively) in the given path.
# pdb.exe is a Windows executable: run this where Windows executables can be launched
# (WSL interop, Wine via binfmt_misc, MSYS2/Git Bash on Windows).
# Usage: createPdbXmlFiles.sh <path to .pdb file|path to directory of .pdb files>

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# Production environment
ghidra_dir="$script_dir/../Ghidra"
os_dir=os
if [[ ! -d "$ghidra_dir" ]]; then
	# Development environment
	ghidra_dir="$script_dir/../../.."
	os_dir=build/os
fi
ghidra_dir="$(cd -- "$ghidra_dir" && pwd)"

pdb_exe="$ghidra_dir/Features/PDB/$os_dir/win_x86_64/pdb.exe"
if [[ ! -f "$pdb_exe" ]]; then
	echo "$pdb_exe not found" >&2
	exit 1
fi

if [[ $# -lt 1 || -z "$1" ]]; then
	echo "Usage: createPdbXmlFiles.sh <path to .pdb file|path to directory of .pdb files>" >&2
	exit 1
fi

target="$1"
if [[ ! -e "$target" ]]; then
	echo "$target not found" >&2
	exit 1
fi

count=0
while IFS= read -r -d '' pdb; do
	echo "Processing file: $pdb"
	if ! "$pdb_exe" "$pdb" > "$pdb.xml"; then
		rm -f -- "$pdb.xml"
		if (( count >= 1 )); then
			echo "Error detected. Created $count .pdb.xml file(s) before exiting"
		else
			echo "Error detected. Exiting..."
		fi
		exit 1
	fi
	count=$((count + 1))
done < <(find "$target" -type f -name '*.pdb' -print0)

echo "Created $count .pdb.xml file(s)."
