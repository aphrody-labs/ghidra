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
# Ghidra Headless Analyzer launch (see analyzeHeadlessREADME.md)

# Optionally override the default Java heap memory, which is typically 1/4 of system RAM.
# Supported values are of the form \d+[gGmMkK] (for example: 8G, 4096m).
# We override the default for headless in case users spin up many headless instances in parallel.
$maxMemDefault = '2G'

# Allow the above default to be overridden by externally set environment variables
# - GHIDRA_MAXMEM: Desired maximum heap memory for all Ghidra instances
# - GHIDRA_HEADLESS_MAXMEM: Desired maximum heap memory only for headless Ghidra instances
$maxMem = if ($env:GHIDRA_HEADLESS_MAXMEM) { $env:GHIDRA_HEADLESS_MAXMEM } elseif ($env:GHIDRA_MAXMEM) { $env:GHIDRA_MAXMEM } else { $maxMemDefault }

# Limit the # of garbage collection and JIT compiler threads in case many headless instances are
# run in parallel. By default, Java will assign one thread per core which does not scale well on
# servers with many cores.
$vmArgList = (@('-XX:ParallelGCThreads=2', '-XX:CICompilerCount=2', $env:GHIDRA_JAVA_OPTIONS, $env:GHIDRA_HEADLESS_JAVA_OPTIONS) | Where-Object { $_ }) -join ' '

# Launch mode can be changed to one of the following: fg, debug, debug-suspend
$launchMode = 'fg'

# Set the debug address to listen on.
# NOTE: This variable is ignored if not launching in a debugging mode.
$env:DEBUG_ADDRESS = '127.0.0.1:13002'

# Expand wildcards following -import ourselves: Windows shells do not do it for us.
$params = [System.Collections.Generic.List[string]]::new()
for ($i = 0; $i -lt $args.Count; $i++) {
	$arg = [string]$args[$i]
	if ($arg -eq '-import' -and $i + 1 -lt $args.Count) {
		$params.Add($arg)
		$i++
		$pattern = [string]$args[$i]
		$expanded = if ([WildcardPattern]::ContainsWildcardCharacters($pattern)) { @(Get-ChildItem -Path $pattern -Force -ErrorAction SilentlyContinue) } else { @() }
		if ($expanded.Count -gt 0) { foreach ($m in $expanded) { $params.Add($m.FullName) } }
		else { $params.Add($pattern) }
	}
	else {
		$params.Add($arg)
	}
}

& "$PSScriptRoot/launch.ps1" $launchMode jdk Ghidra-Headless $maxMem $vmArgList ghidra.app.util.headless.AnalyzeHeadless @params
exit $LASTEXITCODE
