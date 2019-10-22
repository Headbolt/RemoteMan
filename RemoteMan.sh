#!/bin/bash
#
###############################################################################################################################################
#
# ABOUT THIS PROGRAM
#
#   This Script is designed for use in JAMF
#
#   - This script will ...
#			Forcibly set Remote Access Settings
#
###############################################################################################################################################
#
# HISTORY
#
#	Version: 1.1 - 21/04/2018
#
#	- 31/01/2019 - V1.0 - Created by Headbolt
#
#   - 21/10/2019 - V1.1 - Updated by Headbolt
#							More comprehensive error checking and notation
#
###############################################################################################################################################
#
# DEFINE VARIABLES & READ IN PARAMETERS
#
###############################################################################################################################################
#
# Setting Kickstart Path
kickstart="/System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart"
#
# Grab User/Users To Add (Seperated by Comma's) from JAMF variable #4 eg. username1 or username1,username2
adminUser=$4
#
# Grab any System Default User To Add from JAMF variable #5 eg. username
DefaultAdmin=$5
#
# Set a Variable that combines the 2 (Needed for "Remote Management", but only the DefaultAdmin will be used for "Remote Login")
ManUser=$(echo $adminUser,$DefaultAdmin)
#
#Setting Variable for Permissions to add
privs="-all"
#
ScriptName="append prefix here as needed - Restrict Remote Management"
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
# Check Remote Management Status of Accounts
#
Check(){
#
list=0
for username in $(dscl . -list /Users dsAttrTypeNative:naprivs | awk '{print $1}')
	do
		status=
		status=$( dscl . -list /Users dsAttrTypeNative:naprivs | grep -w $username | awk '{print $2}' )
		if [ "${status}" -ne "0" ]
			then
				/bin/echo $username
				list=1
		fi
done
#
if [ "$list" -ne "1" ]
	then
		/bin/echo "No Remote Access Users Currently Are Configured"
fi
# Outputting a Blank Line for Reporting Purposes
/bin/echo
#
rlStatus=$(sudo systemsetup -getremotelogin | cut -c 15-)
if [ "${rlStatus}" == "On" ]
	then
		/bin/echo "Remote Login Is On"
		/bin/echo Current Remote Login Users Are :
		sudo dscl . -read /Groups/com.apple.access_ssh GroupMembership | cut -c 18- 2>/dev/null
		# Outputting a Blank Line for Reporting Purposes
		/bin/echo
		#
		NestedGroups=$(dscl . -read /Groups/com.apple.access_ssh NestedGroups | cut -c 15- | grep ABCDEFAB-CDEF-ABCD-EFAB-CDEF00000050 2> /dev/null)
		if [ "${NestedGroups}" == "ABCDEFAB-CDEF-ABCD-EFAB-CDEF00000050" ]
			then
				/bin/echo "Remote Login Nested Groups Contains Administrators Group"
		fi
fi
#
}
#
###############################################################################################################################################
#
# Cleanup Function
#
CleanUp(){
#
/bin/echo Clearing out permissions and settings and disabling Services
sudo $kickstart -quiet -uninstall -settings -prefs
sudo $kickstart -quiet -activate -configure -access -off
sudo $kickstart -quiet -restart -agent -console
sudo $kickstart -quiet -activate -configure -access -off
#
sudo dseditgroup -o delete -q com.apple.access_ssh > /dev/null 2>&1
sudo dseditgroup -o delete -q com.apple.access_ssh-disabled > /dev/null 2>&1
#
rlStatus=$(sudo systemsetup -getremotelogin | cut -c 15-)
if [ "${rlStatus}" == "On" ]
	then
		sudo systemsetup -f -setremotelogin off > /dev/null 2>&1
fi
#
}
#
###############################################################################################################################################
#
# Change Function
#
Change(){
#
/bin/echo "Setting user/users $ManUser to have Full Remote Management Permissions"
sudo $kickstart -quiet -activate -configure -users $ManUser -access -on -privs $privs -restart -agent
# Outputting a Blank Line for Reporting Purposes
/bin/echo
#
/bin/echo "Setting User and Nested Group Permissions For Remote Logon (SSH)"
sudo dseditgroup -o create -q com.apple.access_ssh -T user admin
#
RecordName=$(dscl . -read /Groups/com.apple.access_ssh RecordName | cut -c 13-)
GeneratedUID=$(dscl . -read /Groups/com.apple.access_ssh GeneratedUID | cut -c 15-)
PrimaryGroupID=$(dscl . -read /Groups/com.apple.access_ssh PrimaryGroupID | cut -c 17-)
#
sudo dscl . -change /Groups/com.apple.access_ssh PrimaryGroupID $PrimaryGroupID 401
sudo dscl . -change /Groups/com.apple.access_ssh RecordName $RecordName com.apple.access_ssh
sudo dscl . -append /Groups/com.apple.access_ssh RealName "Remote Login ACL"
sudo dscl . -append /Groups/com.apple.access_ssh NestedGroups ABCDEFAB-CDEF-ABCD-EFAB-CDEF00000050 2>/dev/null
#
if [ "$DefaultAdmin" != "" ]
	then
		DefaultAdminGUID=$(dscl . -read /Users/$DefaultAdmin GeneratedUID | cut -c 15-)
		sudo dscl . -append /Groups/com.apple.access_ssh GroupMembers DefaultAdminGUID
		sudo dscl . -append /Groups/com.apple.access_ssh GroupMembership $DefaultAdmin
fi
# Outputting a Blank Line for Reporting Purposes
/bin/echo
#
/bin/echo "Re-Enabling with correct Preferences"
/bin/echo 'Setting access as "Specified Users" '
sudo $kickstart -quiet -activate -configure -allowAccessFor -specifiedUsers -restart -agent
#
sudo systemsetup -f -setremotelogin on
#
}
#
###############################################################################################################################################
#
# Section End Function
#
SectionEnd(){
#
# Outputting a Blank Line for Reporting Purposes
/bin/echo
#
# Outputting a Dotted Line for Reporting Purposes
/bin/echo  -----------------------------------------------
#
# Outputting a Blank Line for Reporting Purposes
/bin/echo
#
}
#
###############################################################################################################################################
#
# Script End Function
#
ScriptEnd(){
#
# Outputting a Blank Line for Reporting Purposes
#/bin/echo
#
/bin/echo Ending Script '"'$ScriptName'"'
#
# Outputting a Blank Line for Reporting Purposes
/bin/echo
#
# Outputting a Dotted Line for Reporting Purposes
/bin/echo  -----------------------------------------------
#
# Outputting a Blank Line for Reporting Purposes
/bin/echo
#
}
#
###############################################################################################################################################
#
# End Of Function Definition
#
###############################################################################################################################################
#
# Beginning Processing
#
###############################################################################################################################################
#
# Outputting a Blank Line for Reporting Purposes
/bin/echo
SectionEnd
#
/bin/echo "Current Remote Management Users Are :"
Check
SectionEnd
#
CleanUp
SectionEnd
#
Change
SectionEnd
#
/bin/echo "New Remote Access Users Are :"
Check
SectionEnd
#
ScriptEnd
