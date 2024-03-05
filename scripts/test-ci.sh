#!/bin/bash


# CI tests

GIT_COMMIT=$(git rev-parse --short HEAD)
WI_VERSION=$(<VERSION)

rpm_args="-v 2.11.1 -p linux -a x64 -d rpm -D"
deb_args="-v 2.11.1 -p linux -a x64 -d deb -D"

build() {
    local rpm
    local deb
    local success=0

    rpm=$(bash "scripts/build.sh" $rpm_args)
    local artifact_name=wazuh-indexer-min_"$WI_VERSION"_x86_64_"$GIT_COMMIT".rpm
    if [ "$rpm" = "$artifact_name" ]; then
        echo -e "\t[PASSED] rpm build output has the value '$rpm'"
    else
        echo -e "\t[FAIL] rpm build output has the value '$rpm'. Expected: '$artifact_name'"
        success=1
    fi

    deb=$(bash "scripts/build.sh" $deb_args)
    local artifact_name=wazuh-indexer-min_"$WI_VERSION"_amd64_"$GIT_COMMIT".deb
    if [ "$deb" = "$artifact_name" ]; then
        echo -e "\t[PASSED] deb build output has the value '$deb'"
    else
        echo -e "\t[FAIL] deb build output has the value '$deb'. Expected: '$artifact_name'"
        success=1
    fi

    return $success
}


assemble() {
    local rpm
    local deb
    local success=0

    rpm=$(bash "scripts/assemble.sh" $rpm_args)
    local artifact_name=wazuh-indexer-"$WI_VERSION"_x86_64_"$GIT_COMMIT".rpm
    if [ "$rpm" = "$artifact_name" ]; then
        echo -e "\t[PASSED] rpm assemble output has the value '$rpm'"
    else
        echo -e "\t[FAIL] rpm assemble output has the value '$rpm'. Expected: '$artifact_name'"
        success=1
    fi

    deb=$(bash "scripts/assemble.sh" $deb_args)
    local artifact_name=wazuh-indexer-"$WI_VERSION"_amd64_"$GIT_COMMIT".deb
    if [ "$deb" = "$artifact_name" ]; then
        echo -e "\t[PASSED] deb assemble output has the value '$deb'"
    else
        echo -e "\t[FAIL] deb assemble output has the value '$deb'. Expected: '$artifact_name'"
        success=1
    fi

    return $success
}



main() {
    build && assemble
}


main "$@"