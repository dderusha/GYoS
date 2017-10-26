#!/bin/bash

MYDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"



pashLoc="/Applications/Utilities/"
pashuaApp="Pashua.app"

pashBinLoc="/Applications/Utilities/Pashua.app/Contents/MacOS/Pashua"
SENDGRID_API_KEY="$8"

itemName="$4"
itemURL="$5"
itemApproval="$6"
itemCost="$7"
userName="$3"

fullTitle="Welcome to the $itemName Store."

if [[ $itemApproval == "1" ]]
then
    displayMessage="This item requires approval; it will be ordered when approved.[return][return]$itemName - Cost \$$itemCost[return][return]Please complete this form to finalize the order.[return][return]If in a local office, we will contact you when the item is ready for pickup from the Help Desk. If remote, we will order the item for delivery to be shipped to your location."
else 
    displayMessage="$itemName - Cost \$$itemCost[return][return]Please complete this form to finalize the order.[return][return]If in a local office, we will contact you when the item is ready for pickup from the Help Desk. If remote, we will order the item for delivery to be shipped to your location."
fi


if [[ ! -a "$pashLoc$pashuaApp" ]]
then
	echo "Pashua Not Found."
	sudo jamf policy -event installPashua
else
	echo "Pashua Found."
fi

############
#Functions from the pashua.sh script

locate_pashua() {

    local bundlepath="Pashua.app/Contents/MacOS/Pashua"
    local mypath=`dirname "$0"`

    pashuapath=""

    if [ ! "$1" = "" ]
    then
        searchpaths[0]="$1/$bundlepath"
    fi
    searchpaths[1]="$mypath/Pashua"
    searchpaths[2]="$mypath/$bundlepath"
    searchpaths[3]="./$bundlepath"
    searchpaths[4]="/Applications/$bundlepath"
    searchpaths[5]="$HOME/Applications/$bundlepath"
    searchpaths[6]="/Applications/Utilities/Pashua"

    for searchpath in "${searchpaths[@]}"
    do
        if [ -f "$searchpath" -a -x "$searchpath" ]
        then
            pashuapath=$searchpath
            return 0
        fi
    done

    return 1
}

pashua_run() {

    # Write config file
    local pashua_configfile=`/usr/bin/mktemp /tmp/pashua_XXXXXXXXX`
    echo "$1" > "$pashua_configfile"

    locate_pashua "$2"

    if [ "" = "$pashuapath" ]
    then
        >&2 echo "Error: Pashua could not be found"
        exit 1
    fi

    # Get result
    local result=$("$pashuapath" "$pashua_configfile")

    # Remove config file
    rm "$pashua_configfile"

    oldIFS="$IFS"
    IFS=$'\n'

    # Parse result
    for line in $result
    do
        local name=$(echo $line | sed 's/^\([^=]*\)=.*$/\1/')
        local value=$(echo $line | sed 's/^[^=]*=\(.*\)$/\1/')
        eval $name='$value'
    done

    IFS="$oldIFS"
}

function sendEmail(){

    emailBody=$(cat /tmp/itemOrder.conf)
    
    emailContent=$(cat  << EOF
    {
      "personalizations": [
        {
          "to": [
            {
              "email": "email@company.com"
            }
          ],
          "subject": "Item needs order"
        }
      ],
      "from": {
        "email": "gyosBot@gyos.com"
      },
      "content": [
        {
          "type": "text/plain",
          "value": '"$emailBody"'
        }
      ]
    }
    EOF
    )

    curl --request POST \
      --url https://api.sendgrid.com/v3/mail/send \
      --header "Authorization: Bearer $SENDGRID_API_KEY" \
      --header 'Content-Type: application/json' \
      -d "$emailContent"
}

# Define what the dialog should be like
# Take a look at Pashua's Readme file for more info on the syntax

conf="
# Set window title
*.title = $fullTitle

# Introductory text
txt.type = text
txt.default = $displayMessage
txt.height = 276
txt.width = 325
txt.x = 340
txt.y = 44
txt.tooltip = 

# Add a text field
fullName.type = textfield
fullName.label = Full Name:
fullName.default = 
fullName.width = 310
fullName.x = 0
fullName.y = 275
fullName.mandatory = 1
fullName.tooltip = Please Enter Your Full Name.

# Add a text field
userID.type = textfield
userID.label = User ID:
userID.default = $userName
userID.width = 310
userID.x = 0
userID.y = 230
userID.mandatory = 1
userID.tooltip = Please Enter Your Associate ID.


# Add a text field
email.type = textfield
email.label = Email Address:
email.default = 
email.width = 310
email.x = 0
email.y = 185
email.mandatory = 1
email.tooltip = Please Enter Your Email Address.

# Add a popup menu
workLoc.type = popup
workLoc.label = Delivery Location:
workLoc.width = 310
workLoc.option = Headquarters
workLoc.option = Remote (Address Required)
workLoc.default = Headquarters
workLoc.x = 0
workLoc.y = 135
workLoc.tooltip = Please Select Your Location.

# Add a text field menu
workAddress.type = textfield
workAddress.label = If Remote, Please Enter Shipping Address:
workAddress.width = 310
workAddress.default = 
workAddress.x = 0
workAddress.y = 90
workAddress.tooltip = Shipping address only needed if a remote employee.

# Add a text field menu
city.type = textfield
city.label = City:
city.width = 150
city.default = 
city.x = 0
city.y = 45
city.tooltip = Please Enter Your City.

# Add a text field menu
state.type = textfield
state.label = State:
state.width = 75
state.default = 
state.x = 151
state.y = 45
state.tooltip = Please Enter Your State.

# Add a text field menu
zipCode.type = textfield
zipCode.label = Zip:
zipCode.width = 50
zipCode.default = 
zipCode.x = 227
zipCode.y = 45
zipCode.tooltip = Please Enter Your Zip.

# Add a cancel button with default label
cancel.type = cancelbutton
cancel.tooltip = Cancel

db.type = defaultbutton
db.tooltip = This is an element of type “defaultbutton” (which is automatically added to each window, if not included in the configuration)
"

if [ -d '/Volumes/Pashua/Pashua.app' ]
then
	# Looks like the Pashua disk image is mounted. Run from there.
	customLocation='/Volumes/Pashua'
else
	# Search for Pashua in the standard locations
	customLocation="$pashLoc"
fi

# Get the icon from the application bundle
locate_pashua "$customLocation"
bundlecontents=$(dirname $(dirname "$pashuapath"))
if [ -e "/Applications/Utilities/Pashua.app/Contents/Resources/pingIdentity.png" ]

then
    conf="$conf
          img.type = image
          img.x = 435
          img.y = 248
          img.maxwidth = 128
          img.tooltip = This is an element of type “image”
          img.path = /Applications/Utilities/Pashua.app/Contents/Resources/pingIdentity.png"
fi

#This function will write the conf file to be used for the email template
#The delimiter to get information out of this file should be " - " 
#For example `awk -F' - ' '{print $2}'`

function createConf() {
cat >/tmp/itemOrder.conf <<EOL
Full Name - $fullName\n User ID - $userID\n Email Address - $email\n Work Location - $workLoc\n Work Address - $workAddress\n City - $city\n State - $state\n Zip = $zipCode\n Item Selected - $itemName\n Item Cost - $itemCost\n Item URL - $itemURL\n Approval Needed - $itemApproval\n
EOL
}

#Run Pashua with the config.
function main()
{
    fullName=""
    userID=""
    email=""
    workLoc=""
    workAddress=""
    city=""
    state=""
    zipCode=""
        
    pashua_run "$conf" "$customLocation"

	if [[ "$workLoc" == "Headquarters" ]]
	then
		if [[ $workAddress == "" ]]
		then
			workAddress="N/a"
		fi
		if [[ $city == "" ]]
		then
			city="N/a"
		fi
		if [[ $state == "" ]]
		then
			state="N/a"
		fi
		if [[ $zipCode == "" ]]
		then
			zipCode="N/a"
		fi
	elif [[ "$workLoc" == "Remote (Address Required)" ]]
	then
		if [[ $workAddress == "" ]] || [[ $city == "" ]] || [[ $state == "" ]] || [[ $zipCode == "" ]]
		then
			#Re-Run Pashua
			main
		fi
	fi
	
}

#kick off Pashua via Function
main
#Create Conf File
createConf
#Send the email
sendEmail

echo "Pashua created the following variables:"
echo "  Full Name  = $fullName"
echo "  User ID  = $userID"
echo "  Email Address  = $email"
echo "  Work Location = $workLoc"
echo "  Work Address = $workAddress"
echo "  City = $city"
echo "  State = $state"
echo "  Zip = $zipCode"
echo ""
