#!/bin/bash
#
# Time-stamp: <Thursday 2025-11-20 20:33:45 Jess Moore>
#
# Support for common variables used across the scripts.

# shellcheck disable=SC2034 # Ignore check for unused variables

SCRIPT=$(basename "$0" .sh)

# Check if the current shell is bash.

if [ -z "$BASH_VERSION" ]; then
  printf "ERROR: $0: Please execute this script using Bash shell.\n"
  exit 1
fi


# Flavours will be created for the flavors listed in the FLAVORS
# file.

FLAVORS=configs/flavors.json

# Project build configuration file
PROJECT_FILE='../macos/Runner.xcodeproj/project.pbxproj'

# Support functions

beginLOG () {
    printf "$*"
    printf '#%.0s' {1..72} 1>&2
    printf "\n## $(date '+%Y%m%d %H%M%S') BEGIN ${SCRIPT}\n##\n## " 1>&2
    printf "$*\n" 1>&2
}

addLOG () {
    printf "\n" 1>&2
    printf '#%.0s' {1..18} 1>&2
    printf "\n## $(date '+%Y%m%d %H%M%S') $* \n" 1>&2
    printf '#%.0s' {1..18} 1>&2
    printf "\n" 1>&2
}

dotLOG () { printf "."; }

endLOG () {
    printf "\n##\n## $(date '+%Y%m%d %H%M%S') END ${SCRIPT}\n" 1>&2
    printf '#%.0s' {1..72} 1>&2
    printf "\n" 1>&2
    printf " DONE\n"
}
