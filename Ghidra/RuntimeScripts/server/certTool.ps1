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
$name = [System.IO.Path]::GetFileNameWithoutExtension($PSCommandPath)
& "$PSScriptRoot/../support/launch.ps1" fg jre certTool 128M "-DCertTool.invocation=$name -Djava.awt.headless=true" ghidra.net.CertTool @args
exit $LASTEXITCODE
