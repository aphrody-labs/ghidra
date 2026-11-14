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
# Ghidra launch

# Optionally override the default Java heap memory, which is typically 1/4 of system RAM.
# Supported values are of the form \d+[gGmMkK] (for example: 8G, 4096m).
$maxMemDefault = ''

# Allow the above default to be overridden by externally set environment variables
# - GHIDRA_MAXMEM: Desired maximum heap memory for all Ghidra instances
# - GHIDRA_GUI_MAXMEM: Desired maximum heap memory only for this kind of instance
$maxMem = if ($env:GHIDRA_GUI_MAXMEM) { $env:GHIDRA_GUI_MAXMEM } elseif ($env:GHIDRA_MAXMEM) { $env:GHIDRA_MAXMEM } else { $maxMemDefault }

# Apply Java options from externally set environment variables
$vmArgList = (@($env:GHIDRA_JAVA_OPTIONS, $env:GHIDRA_GUI_JAVA_OPTIONS) | Where-Object { $_ }) -join ' '

& "$PSScriptRoot/support/launch.ps1" bg jdk Ghidra $maxMem $vmArgList ghidra.GhidraRun @args
exit $LASTEXITCODE
