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
# Ghidra Server control: console | start | stop | restart | status | install | uninstall
param(
	[Parameter(Position = 0)]
	[string]$Option
)

$ErrorActionPreference = 'Stop'

function Show-Usage {
	[Console]::Error.WriteLine('')
	[Console]::Error.WriteLine('Usage: ghidraSvr.ps1 { console | start | stop | restart | status }')
	[Console]::Error.WriteLine('')
	exit 1
}

function Fail([string]$Message) {
	[Console]::Error.WriteLine('')
	[Console]::Error.WriteLine("ERROR: $Message")
	[Console]::Error.WriteLine('Please refer to the svrREADME documentation.')
	[Console]::Error.WriteLine('')
	if ($script:GhidraHome) {
		Add-Content -LiteralPath (Join-Path $script:GhidraHome 'wrapper.log') -Value "ERROR: $Message"
	}
	exit 1
}

function Test-Java([string]$Exe) {
	try {
		& $Exe -version *> $null
		return ($LASTEXITCODE -eq 0)
	}
	catch {
		return $false
	}
}

if (-not $Option) { Show-Usage }

# The following command options require admin
if ($Option -in @('start', 'stop', 'install', 'uninstall', 'restart') -and $IsWindows) {
	$principal = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
	if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
		[Console]::Error.WriteLine('')
		[Console]::Error.WriteLine("Command option ""$Option"" must be run as an Administrator (using an Administrator shell - see svrREADME.md)")
		[Console]::Error.WriteLine('')
		exit 1
	}
}

$serverDir = $PSScriptRoot
$appLongName = 'Ghidra Server'
$moduleDir = 'Ghidra/Features/GhidraServer'
$wrapperNamePrefix = 'yajsw'
$wrapperTmpDir = [System.IO.Path]::GetTempPath().TrimEnd('\', '/')
$script:GhidraHome = $null

if (Test-Path -LiteralPath (Join-Path $serverDir '../Ghidra') -PathType Container) {
	# Production environment
	$script:GhidraHome = Split-Path -Parent $serverDir
	$dataDir = Join-Path $GhidraHome "$moduleDir/data"
	$lsCPath = Join-Path $GhidraHome 'support/LaunchSupport.jar'
}
else {
	# Development environment
	$script:GhidraHome = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $serverDir))
	$dataDir = Join-Path $GhidraHome "$moduleDir/build/data"
	$lsCPath = Join-Path $GhidraHome 'GhidraBuild/LaunchSupport/bin/main'
	if (-not (Test-Path -LiteralPath $lsCPath)) {
		$lsCPath = Join-Path $GhidraHome 'GhidraBuild/LaunchSupport/build/libs/LaunchSupport.jar'
	}
	if (-not (Test-Path -LiteralPath $lsCPath)) {
		Fail 'Cannot launch from repo because Ghidra has not been compiled with Eclipse or Gradle.'
	}
}
$wrapperConf = Join-Path $serverDir 'server.conf'

$wrapperDir = Get-ChildItem -LiteralPath $dataDir -Directory -ErrorAction SilentlyContinue |
	Where-Object { $_.Name.StartsWith($wrapperNamePrefix) } | Select-Object -Last 1
if (-not $wrapperDir) {
	[Console]::Error.WriteLine('')
	[Console]::Error.WriteLine("$wrapperNamePrefix not found")
	[Console]::Error.WriteLine('')
	exit 1
}
$wrapperHome = $wrapperDir.FullName
Write-Host "Using service wrapper: $($wrapperDir.Name)"

$exeSuffix = if ($IsWindows) { '.exe' } else { '' }

if ($env:GHIDRA_JAVA_HOME) {
	$java = Join-Path $env:GHIDRA_JAVA_HOME "bin/java$exeSuffix"
	if (-not (Test-Java $java)) {
		Fail "The ghidraSvr script GHIDRA_JAVA_HOME variable is set to an invalid directory: $($env:GHIDRA_JAVA_HOME)"
	}
	& $java -cp $lsCPath LaunchSupport $GhidraHome -java_home_check $env:GHIDRA_JAVA_HOME
	if ($LASTEXITCODE -ne 0) {
		Fail "The ghidraSvr script GHIDRA_JAVA_HOME variable specifies an invalid or unsupported Java runtime: $($env:GHIDRA_JAVA_HOME)"
	}
}
else {
	$java = "java$exeSuffix"
	if (-not (Test-Java $java)) {
		$java = $null
		if ($env:JAVA_HOME) {
			$candidate = Join-Path $env:JAVA_HOME "bin/java$exeSuffix"
			if (Test-Java $candidate) { $java = $candidate }
			else { Write-Warning "JAVA_HOME environment variable is set to an invalid directory: $($env:JAVA_HOME)" }
		}
		if (-not $java) {
			Fail "The ghidraSvr script GHIDRA_JAVA_HOME variable is not set and 'java' command could not be found in your PATH or with JAVA_HOME."
		}
	}
	$lsJavaHome = @(& $java -cp $lsCPath LaunchSupport $GhidraHome -java_home) | Select-Object -Last 1
	if (-not $lsJavaHome) { Fail 'Unable to find a supported Java runtime on your system.' }
	$java = Join-Path ([string]$lsJavaHome).Trim() "bin/java$exeSuffix"
}

$vmArgs = @('-Xmx512M', "-Djava.io.tmpdir=$wrapperTmpDir", "-Djna_tmpdir=$wrapperTmpDir")
$wrapperJar = Join-Path $wrapperHome 'wrapper.jar'
$debugArgs = @($env:DEBUG | Where-Object { $_ })

function Invoke-Wrapper([string]$Flag) {
	& $java @vmArgs @debugArgs -jar $wrapperJar $Flag $wrapperConf
}

switch ($Option) {
	'console' {
		$procArgs = @($vmArgs) + $debugArgs + @('-jar', $wrapperJar, '-c', $wrapperConf)
		Start-Process -FilePath $java -ArgumentList ($procArgs | ForEach-Object { if ($_ -match '\s') { '"' + $_ + '"' } else { $_ } })
		Write-Host 'Use Ctrl-C in Ghidra Console to terminate...'
	}
	'status' { Invoke-Wrapper '-q' }
	'start' { Invoke-Wrapper '-t' }
	'stop' { Invoke-Wrapper '-p' }
	'restart' { Invoke-Wrapper '-p'; Invoke-Wrapper '-t' }
	'install' { Invoke-Wrapper '-i'; Invoke-Wrapper '-t' }
	'uninstall' { Invoke-Wrapper '-r' }
	default { Show-Usage }
}
