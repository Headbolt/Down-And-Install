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
#	Variable 5 - Named "Install Command - eg. /Contents/MacOS/Sophos Installer - OPTIONAL"
#	Variable 6 - Named "Installer Switches - eg. --quiet - OPTIONAL"
#
###############################################################################################################################################
#
# HISTORY
#
#   Version: 1.11 - 19/11/2024
#
#	05/10/2022 - V1.0 - Created by Headbolt
#
#	15/11/2022 - V1.1 - Updated by Headbolt
#							Legislating for "Hotlink's" that always point at the latest version
#
#	17/11/2022 - V1.2 - Updated by Headbolt
#							Legislating for Installers that are Application Suites
#
#	22/11/2022 - V1.3 - Updated by Headbolt
#							Legislating for DMG downloads, and direct .app's as well as .app's 
#							That are Installers
#
#	23/11/2022 - V1.4 - Updated by Headbolt
#							Legislating for ZIP downloads, and common syntax based install failures for .app's
#
#	22/12/2022 - V1.5 - Updated by Headbolt
#							Legislating for the tmp folder not being present.
#							Instances observed where the /tmp link exists, but the default folder it points to ( /private/tmp )
#							is missing for some reason. Logic check put in to recreate when needed.
#
#	22/05/2023 - V1.6 - Updated by Headbolt
#							Legislating for variance in output returned by the "curl -m 5 -si" command
#							and upating some minor logic to take this into account
#							Also checking for Hotlinks that resolve slightly differently.
#
#	18/09/2023 - V1.7 - Updated by Headbolt
#							Updated some Syntax to fix errors
#							Also added section to deal with certain kinds of download results
#
#	20/06/2024 - V1.8 - Updated by Headbolt
#							Updated some Syntax around mounting images to allow for Spaces in Mounted folder names
#							Also modded some syntax around command line switches
#
#	01/07/2024 - V1.9 - Updated by Headbolt
#							Updated some Syntax around mounting images to allow for new version command outputs in Mounted folder names
#							Also changed how some variables are collected, to make them more reliable
#
#	18/09/2024 - V1.10 - Updated by Headbolt
#							Updated some Syntax around mounting images again, to improve how some variables are collected, to make them more reliable
#
#	19/11/2024 - V1.11 - Updated by Headbolt
#							Updated some logic to allow for hotlinks that use a "?fileid=" in them to select the file
#							Also making allowances for some OS version list the mounted folders/devices different orders
#
###############################################################################################################################################
#
#   DEFINE VARIABLES & READ IN PARAMETERS
#
###############################################################################################################################################
#
ScriptVer=v1.11
DownloadURL=$4 # Grab the Download URL for the installer from JAMF variable #4 eg. https://api-cloudstation-us-east-2.prod.hydra.sophos.com/api/download/SophosInstall.zip
AppInstallerCommand=$5 # Grab the Install Command, if needed from JAMF variable #5 eg. /Contents/MacOS/Sophos\ Installer
AppInstallerSwitches="${6}"  # Grab the Installer Switches, if needed from JAMF variable #6 eg. --quiet
#
ScriptName="Application | Download and Install"
MountVolume="" # Ensure The Mount Volume Variable is Blank at the outset
PreMountedFileName="" # Ensure The PreMountedFileName Variable is Blank at the outset
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
		CheckForFileID=$(/bin/echo $DownloadExt | grep "?fileid=" ) # Search Download for "?fileid="
		if [ $CheckForFileID != "" ] # Check if Download link uses "?fileid=", and if so, also assume it's a hotlink
			then
				/bin/echo 'This Download link does includes "?fileid="'
				/bin/echo 'Assuming it is a "HotLink"'
				Hotlink="YES"
			else
				/bin/echo 'Installer is a .'$DownloadExt # Output the file extension for reporting
		fi
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
		if [[ "$HotlinkResolvedURL" = "" ]] # If the "HotLink URL" is blank, attepmt again with a lowercase "location" as some can resolve this way
			then
				HotlinkResolvedURL=$(curl -m 5 -si $DownloadURL | awk '($1 == "location:") { print $NF; exit }' | sed $'s/\r$//')
		fi
        /bin/echo # Outputting a Blank Line for Reporting Purposes
        /bin/echo "Changing Download URL"
        /bin/echo "From..."
        /bin/echo '"'$DownloadURL'"'
        /bin/echo "To..."
        /bin/echo '"'$HotlinkResolvedURL'"'
        DownloadURL="$HotlinkResolvedURL"
		/bin/echo # Outputting a Blank Line for Reporting Purposes
        /bin/echo "Sending new URL for Re-Evaluation"
		SectionEnd
		EvaluateDownload
        SectionEnd
        /bin/echo 'NOW Downloading the Installer'
fi
#
/bin/echo 'Creating Temporary Working Folder "/tmp/'$DownloadFileName'"'
if [ -d "/tmp" ]
	then
    	/bin/echo # Outputting a Blank Line for Reporting Purposes
	else
    	/bin/echo # Outputting a Blank Line for Reporting Purposes
        mkdir "/private/tmp"
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
/bin/echo # Outputting a Blank Line for Reporting Purposes
/bin/echo 'Cleaning up original zip "/tmp/'${DownloadFileName}/$DownloadFile'"'
/bin/echo # Outputting a Blank Line for Reporting Purposes
/bin/echo 'Running Command "rm -rf /tmp/'${DownloadFileName}/$DownloadFile'"'
sudo rm -rf /tmp/${DownloadFileName}/$DownloadFile
#
SectionEnd
PostExpansionIInstallerSearch
#
}
#
###############################################################################################################################################
#
# Image Mount Function
#
ImageMount(){
#
/bin/echo 'Mounting Image File "'$DownloadFile'"'
/bin/echo # Outputting a Blank Line for Reporting Purposes
/bin/echo 'Running Command "'/usr/bin/hdiutil mount -private -noautoopen -noverify "'$DownloadFile'" -shadow'"'
/bin/echo # Outputting a Blank Line for Reporting Purposes
#
MountOutput=$( /usr/bin/hdiutil mount -private -noautoopen -noverify "$DownloadFile" -shadow ) # Mount the DMG
MountedDevice=$( /bin/echo "$MountOutput" | grep disk | head -1 | awk '{print $1}' ) # Find the Devie ID assigned to the mounted Volume
diskutil list -plist $MountedDevice > /tmp/mountlist.plist # Use the mounted device to export data on the mounted Volume in a consistent format
MountVolume=$(defaults read /tmp/mountlist.plist | grep MountPoint | tr '"' "\n" | grep Volumes) # Extract the MountPoint data
#
if [[ $MountVolume == "" ]] # Check the reported Mount Point to see if it is blank, and if so try a different approach
	then
		/bin/echo 'Volume mountpoint reported at the "Top of the list" is "'$MountVolume'"'
		/bin/echo # Outputting a Blank Line for Reporting Purposes
        /bin/echo 'Retrying the "Bottom of the list"'
		/bin/echo 'as some OS versions list in different orders'
		MountedDevice=$( /bin/echo "$MountOutput" | grep disk | tail -1 | awk '{print $1}' ) # Find the Devie ID assigned to the mounted Volume
		diskutil list -plist $MountedDevice > /tmp/mountlist.plist # Use the mounted device to export data on the mounted Volume in a consistent format
		MountVolume=$(defaults read /tmp/mountlist.plist | grep MountPoint | tr '"' "\n" | grep Volumes) # Extract the MountPoint data
		/bin/echo # Outputting a Blank Line for Reporting Purposes
fi
#
rm /tmp/mountlist.plist # tidy up the temp file used for process
#
if [ $? == 0 ] # Test the Mount was Successful
	then
		/bin/echo 'DMG mounted successfully as volume "'$MountVolume'" on device "'$MountedDevice'"'
		/bin/echo # Outputting a Blank Line for Reporting Purposes
		/bin/echo 'Copying Mounted files from "'$MountVolume'" to "/tmp/'$DownloadFileName'/Mounted/"'
		/bin/echo # Outputting a Blank Line for Reporting Purposes
		/bin/echo 'Running Command "cp -r "'${MountVolume}'/" /tmp/"'${DownloadFileName}'/Mounted/"'
		cp -R "${MountVolume}" /tmp/"${DownloadFileName}"/Mounted/ # Copy files to temporary working folder
		#
		SectionEnd
		UnMount
		SectionEnd
		# Set flag to indicate $DownloadFileName value will be changed, and preserve original value
		PreMountedFileName=$DownloadFileName
		DownloadFileName=$( echo ${DownloadFileName}/Mounted ) # Re-set $DownloadFileName to copied filed
		PostExpansionIInstallerSearch
	else
		/bin/echo "There was an error mounting the DMG. Exit Code: $?"
fi
#
}
################################################################################################################################################
#
# Post Expansion Installer Search Function
#
PostExpansionIInstallerSearch(){
#
		/bin/echo 'Checking copied files for installers'
        /bin/echo # Outputting a Blank Line for Reporting Purposes
		if [[ $( ls /tmp/$DownloadFileName | grep ".app" ) != "" ]]
			then
				/bin/echo '.app found'
				DownloadExt="app"
		fi
		#
		if [[ $( ls /tmp/$DownloadFileName | grep ".pkg" ) != "" ]]
			then
				/bin/echo '.pkg found'
				DownloadExt="pkg"
		fi
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
/bin/echo 'Installing "'$InstallerApp'"'
/bin/echo # Outputting a Blank Line for Reporting Purposes
if [[ $AppInstallerCommand == "" ]] # Check if installer Commands are Requested
	then
		/bin/echo 'Running Command "'cp -R "/tmp/'$DownloadFileName/${InstallerApp}'" /Applications/'"'
		cp -R "/tmp/$DownloadFileName/${InstallerApp}" /Applications/
	else
		/bin/echo 'Installer command "'$AppInstallerCommand'" has been Requested'
        if [[ $AppInstallerSwitches != "" ]] # Check if installer Switches are Requested
			then
				/bin/echo 'AND Installer switches "'$AppInstallerSwitches'" have been Requested'
		fi
		#
		chmod a+x "/tmp/$DownloadFileName/$InstallerApp/Contents/MacOS" # correcting permissions inside the installer
		/bin/echo # Outputting a Blank Line for Reporting Purposes
		/bin/echo 'Running Command "sudo /tmp/'$DownloadFileName/${InstallerApp}$AppInstallerCommand $AppInstallerSwitches'"'
		Install=$( sudo "/tmp/$DownloadFileName/$InstallerApp""$AppInstallerCommand" "$AppInstallerSwitches" 2>&1 ) # Install App
		#
		AlternateInstallMethod="" # Ensure The AlternateInstallMethod Variable is Blank at the outset
		#
		if [[ "$Install" == *"Error: There has been an error"* ]] # Check for common failure due to formatting
			then
				/bin/echo # Outputting a Blank Line for Reporting Purposes
				/bin/echo 'An "Error: There has been an error" error was returned, assuming the app installer dislikes the syntax.'
				AlternateInstallMethod="YES"
		fi
		if [[ "$Install" == *"command not found"* ]] # Check for common failure due to formatting
			then
				/bin/echo # Outputting a Blank Line for Reporting Purposes
				/bin/echo 'A "command not found" error was returned, assuming the app installer dislikes the syntax.'
				AlternateInstallMethod="YES"
		fi
		#
		if [[ $AlternateInstallMethod == "YES" ]] # Check if alternate install method is needed
			then
				/bin/echo # Outputting a Blank Line for Reporting Purposes
				/bin/echo 'Attempting a different method of running the same command'
				# To get around occasional tricky syntax with certain installers, pull install command into Variable
				InstallCommand=$( /bin/echo "sudo /tmp/$DownloadFileName/${InstallerApp}${AppInstallerCommand} ${AppInstallerSwitches}" )
				/bin/echo # Outputting a Blank Line for Reporting Purposes
				$InstallCommand # Run Install
		fi
fi
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
AppOutput=$( xattr -rc "/Applications/$AppPath" 2>&1 ) # Clear Attriubtes on Installed App
#
if [[ "$AppOutput" == *"No such file"* ]] # Error Check incase installer App is a Suite
	then
		/bin/echo # Outputting a Blank Line for Reporting Purposes
        /bin/echo '"No such file" error, assuming "'$AppName'" is a Suite'
        /bin/echo # Outputting a Blank Line for Reporting Purposes
        /bin/echo '"Checking each App inside "'$AppName'" and attempting to clear Attriubtes'
        /bin/echo # Outputting a Blank Line for Reporting Purposes
		cat "/tmp/$DownloadFileName/temp/Distribution" | grep 'title=' | sed -e 's/.*title="\([^"]*\)".*/\1/g' | while read IndividualApp
			do
            	/bin/echo # Outputting a Blank Line for Reporting Purposes
            	/bin/echo 'Running Command "xattr -rc /Applications/'$IndividualApp.app'"'
				IndividualAppOutput=$( xattr -rc "/Applications/$IndividualApp.app" 2>&1 ) # Clear Attriubtes on Individual Installed App
                if [[ "$IndividualAppOutput" == *"No such file"* ]] # Result Check
					then
                    	/bin/echo '"No such file" error'
					else
                    	/bin/echo 'OK'
				fi
			done  
fi
#
}
#
###############################################################################################################################################
#
# UnMount Image Function
#
UnMount(){
#
/bin/echo 'UnMounting volume "'$MountVolume'" from device "'$MountedDevice'"'
/bin/echo # Outputting a Blank Line for Reporting Purposes
/bin/echo 'Running Command "'umount $MountVolume'"'
UnMountResult=$( umount "$MountVolume" )
#
if [[ $UnMountResult == "" ]] # check if $DownloadFileNamethere needs resetting for cleanup
	then
		/bin/echo # Outputting a Blank Line for Reporting Purposes
		/bin/echo 'UnMount of "'$MountVolume'" from "'$MountedDevice'" Confirmed Succesful' 
fi
#
}
#
###############################################################################################################################################
#
# Install Function
#
Install(){
#
if [ "$DownloadExt" == "dmg" ] # check if the installer needs unzipping
	then
		ImageMount
        SectionEnd
fi
#
if [ "$DownloadExt" == "zip" ] # check if the installer needs unzipping
	then
		UnZip
        SectionEnd
fi
#
if [ "$DownloadExt" == "app" ] # check if the installer needs unzipping
	then
		InstallerApp
		AppInstallerActioned="YES"
		SectionEnd
fi
#
if [ "$DownloadExt" == "pkg" ] # check if the installer needs unzipping
	then
		pkgInstall
		AppInstallerActioned="YES"
		SectionEnd
fi
#
}
#
###############################################################################################################################################
#
# App Search Function
#
AppSearch(){
#
FileSearch=$(find "/tmp/$DownloadFileName" -name *.dmg) # Search the Temp folder for a .ZIP
if [[ "$FileSearch" != "" ]] # If the search of the Temp folder for a .DMG returns something ....
	then
		DownloadURL=$FileSearch
fi
#
FileSearch=$(find "/tmp/$DownloadFileName" -name *.zip) # Search the Temp folder for a .ZIP
if [[ "$FileSearch" != "" ]] # If the search of the Temp folder for a .ZIP returns something ....
	then
		DownloadURL=$FileSearch
fi
#
FileSearch=$(find "/tmp/$DownloadFileName" -name *.pkg) # Search the Temp folder for a .ZIP
if [[ "$FileSearch" != "" ]] # If the search of the Temp folder for a .PKG returns something ....
	then
		DownloadURL=$FileSearch
fi
#
FileSearch=$(find "/tmp/$DownloadFileName" -name *.app) # Search the Temp folder for a .ZIP
if [[ "$FileSearch" != "" ]] # If the search of the Temp folder for a .APP returns something ....
	then
		DownloadURL=$FileSearch
fi
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
/bin/echo 'sudo rm -rf "/tmp/'$DownloadFileName'"'
sudo rm -rf "/tmp/$DownloadFileName"
#
}
#
###############################################################################################################################################
#
# Script Start Function
#
ScriptStart(){
#
/bin/echo # Outputting a Blank Line for Reporting Purposes
SectionEnd
/bin/echo Starting Script '"'$ScriptName'"'
/bin/echo Script Version '"'$ScriptVer'"'
/bin/echo # Outputting a Blank Line for Reporting Purposes
/bin/echo  ----------------------------------------------- # Outputting a Dotted Line for Reporting Purposes
/bin/echo # Outputting a Blank Line for Reporting Purposes
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
ScriptStart
EvaluateDownload
SectionEnd
#
Download
SectionEnd
#
AppInstallerActioned="NO" # Set variable to No, so we know if an Install has been attempted
Install
#
if [[ "$AppInstallerActioned" == "NO" ]] # If no Install has been attempted, then further checks needed
	then
		AppSearch
			EvaluateDownload # Re-evaluate
			Install # Attempt Install
fi
#
if [[ $PreMountedFileName != "" ]] # check if $DownloadFileNamethere needs resetting for cleanup
	then
		DownloadFileName=$PreMountedFileName
fi
#
Cleanup
SectionEnd
ScriptEnd
