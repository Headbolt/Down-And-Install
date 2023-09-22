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
#		Down-And-Install.ps1 [-install | -uninstall] -MSIName <msi name> -URL <download url> -appname <app name>
#		eg. Down-And-Install.ps1 -install -MSIName Zoom.msi -URL 'https://zoom.com/installer.msi?c="&"c='
#			note special characters in the url will need double quoting with the entire url single quoted
#
#		eg. Down-And-Install.ps1 -uninstall -appname 'Zoom'
#
###############################################################################################################################################
#
# HISTORY
#
#   Version: 1.1 - 22/09/2023
#
#	19/09/2023 - V1.0 - Created by Headbolt
#
#	22/09/2023 - V1.1 - Updated by Headbolt
#				Found a few instances where syntax of potential URL would not work
#				Re-Wrote to compensate and also improve notation, error checking
#
###############################################################################################################################################
#
#   DEFINE VARIABLES & READ IN PARAMETERS
#
###############################################################################################################################################
#
param (
	[switch]$Install,
	[switch]$Uninstall,
 	[string]$MSIName,
 	[string]$URL,
	[string]$AppName
)
#
$LocalLogFilePath="$Env:WinDir\temp\" # Set LogFile Patch
$global:ScriptName="Application | Download and Install" # Set ScriptName for logging
#
$global:URL=$URL # Pull URL into a Global Variable
$global:AppName=$AppName # Pull Appname into a Global Variable 
$global:LocalFilePath="$Env:WinDir\temp\$MSIName" # Construct Local File Path
#
If ( $Install )
{
#
$LocalLogFileType="_Install.log" # Set ActionType for Log File Path
$global:LocalLogFilePath=$LocalLogFilePath+$MSIName+$LocalLogFileType # Construct Log File Path
#
}
#
If ( $Uninstall )
{
#
$LocalLogFileType="_Uninstall.log" # Set ActionType for Log File Path
$global:LocalLogFilePath=$LocalLogFilePath+$AppName+$LocalLogFileType # Construct Log File Path
#
}
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
Clear-Host # Clear Screen
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
################################################################################################################################################
#
# RegScan Function
#
function RegScan
{
#
Write-Host "Searching for Uninstall String"
Write-Host '' # Outputting a Blank Line for Reporting Purposes
#
$Global:UninstallString=(Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall' | % { Get-ItemProperty $_.PsPath } | ? { $_.DisplayName -eq $AppName } | % { Write-Output $_.UninstallString } )
#
if ($Global:UninstallString)
{ 
	Write-Host "Found $UninstallString"
	Write-Host 'in "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"'
}
else
{ 
	Write-Host 'Nothing found in "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"'
	Write-Host '' # Outputting a Blank Line for Reporting Purposes
	Write-Host 'Checking "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall"'
	$Global:UninstallString=(Get-ChildItem 'HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall' | % { Get-ItemProperty $_.PsPath } | ? { $_.DisplayName -eq $AppName } | % { Write-Output $_.UninstallString } )
	if ($Global:UninstallString)
	{
		Write-Host '' # Outputting a Blank Line for Reporting Purposes
		Write-Host "Found $UninstallString"
		Write-Host 'in "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall"'
	}
	else
	{ 
		Write-Host "No Uninstall String Found"
	}
}
#
}
#
###############################################################################################################################################
#
# Uninstall Function
#
function Uninstall
{
#
[String]$UninstallCommand=(Write-Output $UninstallString.substring(12) /qn)
#
Write-Host 'Running Command "Start-Process msiexec.exe -Wait -ArgumentList'$UninstallCommand'"'
Start-Process msiexec.exe -Wait -ArgumentList $UninstallCommand
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
#
If ( $Install )
{
	Write-Host '"Install" action requested'
	SectionEnd
	If ( $URL ) # Check URL is set
	{
		If ( $MSIName ) # Check MSI Name is set
		{
			DownloadCheck
			Write-Host 'Running Command "MsiExec.exe /i '$global:LocalFilePath /qn'"'
			Start-Process msiexec "/i $global:LocalFilePath /qn" -wait
			SectionEnd
			Cleanup
		}
		else
		{
			Write-Host 'MSIName not set, cannot continue'
		}
	}
	else
	{
		Write-Host 'URL not set, cannot continue'
	}	
}
#
If ( $Uninstall )
{
	Write-Host '"Un-Install" action requested'
	SectionEnd
	If ( $AppName ) # Check App Name  is set
	{
		RegScan
		SectionEnd
		if ($Global:UninstallString)
		{
			Uninstall
		}
		else
		{
		Write-Host 'Cannot continue without Uninstall String'
		SectionEnd
		}
	}
	else
	{
		Write-Host 'App Name not set, cannot continue'
	}	
}
#
SectionEnd
ScriptEnd
