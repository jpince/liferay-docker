#!/bin/bash

source ./_common.sh

function check_usage {
	if [ ! -n "${1}" ] ||
	   [[ ("${1}" != "commit") &&
		  ("${1}" != "display") &&
		  ("${1}" != "fail-on-change") &&
		  ("${1}" != "get-version") ]]
	then
		echo "Usage: ${0} <command>"
		echo ""
		echo "This script requires the first parameter to be set to one of these options:"
		echo ""
		echo "    commit: Writes and commits the necessary version change with the change log"
		echo "    display: Display the required version number change"
		echo "    fail-on-change: The script will return an error code if there was a version number changing commit since the last release notes change"
		echo "    get-version: Returns the current version number"

		exit 1
	fi

	check_utils git sed sort tr
}

function generate_release_notes {
	if [ ! -n "${CHANGE_LOG}" ]
	then
		return
	fi

	if ( git log --pretty=%s ${RELEASE_NOTES_LATEST_SHA}..${CURRENT_SHA} | grep "#majorchange" > /dev/null )
	then
		RELEASE_NOTES_VERSION_MAJOR=$(($RELEASE_NOTES_VERSION_MAJOR+1))
		RELEASE_NOTES_VERSION_MINOR=0
		RELEASE_NOTES_VERSION_MICRO=0
	elif ( git log --pretty=%s ${RELEASE_NOTES_LATEST_SHA}..${CURRENT_SHA} | grep "#minorchange" > /dev/null )
	then
		RELEASE_NOTES_VERSION_MINOR=$(($RELEASE_NOTES_VERSION_MINOR+1))
		RELEASE_NOTES_VERSION_MICRO=0
	else
		RELEASE_NOTES_VERSION_MICRO=$(($RELEASE_NOTES_VERSION_MICRO+1))
	fi

	local new_version=${RELEASE_NOTES_VERSION_MAJOR}.${RELEASE_NOTES_VERSION_MINOR}.${RELEASE_NOTES_VERSION_MICRO}

	echo "Bump version from ${RELEASE_NOTES_LATEST_VERSION} to ${new_version}."

	if [ "${1}" == "commit" ]
	then
		(
			echo ""
			echo "#"
			echo "# Liferay Docker Image Version ${new_version}"
			echo "#"
			echo ""
			echo "docker.image.change.log-${new_version}=${CHANGE_LOG}"
			echo "docker.image.git.id-${new_version}=${CURRENT_SHA}"
		) >> .releng/docker-image.changelog

		git add .releng/docker-image.changelog

		git commit -m "${new_version} change log"
	fi
}

function get_change_log {
	CURRENT_SHA=$(git log -1 --pretty=%H)

	CHANGE_LOG=$(git log --pretty=%s --grep "^LPS-" ${RELEASE_NOTES_LATEST_SHA}..${CURRENT_SHA} | sed -e "s/\ .*/ /" | uniq | tr -d "\n" | tr -d "\r" | sed -e "s/ $//")

	if [ "${1}" == "fail-on-change" ] && [ -n "${CHANGE_LOG}" ]
	then
		echo "There was a change in the repository which requires regenerating the release notes."
		echo ""
		echo "Run \"./release_notes.sh commit\" to commit the updated change log."

		exit 1
	fi
}

function get_latest_version {
	local git_line=$(cat .releng/docker-image.changelog | grep docker.image.git.id | tail -n1)

	RELEASE_NOTES_LATEST_SHA=${git_line#*=}

	RELEASE_NOTES_LATEST_VERSION=${git_line#*-}
	RELEASE_NOTES_LATEST_VERSION=${RELEASE_NOTES_LATEST_VERSION%=*}

	RELEASE_NOTES_VERSION_MAJOR=${RELEASE_NOTES_LATEST_VERSION%%.*}

	RELEASE_NOTES_VERSION_MINOR=${RELEASE_NOTES_LATEST_VERSION#*.}
	RELEASE_NOTES_VERSION_MINOR=${RELEASE_NOTES_VERSION_MINOR%.*}

	RELEASE_NOTES_VERSION_MICRO=${RELEASE_NOTES_LATEST_VERSION##*.}

	if [ "${1}" == "get-version" ]
	then
		echo ${RELEASE_NOTES_LATEST_VERSION}

		exit
	fi
}

function main {
	check_usage ${@}

	get_latest_version ${@}

	get_change_log ${@}

	generate_release_notes ${@}
}

main ${@}