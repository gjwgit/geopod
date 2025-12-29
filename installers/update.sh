#!/bin/bash

# set -x

# 20241024 gjw After a github action has built the bundles and stored
# them as artefacts on github, we can upload them to the ${HOST} for
# distribution.

APP=$(basename "$(dirname "$(pwd)")")
REP=$(git remote get-url origin | sed -E 's#.*[/:]([^/]+)/[^/]+(\.git)?$#\1#')

HOST=solidcommunity.au
FLDR=/var/www/html/installers/
DEST=${HOST}:${FLDR}

ssh ${HOST} 'if [ ! -d ${FLDR} ]; then mkdir ${FLDR}; chown gjw:gjw ${FLDR}; fi'

# From the recent 'Build Installers' workflows, identify the 'Bump
# version' pushes to the repository and get the latest one as the one
# we want to download the artefacts.

bumpId=$(gh run list --limit 100 --json databaseId,displayTitle,workflowName \
	     | jq -r '.[] | select(.workflowName | startswith("Build Installers")) | select(.displayTitle | startswith("Bump version")) | .databaseId' \
	     | head -n 1)

echo "Found github action id: $bumpId"

if [[ -z "${bumpId}" ]]; then
    echo "No workflow found."
    exit 1
fi

status=$(gh run view ${bumpId} --json status --jq '.status')
conclusion=$(gh run view ${bumpId} --json conclusion --jq '.conclusion')

# Determine the latest version from pubspec.yaml. Assumes the
# latest Bump Version push is the same version.

version=$(grep version ../pubspec.yaml | head -1 | cut -d ':' -f 2 | sed 's/ //g' | sed 's/+.*//')

# Only proceed if the latest action hase been completed
# successfully. Each artifact whic is downloaded as a zip file
# conatins a single file/installer.
#
# 20250611 gjw I used `gh` to download the artifact but that started
# failing:
#
#     gh run download ${bumpId} --name ${APP}-linux-zip
#     error downloading ${APP}-linux-zip: would result in path traversal
#
# I could manually download through the browser, unzip, and then move
# it here to then run this script. But this is now working as an
# alternative:
#
#     gh api -H "Accept: application/vnd.github+json" repos/${REP}/${APP}/actions/artifacts/3300608315/zip >| artifact.zip
#
# We need to get the correct artifact ID for each artefact.
#
# 20251230 gjw The timestamp from the artifact is UTC which I cahnge
# to current date/time in my timezone for consistency as the release
# time, using `touch`.

if [[ "${status}" == "completed" && "${conclusion}" == "success" ]]; then

    echo "Uploading ${APP} version ${version}"
    echo "Uploads are going to ${DEST}."
    echo

    echo '***** UPLOAD LINUX DEB'

    TARGET="${APP}_amd64.deb"

    ## gh run download ${bumpId} --name ${APP}-linux-deb

    artifactId=$(gh api -H "Accept: application/vnd.github+json" /repos/${REP}/${APP}/actions/artifacts \
		    --jq '.artifacts[] | select(.name | endswith("-linux-deb")) | .id' | head -n 1)
    echo "artifact id: $artifactId"
    gh api -H "Accept: application/vnd.github+json" repos/${REP}/${APP}/actions/artifacts/${artifactId}/zip > artifact.zip
    unzip artifact.zip
    fname=$(unzip -l artifact.zip | awk 'NR==4 {print $4}')
    touch ${fname} # ${APP}_${version}_amd64.deb
    rm -f artifact.zip

    echo ${DEST}

    rsync -avzh ${fname} ${DEST}/${TARGET}
    ssh ${HOST} "cd ${FLDR}; chmod a+r ${TARGET}"
    mv -f ${fname} ARCHIVE/

    echo ""

    echo '***** UPLOAD LINUX SNAP'

    TARGET="${APP}_amd64.snap"

    ## gh run download ${bumpId} --name ${APP}-linux-snap

    artifactId=$(gh api -H "Accept: application/vnd.github+json" /repos/${REP}/${APP}/actions/artifacts \
		    --jq '.artifacts[] | select(.name | endswith("-linux-snap")) | .id' | head -n 1)
    # TODO 20251003 gjw Only continue if a snap artefact was found
    echo "artifact id: $artifactId"
    gh api -H "Accept: application/vnd.github+json" repos/${REP}/${APP}/actions/artifacts/${artifactId}/zip > artifact.zip
    unzip artifact.zip
    fname=$(unzip -l artifact.zip | awk 'NR==4 {print $4}')
    touch ${fname} # ${APP}_${version}_amd64.snap
    rm -f artifact.zip

    rsync -avzh ${fname} ${DEST}/${TARGET}
    ssh ${HOST} "cd ${FLDR}; chmod a+r ${TARGET}"
    mv -f ${fname} ARCHIVE/

    echo ""

    echo '***** UPLOAD LINUX ZIP'

    ## gh run download ${bumpId} --name ${APP}-linux-zip

    artifactId=$(gh api -H "Accept: application/vnd.github+json" /repos/${REP}/${APP}/actions/artifacts \
		    --jq '.artifacts[] | select(.name | endswith("-linux-zip")) | .id' | head -n 1)
    echo "artifact id: $artifactId"
    gh api -H "Accept: application/vnd.github+json" repos/${REP}/${APP}/actions/artifacts/${artifactId}/zip > artifact.zip
    unzip artifact.zip
    fname=$(unzip -l artifact.zip | awk 'NR==4 {print $4}')
    touch ${fname} # Timestamp with current date/time
    rm -f artifact.zip

    rsync -avzh ${APP}-linux.zip ${DEST}
    mv -f ${APP}-linux.zip ARCHIVE/${APP}_${version}_linux.zip

    echo ""

    echo '***** UPLOAD MACOS DMG'

    ## gh run download ${bumpId} --name ${APP}-macos-zip

    artifactId=$(gh api -H "Accept: application/vnd.github+json" /repos/${REP}/${APP}/actions/artifacts \
		    --jq '.artifacts[] | select(.name | endswith("-macos-dmg")) | .id' | head -n 1)
    echo "artifact id: $artifactId"
    gh api -H "Accept: application/vnd.github+json" repos/${REP}/${APP}/actions/artifacts/${artifactId}/zip > artifact.zip
    unzip artifact.zip
    fname=$(unzip -l artifact.zip | awk 'NR==4 {print $4}')
    touch ${fname} # Timestamp with current date/time
    rm -f artifact.zip

    rsync -avzh ${fname} ${DEST}/
    mv ${fname} ARCHIVE/${APP}_${version}_macos.dmg
    ssh ${HOST} "cd ${FLDR}; chmod a+r ${fname}"

    echo ""

    echo '***** UPLOAD MACOS ZIP'

    ## gh run download ${bumpId} --name ${APP}-macos-zip

    artifactId=$(gh api -H "Accept: application/vnd.github+json" /repos/${REP}/${APP}/actions/artifacts \
		    --jq '.artifacts[] | select(.name | endswith("-macos-zip")) | .id' | head -n 1)
    echo "artifact id: $artifactId"
    gh api -H "Accept: application/vnd.github+json" repos/${REP}/${APP}/actions/artifacts/${artifactId}/zip > artifact.zip
    unzip artifact.zip
    fname=$(unzip -l artifact.zip | awk 'NR==4 {print $4}')
    touch ${fname} # Timestamp with current date/time
    rm -f artifact.zip

    rsync -avzh ${APP}-macos.zip ${DEST}
    mv ${APP}-macos.zip ARCHIVE/${APP}_${version}_macos.zip
    ssh ${HOST} "cd ${FLDR}; chmod a+r ${APP}-*.zip ${APP}-*.exe"

    echo ""

    # 20251222 gjw
    #
    #    The macOS and iOS signed/certified builds are under
    #    development with the notepod app. Once it is working there we
    #    can migrate all other apps.

    # echo '***** UPLOAD MACOS DMG UNSIGNED'

    # ## gh run download ${bumpId} --name ${APP}-macos-zip

    # artifactId=$(gh api -H "Accept: application/vnd.github+json" /repos/${REP}/${APP}/actions/artifacts \
    # 		    --jq '.artifacts[] | select(.name | endswith("-macos-unsigned-dmg")) | .id' | head -n 1)
    # echo "artifact id: $artifactId"
    # gh api -H "Accept: application/vnd.github+json" repos/${REP}/${APP}/actions/artifacts/${artifactId}/zip > artifact.zip
    # unzip artifact.zip
    # rm -f artifact.zip

    # rsync -avzh ${APP}-dev-macos-unsigned.dmg ${DEST}
    # mv ${APP}-dev-macos-unsigned.dmg ARCHIVE/${APP}_${version}_macos_unsigned.dmg
    # ssh ${HOST} "cd ${FLDR}; chmod a+r ${APP}-dev-macos-unsigned.dmg"

    # echo ""

    # echo '***** UPLOAD MACOS DMG STAGING'

    # ## gh run download ${bumpId} --name ${APP}-macos-zip

    # artifactId=$(gh api -H "Accept: application/vnd.github+json" /repos/${REP}/${APP}/actions/artifacts \
    # 		    --jq '.artifacts[] | select(.name | endswith("-macos-staging-dmg")) | .id' | head -n 1)
    # echo "artifact id: $artifactId"
    # gh api -H "Accept: application/vnd.github+json" repos/${REP}/${APP}/actions/artifacts/${artifactId}/zip > artifact.zip
    # unzip artifact.zip
    # rm -f artifact.zip

    # rsync -avzh ${APP}-dev-macos-staging.dmg ${DEST}
    # mv ${APP}-dev-macos-staging.dmg ARCHIVE/${APP}_${version}_macos_staging.dmg
    # ssh ${HOST} "cd ${FLDR}; chmod a+r ${APP}-dev-macos-staging.dmg"

    # echo ""

    # echo '***** UPLOAD MACOS DMG DEV'

    # ## gh run download ${bumpId} --name ${APP}-macos-zip

    # artifactId=$(gh api -H "Accept: application/vnd.github+json" /repos/${REP}/${APP}/actions/artifacts \
    # 		    --jq '.artifacts[] | select(.name | endswith("-macos-dev-dmg")) | .id' | head -n 1)
    # echo "artifact id: $artifactId"
    # gh api -H "Accept: application/vnd.github+json" repos/${REP}/${APP}/actions/artifacts/${artifactId}/zip > artifact.zip
    # unzip artifact.zip
    # rm -f artifact.zip

    # rsync -avzh ${APP}-dev-macos-dev.dmg ${DEST}
    # mv ${APP}-dev-macos-dev.dmg ARCHIVE/${APP}_${version}_macos_dev.dmg
    # ssh ${HOST} "cd ${FLDR}; chmod a+r ${APP}-dev-macos-dev.dmg"

    # echo ""

    # echo '***** UPLOAD MACOS ZIP UNSIGNED'

    # ## gh run download ${bumpId} --name ${APP}-macos-zip

    # artifactId=$(gh api -H "Accept: application/vnd.github+json" /repos/${REP}/${APP}/actions/artifacts \
    # 		    --jq '.artifacts[] | select(.name | endswith("-macos-unsigned-zip")) | .id' | head -n 1)
    # echo "artifact id: $artifactId"
    # gh api -H "Accept: application/vnd.github+json" repos/${REP}/${APP}/actions/artifacts/${artifactId}/zip > artifact.zip
    # unzip artifact.zip
    # rm -f artifact.zip

    # rsync -avzh ${APP}-dev-macos-unsigned.zip ${DEST}
    # mv ${APP}-dev-macos-unsigned.zip ARCHIVE/${APP}_${version}_macos_unsigned.zip
    # ssh ${HOST} "cd ${FLDR}; chmod a+r ${APP}-dev-macos-unsigned.zip"

    # echo ""

    echo '***** UPLOAD WINDOWS INNO'

    ## gh run download ${bumpId} --name ${APP}-windows-inno

    artifactId=$(gh api -H "Accept: application/vnd.github+json" /repos/${REP}/${APP}/actions/artifacts \
		    --jq '.artifacts[] | select(.name | endswith("-windows-inno")) | .id' | head -n 1)
    echo "artifact id: $artifactId"
    gh api -H "Accept: application/vnd.github+json" repos/${REP}/${APP}/actions/artifacts/${artifactId}/zip > artifact.zip
    unzip artifact.zip
    fname=$(unzip -l artifact.zip | awk 'NR==4 {print $4}')
    touch ${fname} # Timestamp with current date/time
    rm -f artifact.zip

    rsync -avzh ${fname} ${DEST}
    mv ${fname} ARCHIVE/${APP}_${version}_windows-inno.exe

    echo ""

    echo '***** UPLOAD WINDOWS ZIP'

    ## gh run download ${bumpId} --name ${APP}-windows-zip

    artifactId=$(gh api -H "Accept: application/vnd.github+json" /repos/${REP}/${APP}/actions/artifacts \
		    --jq '.artifacts[] | select(.name | endswith("-windows-zip")) | .id' | head -n 1)
    echo "artifact id: $artifactId"
    gh api -H "Accept: application/vnd.github+json" repos/${REP}/${APP}/actions/artifacts/${artifactId}/zip > artifact.zip
    unzip artifact.zip
    fname=$(unzip -l artifact.zip | awk 'NR==4 {print $4}')
    touch ${fname} # Timestamp with current date/time
    rm -f artifact.zip

    rsync -avzh ${APP}-windows.zip ${DEST}
    mv -f ${APP}-windows.zip ARCHIVE/${APP}_${version}_windows.zip
    ssh ${HOST} "cd ${FLDR}; chmod a+r ${APP}-*.zip ${APP}-*.exe"

else
    gh run view ${bumpId}
    gh run view ${bumpId} --json status,conclusion
    echo ''
    echo "***** Latest github actions has not successfully completed. Exiting."
    echo ''
    exit 1
fi
