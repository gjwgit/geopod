#!/bin/bash
#
# Time-stamp: <Friday 2025-11-21 15:20:55 Jess Moore>
#
# The JSON flavors file is a simple array with name, and signing settings of each flavor.
#
# [
#  {
        # "flavor_name": "unsigned",
        # "development_team": "",  // Apple Developer Program team id
        # "code_sign_style": "Manual", // Manual for scripted signing
        # "code_sign_identity": "", // Provide certificate name for flavors for signed builds
        # "provisioning_profile_specifier": "" // Provide provisioning profile name for flavors for signed builds
#   },
#   ...
# ]

function usage() {
    echo "Usage: bash setup_flavors.sh"
    echo ""
    echo "Description: create schemes for each desired flavor in configs/flavors.json"
    echo "with build settings as specified in config file. Flavor schemes are created"
    echo "by duplicating existing runner scheme file."
    echo ""
    exit 1 # Exit with a non-zero status to indicate an error
}

if [[ $* == *"help"* || $* == *"-h"* ]]; then
    usage
fi

. ./common.sh

if [ ! -e ${FLAVORS} ]; then
    printf "WARNING: ${SCRIPT}: The flavors file \"${FLAVORS}\" does not exist.\n"
    exit 1
fi

NUM=$(jq '.|length' ${FLAVORS})

# Set filename for backup of project file
# In case need to revert to original project file
# format
ORIG_PROJECT_FILE="${PROJECT_FILE}.bak"
# Set filenames for json version of project file
# and tmp (for update process)
JSON_PROJECT_FILE="${PROJECT_FILE}.json"
TMP_JSON_PROJECT_FILE="${PROJECT_FILE}_tmp.json"

beginLOG "Setup flavors:"

# Convert project file to json and create tmp

addLOG "Convert ${PROJECT_FILE} to json and create tmp json"
# Create backup of project file in original format
if [ ! -e ${ORIG_PROJECT_FILE} ]; then
    cp "$PROJECT_FILE" "$ORIG_PROJECT_FILE"
fi
# Create project file in json
plutil -convert json "$PROJECT_FILE" -o "$JSON_PROJECT_FILE"

addLOG "Adding ${NUM} flavors with their build configs:"

# List initial build configurations and schemes
ruby create_macos_flavor.rb --list

for ((i = 0 ; i < NUM ; i++)); do

    flavor_name=$(jq -r .[$i].flavor_name ${FLAVORS})
    development_team=$(jq -r .[$i].development_team ${FLAVORS})
    code_sign_style=$(jq -r .[$i].code_sign_style ${FLAVORS})
    code_sign_identity=$(jq -r .[$i].code_sign_identity ${FLAVORS})
    provisioning_profile_specifier=$(jq -r .[$i].provisioning_profile_specifier ${FLAVORS})

    printf "\n\n"

    # Create scheme for flavor
    printf " Creating flavor ${flavor_name}...:\n"
    ruby create_macos_flavor.rb "$flavor_name"

    # Set config for each build mode of flavor
    build_modes=("Debug" "Profile" "Release")
    for build_mode in "${build_modes[@]}"; do

        build_name="${build_mode}-${flavor_name}"
        printf "\n"
        echo " config: ${build_name}"

        # Get/set variable in json object of this flavor
        # build

        # Add development team
        echo ""
        echo "Development team: ${development_team}"
        printf "Before: "
        jq -r --arg build_name "${build_name}" '.. |select(type == "object" and .name == $build_name) | select(.buildSettings.DEVELOPMENT_TEAM != null) | .buildSettings.DEVELOPMENT_TEAM' "${JSON_PROJECT_FILE}"

        echo "Adding value..."
        jq -r --arg build_name "${build_name}" --arg new_value "${development_team}" '(.. | select(type == "object" and .name == $build_name) ).buildSettings.DEVELOPMENT_TEAM? |= $new_value' "${JSON_PROJECT_FILE}" > "${TMP_JSON_PROJECT_FILE}"
        mv "${TMP_JSON_PROJECT_FILE}" "${JSON_PROJECT_FILE}"

        printf "After: "
        jq -r --arg build_name "${build_name}" '.. |select(type == "object" and .name == $build_name) | select(.buildSettings.DEVELOPMENT_TEAM != null) | .buildSettings.DEVELOPMENT_TEAM' "${JSON_PROJECT_FILE}"

        # Update code signing style
        echo ""
        echo "Code signing style: ${code_sign_style}"
        printf "\nBefore: "
        jq -r --arg build_name "${build_name}" '.. |select(type == "object" and .name == $build_name) | select(.buildSettings.CODE_SIGN_STYLE != null) | .buildSettings.CODE_SIGN_STYLE' "${JSON_PROJECT_FILE}"

        echo "Editing values..."
        jq -r --arg build_name "${build_name}" --arg new_value "${code_sign_style}" '(.. | select(type == "object" and .name == $build_name) | select(.buildSettings.CODE_SIGN_STYLE != null) ).buildSettings.CODE_SIGN_STYLE? |= $new_value' "${JSON_PROJECT_FILE}" > "${TMP_JSON_PROJECT_FILE}"
        mv "${TMP_JSON_PROJECT_FILE}" "${JSON_PROJECT_FILE}"

        printf "After: "
        jq -r --arg build_name "${build_name}" '.. |select(type == "object" and .name == $build_name) | select(.buildSettings.CODE_SIGN_STYLE != null) | .buildSettings.CODE_SIGN_STYLE' "${JSON_PROJECT_FILE}"


        # Add code signing identity
        echo ""
        echo "Code signing certificate name: ${code_sign_identity}"
        printf "Before: "
        jq -r --arg build_name "${build_name}" '.. |select(type == "object" and .name == $build_name) | select(.buildSettings.CODE_SIGN_IDENTITY != null) | .buildSettings.CODE_SIGN_IDENTITY' "${JSON_PROJECT_FILE}"

        echo "Adding value..."
        jq -r --arg build_name "${build_name}" --arg new_value "${code_sign_identity}" '(.. | select(type == "object" and .name == $build_name) ).buildSettings.CODE_SIGN_IDENTITY? |= $new_value' "${JSON_PROJECT_FILE}" > "${TMP_JSON_PROJECT_FILE}"
        mv "${TMP_JSON_PROJECT_FILE}" "${JSON_PROJECT_FILE}"

        printf "After: "
        jq -r --arg build_name "${build_name}" '.. |select(type == "object" and .name == $build_name) | select(.buildSettings.CODE_SIGN_IDENTITY != null) | .buildSettings.CODE_SIGN_IDENTITY' "${JSON_PROJECT_FILE}"

        # Add provisioning profile name
        echo ""
        echo "Provisioning profile name: ${provisioning_profile_specifier}"
        printf "Before: "
        jq -r --arg build_name "${build_name}" '.. |select(type == "object" and .name == $build_name) | select(.buildSettings.PROVISIONING_PROFILE_SPECIFIER != null) | .buildSettings.PROVISIONING_PROFILE_SPECIFIER' "${JSON_PROJECT_FILE}"

        echo "Adding value..."
        jq -r --arg build_name "${build_name}" --arg new_value "${provisioning_profile_specifier}" '(.. | select(type == "object" and .name == $build_name) ).buildSettings.PROVISIONING_PROFILE_SPECIFIER? |= $new_value' "${JSON_PROJECT_FILE}" > "${TMP_JSON_PROJECT_FILE}"
        mv "${TMP_JSON_PROJECT_FILE}" "${JSON_PROJECT_FILE}"

        printf "After: "
        jq -r --arg build_name "${build_name}" '.. |select(type == "object" and .name == $build_name) | select(.buildSettings.PROVISIONING_PROFILE_SPECIFIER != null) | .buildSettings.PROVISIONING_PROFILE_SPECIFIER' "${JSON_PROJECT_FILE}"

    done

done

# List final build configurations and schemes
printf "\n"
ruby create_macos_flavor.rb --list

# TODO: rename project file to expected name

printf " "

endLOG
