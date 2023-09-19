#
###############################################################################################################################################
#
# ABOUT THIS PROGRAM
#
#	Down-And-Install.ps1
#	https://github.com/Headbolt/Down-And-Install
#
#   This Script is designed for use in Intunewin packages and was designed to Download
#	an MSI installer and install, or uninstall it
#
###############################################################################################################################################
#
#	Usage
#		Down-And-Install.ps1 [install|uninstall] <LocalFile> <downloadurl>
#		eg. Down-And-Install.ps1 install Zoom.msi https://zoom.com/installer.msi
#
###############################################################################################################################################
#
# HISTORY
#
#   Version: 1.0 - 19/09/2023
#
#	19/09/2023 - V1.0 - Created by Headbolt
#
###############################################################################################################################################
#
#   DEFINE VARIABLES & READ IN PARAMETERS
#
###############################################################################################################################################
#
$global:Action=$args[0] # Grab the Action Decision from variable #0 eg Install
$global:LocalFile=$args[1] # Grab the Local Filename to use from variable #1 eg Install
$global:URL=$args[2] # Grab the Download URL for the installer variable #2 eg. https://dl.ms.com/file.msi
#
$global:LocalFilePath="$Env:WinDir\temp\$global:LocalFile" # Construct Local File Path
$global:LocalLogFilePath="$global:LocalFilePath-$global:Action.log" # Construct Log File Path
#
$global:ScriptName="Application | Download and Install"
#
###############################################################################################################
#
#   Functions Definition
#
###############################################################################################################################################
#
#   Logging Function
#
function Logging
{
Start-Transcript $global:LocalLogFilePath # Start the logging
Clear-Host #Clear Screen
SectionEnd
Write-Host "Logging to $global:LocalLogFilePath"
}     
#
###############################################################################################################################################
#
# Download Check Function
#
function DownloadCheck
{
#
Download
SectionEnd
#
if (Test-Path -Path $global:LocalFilePath)
{
	If (-not((Get-Item $global:LocalFilePath).length -gt 0kb))
	{
		Write-Host 'Installer is zero size, possible URL Expansion Needed'
		SectionEnd
		Cleanup
		SectionEnd
		ExpandURL
		SectionEnd
		Download
	}
}
Else
{
	Write-Host 'Installer not detected, possible URL Expansion Needed'
	ExpandURL
	SectionEnd
	Download
}
#
}
#
###############################################################################################################################################
#
# Cleanup Function
#
function Cleanup
{
Write-Host 'Cleaning Up File'
Write-Host ''# Outputting a Blank Line for Reporting Purposes
Write-Host 'Running Command "Remove-Item '$global:LocalFilePath'"'
Remove-Item $global:LocalFilePath
#
}
#
###############################################################################################################################################
#
# Download Function
#
function Download
{
Write-Host 'Attempting Download'
Write-Host ''# Outputting a Blank Line for Reporting Purposes
Write-Host 'Running Command "curl.exe --output'$global:LocalFilePath' --url '$global:URL'"'
Write-Host ''# Outputting a Blank Line for Reporting Purposes
curl.exe --output $global:LocalFilePath --url $global:URL
#
}
#
###############################################################################################################################################
#
# URL Expansion Function
#
function ExpandURL
{
#
Write-Host 'Attempting to Expand URL'
Write-Host ''# Outputting a Blank Line for Reporting Purposes
Write-Host 'Original URL'
Write-Host "$global:URL"
$ExpandedURL=(curl.exe -m 5 -si $global:URL)
$ExpandedURLarray = $ExpandedURL -split ';'
$ExpandedURLlocation = ($ExpandedURLarray | out-string -stream | select-string 'location:')
$ExpandedURLlocationUnTrimmed = $ExpandedURLlocation -split 'location: ' 
$global:URL=$ExpandedURLlocationUnTrimmed -split ' '
Write-Host ''# Outputting a Blank Line for Reporting Purposes
Write-Host 'Expanded URL'
Write-Host $global:URL
#
}
#
###############################################################################################################################################
#
# Section End Function
#
function SectionEnd
{
#
Write-Host '' # Outputting a Blank Line for Reporting Purposes
Write-Host  '-----------------------------------------------' # Outputting a Dotted Line for Reporting Purposes
Write-Host '' # Outputting a Blank Line for Reporting Purposes
#
}
#
###############################################################################################################################################
#
# Script End Function
#
Function ScriptEnd
{
#
Write-Host Ending Script $global:ScriptName
Write-Host '' # Outputting a Blank Line for Reporting Purposes
Write-Host  '-----------------------------------------------' # Outputting a Dotted Line for Reporting Purposes
Write-Host ''# Outputting a Blank Line for Reporting Purposes
#
Stop-Transcript # Stop Logging
#
}
#
###############################################################################################################################################
#
# End Of Function Definition
#
###############################################################################################################################################
# 
# Begin Processing
#
###############################################################################################################################################
#
Logging
#
SectionEnd
DownloadCheck
#
SectionEnd
#
If ( $global:Action -eq "install" )
{
	Write-Host '"Install" action requested'
	Write-Host ''# Outputting a Blank Line for Reporting Purposes
	Write-Host 'Running Command "MsiExec.exe /i '$global:LocalFilePath /qn'"'
	Start-Process msiexec "/i $global:LocalFilePath /qn" -wait
	SectionEnd
}
#
If ( $global:Action -eq "uninstall" )
{
	Write-Host '"Un-Install" action requested'
	Write-Host ''# Outputting a Blank Line for Reporting Purposes
	Write-Host 'Running Command "MsiExec.exe /x '$global:LocalFilePath /qn'"'
	Start-Process msiexec "/x $global:LocalFilePath /qn" -wait
	SectionEnd
}
#
Cleanup
SectionEnd
ScriptEnd
