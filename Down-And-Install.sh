#!/bin/bash
#
###############################################################################################################################################
#
# ABOUT THIS PROGRAM
#
#	Down-And-Install.sh
#	https://github.com/Headbolt/Down-And-Install
#
#   This Script is designed for use in JAMF and was designed to Download an App installer and install it
#
#	The Following Variables should be defined
#	Variable 4 - Named "Download URL for Client Connector - eg. https://api-cloudstation-us-east-2.prod.hydra.sophos.com/api/download/SophosInstall.zip"
#	Variable 5 - Named "Install Command - eg. Sophos Installer - OPTIONAL"
#	Variable 6 - Named "Installer Switches - eg. --quiet - OPTIONAL"
#
###############################################################################################################################################
#
# HISTORY
#
#   Version: 1.1 - 15/11/2022
#
#	05/10/2022 - V1.0 - Created by Headbolt
#
#	15/11/2022 - V1.1 - Updated by Headbolt
#							Legislating for "Hotlink's that always point at the latest version"
#
###############################################################################################################################################
#
#   DEFINE VARIABLES & READ IN PARAMETERS
#
###############################################################################################################################################
#
DownloadURL=$4 # Grab the Download URL for the installer from JAMF variable #4 eg. https://api-cloudstation-us-east-2.prod.hydra.sophos.com/api/download/SophosInstall.zip
AppInstallerCommand=$5 # Grab the Install Command, if needed from JAMF variable #5 eg. Sophos Installer
AppInstallerSwitches=$6  # Grab the Installer Switches, if needed from JAMF variable #6 eg. --quiet
#
ScriptName="Application | Download and Install"
ExitCode=0
#
###############################################################################################################################################
#
#   Checking and Setting Variables Complete
#
###############################################################################################################################################
# 
# SCRIPT CONTENTS - DO NOT MODIFY BELOW THIS LINE
#
###############################################################################################################################################
#
# Defining Functions
#
###############################################################################################################################################
#
# Evaluate Download Function
#
EvaluateDownload(){
#
/bin/echo 'Checking the Installer'
/bin/echo # Outputting a Blank Line for Reporting Purposes
Hotlink="NO" # Ensuring Hotlink is not carried over in the event of a Re-Evaluation Being Needed
#
IFS='/' # Internal Field Seperator Delimiter is set to forward slash (/)
if [ $ZSH_VERSION ] # Check if shell is ZSH and if so enable IFS
	then
		setopt sh_word_split
fi
#
DownloadFile=$(/bin/echo $DownloadURL | rev | awk '{print $1}' | rev) # Reverse the Download string, grab the first section and reverse again
IFS='.' # Internal Field Seperator Delimiter is set to dot (.)
DownloadFileName=$(/bin/echo $DownloadFile | awk '{print $1}') # Grab the FileName string, grab the filename
# Grab the FileName string, ensure its all in lowercase, grab the file extension and reverse again
DownloadExt=$(/bin/echo $DownloadFile |  tr '[:upper:]' '[:lower:]' | rev | awk '{print $1}' | rev)
#
if [ $DownloadFileName == $DownloadExt ] # Check if link is a "HotLink"
	then
		/bin/echo 'Download FileName and Download Extension match'
		/bin/echo 'This Download link does not include the Extension'
        /bin/echo 'Assuming it is a "HotLink"'
        Hotlink="YES"
	else
		/bin/echo 'Installer is a .'$DownloadExt # Output the file extension for reporting
fi
IFS=' ' # Internal Field Seperator Delimiter is set to space ( )
unset ifs # set the IFS back to normal
#
}
#
###############################################################################################################################################
#
# Download Function
#
Download(){
#
/bin/echo 'Downloading the Installer'
/bin/echo # Outputting a Blank Line for Reporting Purposes
#
if [ $Hotlink == "YES" ] # If link is a "HotLink" process accordingly to pull out required information
	then
		/bin/echo "Download URL is a Hotlink, following Link to find proper download URL and FileName"
        # Check Hotlink and find the actual Download we need, also legislate for occasional carriage reurn at end
		HotlinkResolvedURL=$(curl -m 5 -si $DownloadURL | awk '($1 == "Location:") { print $NF; exit }' | sed $'s/\r$//')
        /bin/echo # Outputting a Blank Line for Reporting Purposes
        /bin/echo "Changing Download URL"
        /bin/echo "From..."
        /bin/echo $DownloadURL
        /bin/echo "To..."
        /bin/echo $HotlinkResolvedURL
        DownloadURL="$HotlinkResolvedURL"
		/bin/echo # Outputting a Blank Line for Reporting Purposes
        /bin/echo "Sending new URL for Re-Evaluation"
		SectionEnd
		EvaluateDownload
        SectionEnd
        /bin/echo 'NOW Downloading the Installer'
		/bin/echo # Outputting a Blank Line for Reporting Purposes
fi
#
/bin/echo 'Creating Temporary Working Folder "/tmp/'$DownloadFileName'"'
mkdir "/tmp/$DownloadFileName"
/bin/echo 'Changing to Temporary Working Folder "/tmp/'$DownloadFileName'"'
cd "/tmp/$DownloadFileName"
#
/bin/echo # Outputting a Blank Line for Reporting Purposes
/bin/echo 'Downloading the installer'
/bin/echo # Outputting a Blank Line for Reporting Purposes
/bin/echo 'Running command "curl -L -O '$DownloadURL'"'
/bin/echo # Outputting a Blank Line for Reporting Purposes
curl -L -O "$DownloadURL"
#
}
#
###############################################################################################################################################
#
# Unzip Function
#
UnZip(){
#
/bin/echo 'UnZipping file "'$DownloadFile'"'
/bin/echo # Outputting a Blank Line for Reporting Purposes
/bin/echo 'Running Command "'unzip $DownloadFile'"'
/bin/echo # Outputting a Blank Line for Reporting Purposes
unzip $DownloadFile
#
}
#
###############################################################################################################################################
#
# Installer App Function
#
InstallerApp(){
#
InstallerApp=$(ls "/tmp/$DownloadFileName" | grep ".app") # Search for the Installer .app
chmod a+x "/tmp/$DownloadFileName/$InstallerApp/Contents/MacOS" # correcting permissions inside the installer
/bin/echo 'Installing "'$InstallerApp'"'
/bin/echo # Outputting a Blank Line for Reporting Purposes
/bin/echo 'Running Command "'sudo /tmp/$DownloadFileName/$InstallerApp/$AppInstallerCommand $AppInstallerSwitches'"'
/bin/echo # Outputting a Blank Line for Reporting Purposes
sudo "/tmp/$DownloadFileName/$InstallerApp/$AppInstallerCommand" $AppInstallerSwitches # Install App
#
}
#
###############################################################################################################################################
#
# pkg Install Function
#
pkgInstall(){
#
/bin/echo 'Installing "'$DownloadFile'"'
/bin/echo # Outputting a Blank Line for Reporting Purposes
#
if [ $Hotlink == "YES" ] # If link is a "HotLink" set a default name for Working Folder
	then
		/bin/echo 'Changing to Temporary Working Folder "/tmp/'$DownloadFileName/temp'"'
		cd "/tmp/$DownloadFileName/temp"
        ls -al
	else
		pkgutil --expand $DownloadFile "/tmp/$DownloadFileName/temp" # Extract a copy of the app
fi
#
/bin/echo 'Running Command "'sudo /usr/sbin/installer -pkg $DownloadFile -target /'"'
/bin/echo # Outputting a Blank Line for Reporting Purposes
sudo /usr/sbin/installer -pkg $DownloadFile -target / # Install App
#
#Find the Name of the App as it will appear when installed
AppName=$(cat "/tmp/$DownloadFileName/temp/Distribution" | grep '<title>' | sed "s@.*<title>\(.*\)</title>.*@\1@" )
AppPath=$(/bin/echo $AppName.app ) # Translate into the full App name for the attribute section
/bin/echo # Outputting a Blank Line for Reporting Purposes
/bin/echo 'Clearing Attriubtes on Installed App'
/bin/echo 'Running Command "xattr -rc /Applications/'$AppPath'"'
xattr -rc "/Applications/$AppPath" # Clear Attriubtes on Installed App
#
}
#
###############################################################################################################################################
#
# Cleanup Function
#
Cleanup(){
#
/bin/echo 'Cleaning up Temporary Working Folder "/tmp/'$DownloadFileName'"'
sudo rm -rf "/tmp/$DownloadFileName"
#
}
#
###############################################################################################################################################
#
# Section End Function
#
SectionEnd(){
#
/bin/echo # Outputting a Blank Line for Reporting Purposes
/bin/echo  ----------------------------------------------- # Outputting a Dotted Line for Reporting Purposes
/bin/echo # Outputting a Blank Line for Reporting Purposes
#
}
#
###############################################################################################################################################
#
# Script End Function
#
ScriptEnd(){
#
/bin/echo Ending Script '"'$ScriptName'"'
/bin/echo # Outputting a Blank Line for Reporting Purposes
/bin/echo  ----------------------------------------------- # Outputting a Dotted Line for Reporting Purposes
/bin/echo # Outputting a Blank Line for Reporting Purposes
#
exit $ExitCode
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
/bin/echo # Outputting a Blank Line for Reporting Purposes
SectionEnd
#
EvaluateDownload
SectionEnd
#
Download
SectionEnd
#
#if [ $Hotlink == "YES" ] # If link is a "HotLink" set a default name for Working Folder
#	then
#		pkgutil --expand $DownloadFile "/tmp/$DownloadFileName/temp" # Extract a copy of the app
#		DownloadFile=$(ls "/tmp/$DownloadFileName/temp/" | grep "$ExpectedAppFromHotlink" )
#		pkgInstall
#		SectionEnd
#fi
#
if [ $DownloadExt == "zip" ] # check if the installer needs unzipping
	then
		UnZip
        SectionEnd
		InstallerApp
		SectionEnd
fi
#
if [ $DownloadExt == "pkg" ] # check if the installer needs unzipping
	then
		pkgInstall
		SectionEnd
fi
#
Cleanup
SectionEnd
ScriptEnd
