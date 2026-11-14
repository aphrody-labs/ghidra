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
#Requires -Version 7.0
# Creates a .pdb.xml file next to every .pdb file found (recursively) in the given path.
# Usage: createPdbXmlFiles.ps1 <path to .pdb file|path to directory of .pdb files>

# Production environment
$ghidraDir = Join-Path (Split-Path -Parent $PSScriptRoot) 'Ghidra'
$osDir = 'os'
if (-not (Test-Path -LiteralPath $ghidraDir)) {
	# Development environment
	$ghidraDir = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
	$osDir = 'build/os'
}

$pdbExe = Join-Path (Resolve-Path -LiteralPath $ghidraDir) "Features/PDB/$osDir/win_x86_64/pdb.exe"
if (-not (Test-Path -LiteralPath $pdbExe)) {
	[Console]::Error.WriteLine("$pdbExe not found")
	exit 1
}

if ($args.Count -lt 1 -or -not $args[0]) {
	[Console]::Error.WriteLine('Usage: createPdbXmlFiles.ps1 <path to .pdb file|path to directory of .pdb files>')
	exit 1
}

$target = [string]$args[0]
if (-not (Test-Path -LiteralPath $target)) {
	[Console]::Error.WriteLine("$target not found")
	exit 1
}

# Recursively traverse the given path; the .pdb.xml file lands next to its .pdb file
$pdbFiles = if (Test-Path -LiteralPath $target -PathType Container) {
	Get-ChildItem -LiteralPath $target -Recurse -File -Filter '*.pdb'
}
else {
	Get-Item -LiteralPath $target
}

$count = 0
foreach ($pdb in $pdbFiles) {
	if ($pdb.Extension -ne '.pdb') { continue }
	$xml = "$($pdb.FullName).xml"
	Write-Host "Processing file: $($pdb.FullName)"
	# Start-Process keeps the raw bytes of stdout (no re-encoding by the PowerShell pipeline)
	$p = Start-Process -FilePath $pdbExe -ArgumentList ('"' + $pdb.FullName + '"') -RedirectStandardOutput $xml -NoNewWindow -Wait -PassThru
	if ($p.ExitCode -ne 0) {
		# Delete the (empty) XML file that was just created
		Remove-Item -LiteralPath $xml -Force -ErrorAction SilentlyContinue
		if ($count -ge 1) { Write-Host "Error detected. Created $count .pdb.xml file(s) before exiting" }
		else { Write-Host 'Error detected. Exiting...' }
		exit 1
	}
	$count++
}

Write-Host "Created $count .pdb.xml file(s)."
