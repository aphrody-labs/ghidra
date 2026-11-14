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
$ghidraRootDir = Join-Path (Split-Path -Parent $PSScriptRoot) 'Ghidra'
if (-not (Test-Path -LiteralPath $ghidraRootDir)) {
	[Console]::Error.WriteLine('This script does not support development mode use')
	exit 1
}

$name = [System.IO.Path]::GetFileNameWithoutExtension($PSCommandPath)
& "$PSScriptRoot/launch.ps1" fg jdk Ghidra '' "-DGhidraJarBuilder.Name=$name" ghidra.util.GhidraJarBuilder -main ghidra.JarRun @args
exit $LASTEXITCODE
