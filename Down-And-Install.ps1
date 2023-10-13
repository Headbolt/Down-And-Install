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
# 		Note as IntuneWin are 32 Bit Apps, powershell in the App Command will need to be forced to Native
#			Otherwise Reg Searches for Uninstall commands in HKLM:\SOFTWARE\Microsoft
#			may get redirected to HKLM:\SOFTWARE\Wow6432Node\Microsoft, resulting in uninstallers not being found
#			so call powershell like this
#			%windir%\SysNative\WindowsPowershell\v1.0\PowerShell.exe -executionpolicy bypass -command ./Down-And-Install.ps1
#
###############################################################################################################################################
#
#	Usage
#		Down-And-Install.ps1 [-install | -uninstall] -MSIName <msi name> -ExeName <exe name> -Args <arguments> -URL <download url> -appname <app name>
#			Note -InstallArgs is optional
#		eg. Down-And-Install.ps1 -install -MSIName Zoom.msi -Args 'ACTID={aa}' -URL 'https://zoom.com/installer.msi?c="&"c='
#		eg. Down-And-Install.ps1 -install -ExeName Zoom.exe -Args 'ACTID={aa}' -URL 'https://zoom.com/installer.msi?c="&"c='
#				note special characters in the url will need double quoting with the entire url single quoted
#
#		eg. Down-And-Install.ps1 -uninstall -appname 'Zoom'
#
###############################################################################################################################################
#
# HISTORY
#
#   Version: 1.5 - 13/10/2023
#
#	19/09/2023 - V1.0 - Created by Headbolt
#
#	22/09/2023 - V1.1 - Updated by Headbolt
#				Found a few instances where syntax of potential URL would not work
#				Re-Wrote to compensate and also improve notation, error checking
#
#	22/09/2023 - V1.2 - Updated by Headbolt
#				Minor Syntax error when used in very specific cases
#
#	04/10/2023 - V1.3 - Updated by Headbolt
#				Added option for additional Arguments to pass to install command
#
#	04/10/2023 - V1.4 - Updated by Headbolt
#				Added option for .EXE installers and Uninstallers
#
#	13/10/2023 - V1.5 - Updated by Headbolt
#				Fixed a few syntax errors
#				Also Issue Found where some Intune Deployments are putting "/qn" in the ExeName Variable, when it is not set !!!
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
 	[string]$ExeName,
 	[string]$Args,
 	[string]$URL,
	[string]$AppName
)
#
$global:ScriptVer="1.5" # Set ScriptVersion for logging
#
$global:LocalLogFilePath="$Env:WinDir\temp\" # Set LogFile Patch
$global:ScriptName="Application | Download and Install" # Set ScriptName for logging
$global:URL=$URL # Pull URL into a Global Variable
$global:MSIName=$MSIName # Pull MSIName into a Global Variable
$global:ExeName=$ExeName # Pull ExeName into a Global Variable 
$global:AppName=$AppName # Pull Appname into a Global Variable 
#
If ( $Args )
{
	$global:Args=" $Args" # Pull Arguments into a Global Variable, adding a leading space
}
#
																			 
 
If ( $global:MSIName )
{
#
	$global:Name=$global:MSIName
	$global:LocalFilePath="$Env:WinDir\temp\$global:MSIName" # Construct Local File Path
#
}
#
If ( $global:ExeName )
{
#
	If ( "$global:ExeName" -eq "/qn" ) # Check if Machine interprets no ExeName incorrectly
	{
		$global:ExeName -eq ""
	}
	Else
	{
		$global:Name=$global:ExeName
		$global:LocalFilePath="$Env:WinDir\temp\$global:ExeName" # Construct Local File Path
	}
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
#	
If ( $Install )
{
	$LocalLogFileType="_Install.log" # Set ActionType for Log File Path
	$global:LocalLogFilePath=$global:LocalLogFilePath+$global:Name+$LocalLogFileType # Construct Log File Path
}
#
If ( $Uninstall )
{
	$LocalLogFileType="_Uninstall.log" # Set ActionType for Log File Path
	$global:LocalLogFilePath=$global:LocalLogFilePath+$global:AppName+$LocalLogFileType # Construct Log File Path
}
#
Start-Transcript $global:LocalLogFilePath # Start the logging
Clear-Host # Clear Screen
SectionEnd
Write-Host "Logging to $global:LocalLogFilePath"
Write-Host ''# Outputting a Blank Line for Reporting Purposes
Write-Host "Script Version $global:ScriptVer"
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
  		SectionEnd
	}
}
Else
{
	Write-Host 'Installer not detected, possible URL Expansion Needed'
	SectionEnd
	ExpandURL
	SectionEnd
	Download
 	SectionEnd
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
Write-Host "Searching for Uninstall String for $Global:AppName"
Write-Host '' # Outputting a Blank Line for Reporting Purposes
#
$Global:UninstallString=(Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall' | Foreach-Object { Get-ItemProperty $_.PsPath } | Where-Object { $_.DisplayName -eq "$Global:AppName" } | Foreach-Object { Write-Output $_.UninstallString } )
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
	$Global:UninstallString=(Get-ChildItem 'HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall' | Foreach-Object { Get-ItemProperty $_.PsPath } | Where-Object { $_.DisplayName -eq "$Global:AppName" } | Foreach-Object { Write-Output $_.UninstallString } )
	if ($Global:UninstallString)
	{
		Write-Host '' # Outputting a Blank Line for Reporting Purposes
		Write-Host "Found $UninstallString"
		Write-Host 'in "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall"'
	}
	else
	{
		Write-Host '' # Outputting a Blank Line for Reporting Purposes
		Write-Host "No Uninstall String Found"
	}
}
#
}
#
###############################################################################################################################################
#
# MSI Install Function
#
function MSIinstall
{
#
Write-Host 'Attempting MSI Install'
SectionEnd
DownloadCheck
Write-Host 'Running Command "MsiExec.exe /i '$global:LocalFilePath$global:Args /qn'"'
Start-Process msiexec "/i $global:LocalFilePath$global:Args /qn" -wait
SectionEnd
Cleanup
#
}
#
###############################################################################################################################################
#
# EXE Install Function
#
function ExeInstall
{
#
Write-Host 'Attempting EXE Install'
SectionEnd
DownloadCheck
Write-Host 'Running Command "'$global:LocalFilePath$global:Args'"'
Start-Process "$global:LocalFilePath$global:Args" -wait
SectionEnd
Cleanup
#
}
#
###############################################################################################################################################
#
# MSI Uninstall Function
#
function MSIUninstall
{
#
[String]$UninstallCommand=(Write-Output $UninstallString.substring(12) /qn)
#
if ($UninstallCommand.ToLower().Contains("/i"))
{
	Write-Host 'Uninstall Command calls for MSIEXEC /I "'$UninstallString '"'
	Write-Host 'Converting it to /X for UnInstall'
	$UninstallCommand = $UninstallCommand.Replace('/I','/X')
	Write-Host 'Running Command "Start-Process msiexec.exe -Wait -ArgumentList'$UninstallCommand'"'
	Start-Process msiexec.exe -Wait -ArgumentList $UninstallCommand
}
#
}
#
###############################################################################################################################################
#
# EXE Uninstall Function
#
function EXEUninstall
{
#
Write-Host 'Running Command "'$UninstallString'"'
Start-Process $UninstallString -Wait
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
		If ( $global:MSIName ) # Check MSI Name is set
		{
			MSIinstall
		}
		else
		{
			Write-Host 'MSI Name not set, MSI Install cannot continue'
			SectionEnd
			#
			If ( $global:ExeName ) # Check App Name is set
			{
				ExeInstall
			}
			else
			{
				Write-Host 'EXE Name not set, EXE Install cannot continue'
			}
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
	If ($Global:AppName ) # Check App Name  is set
	{
		RegScan
		SectionEnd
		if ($Global:UninstallString)
		{
			if ($Global:UninstallString.ToLower().Contains("msiexec"))
			{
				MSIUninstall
			}
			else
			{
				ExeUninstall
			}
		}
		else
		{
		Write-Host 'Cannot continue without Uninstall String'
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
