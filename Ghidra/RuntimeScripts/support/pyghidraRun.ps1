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
# PyGhidra launch: finds a Python 3 interpreter and runs pyghidra_launcher.py

$vmArgList = (@($env:JDK_JAVA_OPTIONS, $env:GHIDRA_JAVA_OPTIONS, $env:PYGHIDRA_JAVA_OPTIONS, '-Dsun.java2d.dpiaware=true') | Where-Object { $_ }) -join ' '

$python = $null
foreach ($candidate in @('py', 'python3', 'python')) {
	if (Get-Command $candidate -CommandType Application -ErrorAction SilentlyContinue) { $python = $candidate; break }
}
if (-not $python) {
	[Console]::Error.WriteLine('Python 3 is not installed.')
	exit 1
}

$devArg = @()
$installDir = Split-Path -Parent $PSScriptRoot
if (-not (Test-Path -LiteralPath (Join-Path $installDir 'Ghidra'))) {
	$devArg = @('--dev')
	$installDir = Split-Path -Parent (Split-Path -Parent $installDir)
}

$launcher = Join-Path $installDir 'Ghidra/Features/PyGhidra/support/pyghidra_launcher.py'

& $python $launcher $installDir @devArg $vmArgList @args
exit $LASTEXITCODE
