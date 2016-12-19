#!/bin/sh

set -e

BASE="${HOME}"
mkdir -p "${BASE}/workspace" || true
mkdir -p "${BASE}/build" || true

export PATH="${BASE}/bin:${PATH}"

if ! [ -d "${BASE}/workspace/sources" ]; then
    if [ -d "${BASE}/sources" ]; then
        ln -s "${BASE}/sources" "${BASE}/workspace/sources"
    else
        mkdir "${BASE}/workspace/sources"
    fi
fi

cmd () {
    echo "$@" 1>&2
    "$@"
}

name="$1"
remote="$2"
commit="$3"

if [ -n "${remote}" ]; then
    export BUILD_SOURCE_${name}="${remote} ${commit}"
fi

source_vars=$(set | grep '^BUILD_SOURCE_' | sed -ne 's/^BUILD_SOURCE_\([^=]*\)=\(.*\)$/\1/p')

if [ -z "${source_vars}" ]; then
    echo "No build sources to build."
    exit 1
fi

for source_name in "${source_vars}"; do
    source=$(eval echo ${source_name} \$BUILD_SOURCE_${source_name})

    name=
    remote=
    commit=

    for var in ${source}; do
        if [ -z "${name}" ]; then
            name="${BASE}/workspace/sources/${var}"
            name_opt="-p ${name}"
        elif [ -z "${remote}" ]; then
            remote="${var}"
            remote_opt="-r ${remote}"
        elif [ -z "${commit}" ]; then
            commit="${var}"
            commit_opt="-c ${commit}"
        fi
    done

    if [ -d "${name}" ]; then
        if [ "${remote}" = "local+fetch" ]; then
            (cmd cd "${name}"; for git_remote in $(git remote); do cmd git fetch "${git_remote}"; done)
        elif [ "${remote}" != "local" ]; then
            echo "${name} exists yet remote is not either 'local' or 'local+fetch'"
            exit 2
        fi
    else
        cmd git_repo.sh ${remote_opt} ${commit_opt} ${name_opt}
    fi

    cmd cd "${name}"
    cmd ./autogen.sh
    cmd ./configure --prefix=/usr/local --sysconfdir=/etc --localstatedir=/var \
            --enable-monitoring --enable-metadata --enable-syslog \
            --enable-symlinks --enable-developer-mode \
            --enable-restricted-commands --enable-haskell-tests \
            --enable-haskell-coverage \
            --with-export-dir=/var/lib/ganeti/export \
            --with-iallocator-search-path=/usr/local/lib/ganeti/iallocators,/usr/lib/ganeti/iallocators \
            --with-os-search-path=/srv/ganeti/os,/usr/local/lib/ganeti/os,/usr/lib/ganeti/os,/usr/share/ganeti/os \
            --with-extstorage-search-path=/srv/ganeti/extstorage,/usr/local/lib/ganeti/extstorage,/usr/lib/ganeti/extstorage,/usr/share/ganeti/extstorage

    cmd make -j

    # cmd mkdeb -b production; cmd cp deb_dist/*deb "${BASE}/build")
done
