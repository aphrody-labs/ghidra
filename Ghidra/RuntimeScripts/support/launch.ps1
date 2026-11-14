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
# Ghidra launcher (PowerShell 7 port of launch.bat).
# Usage: launch.ps1 <mode> <java-type> <name> <max-memory> "<vmarg-list>" <app-classname> <app-args>...
# Positional arguments are read from $args on purpose: application arguments such as -import
# must never be bound to script parameters.

function Show-Usage {
	[Console]::Error.WriteLine(@'
Usage: launch.ps1 <mode> <java-type> <name> <max-memory> "<vmarg-list>" <app-classname> <app-args>...
   <mode>: fg    run as foreground process in current shell
           bg    run as background process
           debug run as foreground process in debug mode (suspend=n)
           debug-suspend   run as foreground process in debug mode (suspend=y)
           NOTE: for all debug modes environment variable DEBUG_ADDRESS may be set to
                 override default debug address of 127.0.0.1:18001
   <java-type>: jdk  requires JDK to run
                jre  JRE is sufficient to run (JDK works too)
   <name>: application name used for naming the process
   <max-memory>: maximum heap size (e.g., 768M or 2G).  Use "" if default should be used.
   <vmarg-list>: pass-thru args (e.g., "-Xmx512M -Dmyvar=1 -DanotherVar=2") - use
                 empty "" if vmargs not needed
   <app-classname>: application classname (e.g., ghidra.GhidraRun)
   <app-args>...: arguments to be passed to the application

   Example:
      launch.ps1 debug jdk Ghidra 4G "" ghidra.GhidraRun
'@)
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

function Quote-Arg([string]$Arg) {
	# Start-Process joins ArgumentList without quoting
	if ($Arg -match '[\s"]') { return '"' + ($Arg -replace '"', '\"') + '"' }
	return $Arg
}

$launchArgs = @($args)
if ($launchArgs.Count -lt 6 -or [string]::IsNullOrEmpty([string]$launchArgs[5])) {
	[Console]::Error.WriteLine('ERROR: Incorrect launch usage - missing argument(s)')
	Show-Usage
}

$Mode = [string]$launchArgs[0]
$JavaTypeArg = if ([string]$launchArgs[1] -eq 'jre') { '-java_home' } else { '-jdk_home' }
$AppName = [string]$launchArgs[2]
$MaxMem = [string]$launchArgs[3]
$CallerVmArgs = [string]$launchArgs[4]
$ClassName = [string]$launchArgs[5]
$AppArgs = if ($launchArgs.Count -gt 6) { @($launchArgs[6..($launchArgs.Count - 1)] | ForEach-Object { [string]$_ }) } else { @() }

$ExeSuffix = if ($IsWindows) { '.exe' } else { '' }
$SupportDir = $PSScriptRoot

# Production environment
$InstallDir = Split-Path -Parent $SupportDir
$CPath = Join-Path $InstallDir 'Ghidra/Framework/Utility/lib/Utility.jar'
$LsCPath = Join-Path $SupportDir 'LaunchSupport.jar'
$DebugLog4j = Join-Path $SupportDir 'debug.log4j.xml'

if (-not (Test-Path -LiteralPath (Join-Path $InstallDir 'Ghidra/application.properties'))) {
	# Development environment (Eclipse classes or "gradle jar")
	$InstallDir = Split-Path -Parent (Split-Path -Parent $InstallDir)
	$CPath = Join-Path $InstallDir 'Ghidra/Framework/Utility/bin/main'
	$LsCPath = Join-Path $InstallDir 'GhidraBuild/LaunchSupport/bin/main'
	if (-not (Test-Path -LiteralPath $LsCPath)) {
		$CPath = Join-Path $InstallDir 'Ghidra/Framework/Utility/build/libs/Utility.jar'
		$LsCPath = Join-Path $InstallDir 'GhidraBuild/LaunchSupport/build/libs/LaunchSupport.jar'
	}
	if (-not (Test-Path -LiteralPath $LsCPath)) {
		[Console]::Error.WriteLine('ERROR: Cannot launch from repo because Ghidra has not been compiled with Eclipse or Gradle.')
		exit 1
	}
	$DebugLog4j = Join-Path $InstallDir 'Ghidra/RuntimeScripts/support/debug.log4j.xml'
}

$VmArgsFromLaunch = [System.Collections.Generic.List[string]]::new()

# Force Java to use the user profile directory for user.home
if ($env:USERPROFILE -and (Test-Path -LiteralPath $env:USERPROFILE)) {
	$VmArgsFromLaunch.Add("-Duser.home=$($env:USERPROFILE)")
}

# Check for java based upon PATH, then JAVA_HOME
$JavaCmd = "java$ExeSuffix"
if (-not (Test-Java $JavaCmd)) {
	$JavaCmd = $null
	if ($env:JAVA_HOME) {
		$candidate = Join-Path $env:JAVA_HOME "bin/java$ExeSuffix"
		if (Test-Java $candidate) { $JavaCmd = $candidate }
		else { Write-Warning "JAVA_HOME environment variable is set to an invalid directory: $($env:JAVA_HOME)" }
	}
	if (-not $JavaCmd) {
		[Console]::Error.WriteLine('')
		[Console]::Error.WriteLine("ERROR: The 'java' command could not be found in your PATH or with JAVA_HOME.")
		[Console]::Error.WriteLine("Please refer to the Getting Started document's Troubleshooting section.")
		exit 1
	}
}

# Use LaunchSupport to locate a supported java runtime
function Get-LsJavaHome {
	$lines = @(& $JavaCmd -cp $LsCPath LaunchSupport $InstallDir $JavaTypeArg -save)
	if ($lines.Count -eq 0) { return '' }
	return ([string]$lines[-1]).Trim()
}

$LsJavaHome = Get-LsJavaHome
if (-not $LsJavaHome) {
	# No JDK has been set up yet. Let the user choose one.
	& $JavaCmd -cp $LsCPath LaunchSupport $InstallDir $JavaTypeArg -ask
	$LsJavaHome = Get-LsJavaHome
	if (-not $LsJavaHome) {
		[Console]::Error.WriteLine('')
		[Console]::Error.WriteLine('ERROR: Failed to find a supported JDK.')
		[Console]::Error.WriteLine("Please refer to the Getting Started document's Troubleshooting section.")
		exit 1
	}
}
$JavaCmd = Join-Path $LsJavaHome "bin/java$ExeSuffix"

# Configurable environment variables from the launch properties (only set when undefined)
foreach ($line in @(& $JavaCmd -cp $LsCPath LaunchSupport $InstallDir -envvars)) {
	$key, $value = ([string]$line).Trim() -split '=', 2
	if ($key -and [string]::IsNullOrEmpty([Environment]::GetEnvironmentVariable($key))) {
		[Environment]::SetEnvironmentVariable($key, $value)
	}
}

# Configurable VM arguments from the launch properties
$VmArgsFromProps = @(& $JavaCmd -cp $LsCPath LaunchSupport $InstallDir -vmargs | ForEach-Object { ([string]$_).Trim() } | Where-Object { $_ })

if ($MaxMem) { $VmArgsFromLaunch.Add("-Xmx$MaxMem") }

$Background = $false
$Debug = $false
$Suspend = 'n'
switch ($Mode) {
	'fg' { }
	'bg' { $Background = $true }
	'debug' { $Debug = $true }
	'debug-suspend' { $Debug = $true; $Suspend = 'y' }
	default {
		[Console]::Error.WriteLine("ERROR: Incorrect launch usage - invalid launch mode: $Mode")
		exit 1
	}
}

if ($Debug) {
	$debugAddress = if ($env:DEBUG_ADDRESS) { $env:DEBUG_ADDRESS } else { '127.0.0.1:18001' }
	$VmArgsFromLaunch.Add("-Dlog4j.configurationFile=$DebugLog4j")
	$VmArgsFromLaunch.Add("-agentlib:jdwp=transport=dt_socket,server=y,suspend=$Suspend,address=$debugAddress")
}

# Caller vmargs: whitespace separated, double quotes group words
$VmArgsFromCaller = @([regex]::Matches($CallerVmArgs, '(?:[^\s"]+|"[^"]*")+') | ForEach-Object { $_.Value.Replace('"', '') })

$cmdArgs = @()
foreach ($extra in @($env:FORCE_JAVA_VERSION, $env:JAVA_USER_HOME_DIR_OVERRIDE)) {
	if ($extra) { $cmdArgs += $extra }
}
$cmdArgs += $VmArgsFromProps
$cmdArgs += $VmArgsFromLaunch
$cmdArgs += $VmArgsFromCaller
$cmdArgs += @('-cp', $CPath, 'ghidra.Ghidra', $ClassName)
$cmdArgs += $AppArgs

if ($Background) {
	$bgJava = "$JavaCmd"
	if ($IsWindows) { $bgJava = Join-Path $LsJavaHome 'bin/javaw.exe' }
	$proc = Start-Process -FilePath $bgJava -ArgumentList ($cmdArgs | ForEach-Object { Quote-Arg $_ }) -NoNewWindow -PassThru
	# If the process dies immediately, tell the user to run in foreground mode: background mode
	# hides all error output.
	if ($proc.WaitForExit(1000) -and $proc.ExitCode -ne 0) {
		Write-Host 'Exited with error.  Run in foreground (fg) mode for more details.'
		exit $proc.ExitCode
	}
	exit 0
}

& $JavaCmd @cmdArgs
exit $LASTEXITCODE
