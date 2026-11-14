## ###
# IP: Apache License 2.0
##
#Requires -Version 7.0
# Gradle wrapper launcher (PowerShell 7 port of gradlew.bat); runs the same gradle-wrapper.jar.

$ErrorActionPreference = 'Stop'

function Fail([string]$Message) {
	[Console]::Error.WriteLine('')
	[Console]::Error.WriteLine("ERROR: $Message")
	[Console]::Error.WriteLine('')
	[Console]::Error.WriteLine('Please set the JAVA_HOME variable in your environment to match the')
	[Console]::Error.WriteLine('location of your Java installation.')
	exit 1
}

$appBaseName = [System.IO.Path]::GetFileNameWithoutExtension($PSCommandPath)
$appHome = $PSScriptRoot
$exeSuffix = if ($IsWindows) { '.exe' } else { '' }

# Resolve java
if ($env:JAVA_HOME) {
	$javaExe = Join-Path ($env:JAVA_HOME.Trim('"')) "bin/java$exeSuffix"
	if (-not (Test-Path -LiteralPath $javaExe)) { Fail "JAVA_HOME is set to an invalid directory: $($env:JAVA_HOME)" }
}
else {
	$javaExe = "java$exeSuffix"
	if (-not (Get-Command $javaExe -CommandType Application -ErrorAction SilentlyContinue)) {
		Fail "JAVA_HOME is not set and no 'java' command could be found in your PATH."
	}
}

if (Test-Path -LiteralPath (Join-Path $appHome 'gradle-wrapper.jar')) {
	# Production environment
	$jarPath = Join-Path $appHome 'gradle-wrapper.jar'
	$ghidraHome = Join-Path $appHome '../..'
}
else {
	# Development environment (Eclipse classes or "gradle jar")
	$jarPath = Join-Path $appHome 'Ghidra/RuntimeScripts/support/gradle/gradle-wrapper.jar'
	$ghidraHome = $appHome
}

# Read application.properties (key=value)
$props = @{}
foreach ($line in Get-Content -LiteralPath (Join-Path $ghidraHome 'Ghidra/application.properties')) {
	$key, $value = $line -split '=', 2
	if ($key -and $null -ne $value) { $props[$key.Trim()] = $value.Trim() }
}

$proceed = $true
if (Test-Path -LiteralPath (Join-Path $ghidraHome '../ghidra.bin')) { $proceed = $false }
if ($props['application.release.name'] -notin @('PUBLIC', 'DEV')) { $proceed = $false }
if (-not $proceed) {
	Write-Host "Please install Gradle $($props['application.gradle.min']) or later and put it on your PATH."
	exit 1
}

$jvmOpts = @('-Xmx64m', '-Xms64m')
foreach ($var in @($env:JAVA_OPTS, $env:GRADLE_OPTS)) {
	if ($var) { $jvmOpts += @($var -split '\s+' | Where-Object { $_ }) }
}

& $javaExe @jvmOpts "-Dorg.gradle.appname=$appBaseName" -jar $jarPath @args
exit $LASTEXITCODE
