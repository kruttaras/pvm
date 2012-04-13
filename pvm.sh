# Play Version Manager
# Bash function for managing play framework versions 
# 
# This started off as a fork of the excellent 
# Node Version Manager (https://github.com/creationix/nvm.git)
# which has been implemented by Tim Caswell <tim@creationix.com> 
# and Matthew Ranney
#
# Auto detect the PVM_DIR
if [ ! -d "${PVM_DIR}" ]; then
    export PVM_DIR=$(cd $(dirname ${BASH_SOURCE[0]:-$0}); pwd)
fi

# Expand a version using the version cache
pvm_version()
{
    PATTERN=$1
    # The default version is the current one
    if [ ! "$PATTERN" ]; then
        PATTERN='current'
    fi

    VERSION=$(pvm_ls $PATTERN | tail -n1)
    echo "${VERSION}"
    
    if [ "${VERSION}" = 'N/A' ]; then
        return 13
    fi
}

pvm_ls()
{
    PATTERN=$1
    VERSIONS=''
    if [ "$PATTERN" = 'current' ]; then
        echo $(node -v 2>/dev/null)
        return
    fi

    if [ -f "${PVM_DIR}/alias/$PATTERN" ]; then
        pvm_version $(cat ${PVM_DIR}/alias/$PATTERN)
        return
    fi
    # If it looks like an explicit version, don't do anything funny
    if [[ "$PATTERN" == v?*.?*.?* ]]; then
        VERSIONS="$PATTERN"
    else
        VERSIONS=$((cd ${PVM_DIR}; \ls -d v${PATTERN}* 2>/dev/null) | sort -t. -k 1.2,1n -k 2,2n -k 3,3n)
    fi
    if [ ! "${VERSION}S" ]; then
        echo "N/A"
        return
    fi
    echo "${VERSION}S"
    return
}

print_versions()
{
    OUTPUT=''
    for VERSION in $1; do
        PADDED_VERSION=$(printf '%10s' ${VERSION})
        if [[ -d "${PVM_DIR}/${VERSION}" ]]; then
             PADDED_VERSION="\033[0;34m$PADDED_VERSION\033[0m" 
        fi
        OUTPUT="$OUTPUT\n$PADDED_VERSION" 
    done
    echo -e "$OUTPUT" | column 
}

pvm()
{
  if [ $# -lt 1 ]; then
    pvm help
    return
  fi
  case $1 in
    "help" )
      echo
      echo "Play Version Manager"
      echo
      echo "Usage:"
      echo "    pvm help                    Show this message"
      echo "    pvm install <version>       Download and install a <version>"
      echo "    pvm uninstall <version>     Uninstall a version"
      echo "    pvm use <version>           Modify PATH to use <version>"
      echo "    pvm run <version> [<args>]  Run <version> with <args> as arguments"
      echo "    pvm ls                      List installed versions"
      echo "    pvm ls <version>            List versions matching a given description"
      echo "    pvm deactivate              Undo effects of PVM on current shell"
      echo "    pvm alias [<pattern>]       Show all aliases beginning with <pattern>"
      echo "    pvm alias <name> <version>  Set an alias named <name> pointing to <version>"
      echo "    pvm unalias <name>          Deletes the alias named <name>"
      echo "    pvm copy-packages <version> Install global NPM packages contained in <version> to current version"
      echo
      echo "Example:"
      echo "    pvm install v1.2.4          Install a specific version number"
      echo "    pvm use 1.2                 Use the latest available 0.2.x release"
      echo "    pvm run 0.4.12 myApp.js     Run myApp.js using node v0.4.12"
      echo "    pvm alias default 0.4       Auto use the latest installed v0.4.x version"
      echo
    ;;
    "install" )
      if [ ! $(which curl) ]; then
        echo 'PVM Needs curl to proceed.' >&2;
      fi
      
      if [ $# -ne 2 ]; then
        pvm help
        return
      fi
      VERSION=$(pvm_version $2)

      [ -d "${PVM_DIR}/${VERSION}" ] && echo "${VERSION} is already installed." && return

      appname=play-${VERSION}
      zipfile="${appname}.zip"
      download_url="http://download.playframework.org/releases/${zipfile}"
      if [ "$(curl -Is "${download_url}" | grep '200 OK')" != '' ]; then
	  echo "Using ${download_url} as download location"
      else 
	  echo "Cannot download version ${VERSION} of"'Play! Framework'" from '${download_url}'"
	  exit 1
      fi

      if (
              [ ! -z ${download_url} ] && \
		  cd "${PVM_DIR}" && \
		  curl -C - --progress-bar ${download_url} -o "${zipfile}" && \
		  unzip "${zipfile}" && \
		  mv ${appname} ${VERSION}
          )
      then
        pvm use ${VERSION}
      else
        echo "pvm: install ${VERSION} failed!"
      fi
    ;;
    "uninstall" )
      [ $# -ne 2 ] && pvm help && return
      if [[ $2 == $(pvm_version) ]]; then
        echo "pvm: Cannot uninstall currently-active play framework version, $2."
        return
      fi
      VERSION=$(pvm_version $2)
      if [ ! -d ${PVM_DIR}/${VERSION} ]; then
        echo "${VERSION} version is not installed yet"
        return;
      fi

      # Delete all files related to target version.
      (cd "${PVM_DIR}" && \
          rm -rf "play-${VERSION}" 2>/dev/null && \
          rm -f "play-${VERSION}.zip" 2>/dev/null && \
          rm -rf "${PVM_DIR}/${VERSION}" 2>/dev/null)
      echo "Uninstalled play ${VERSION}"

      # Rm any aliases that point to uninstalled version.
      for A in $(grep -l ${VERSION} ${PVM_DIR}/alias/*)
      do
        pvm unalias $(basename $A)
      done

    ;;
    "deactivate" )
      if [[ $PATH == *${PVM_DIR}/*/bin* ]]; then
        export PATH=${PATH%${PVM_DIR}/*/bin*}${PATH#*${PVM_DIR}/*/bin:}
        hash -r
        echo "${PVM_DIR}/*/bin removed from \$PATH"
      else
        echo "Could not find ${PVM_DIR}/*/bin in \$PATH"
      fi
      if [[ $MANPATH == *${PVM_DIR}/*/share/man* ]]; then
        export MANPATH=${MANPATH%${PVM_DIR}/*/share/man*}${MANPATH#*${PVM_DIR}/*/share/man:}
        echo "${PVM_DIR}/*/share/man removed from \$MANPATH"
      else
        echo "Could not find ${PVM_DIR}/*/share/man in \$MANPATH"
      fi
    ;;
    "use" )
      if [ $# -ne 2 ]; then
        pvm help
        return
      fi
      VERSION=$(pvm_version $2)
      if [ ! -d ${PVM_DIR}/${VERSION} ]; then
        echo "${VERSION} version is not installed yet"
        return;
      fi
      if [[ $PATH == *${PVM_DIR}/*/bin* ]]; then
        PATH=${PATH%${PVM_DIR}/*/bin*}${PVM_DIR}/${VERSION}/bin${PATH#*${PVM_DIR}/*/bin}
      else
        PATH="${PVM_DIR}/${VERSION}/bin:$PATH"
      fi
      if [[ $MANPATH == *${PVM_DIR}/*/share/man* ]]; then
        MANPATH=${MANPATH%${PVM_DIR}/*/share/man*}${PVM_DIR}/${VERSION}/share/man${MANPATH#*${PVM_DIR}/*/share/man}
      else
        MANPATH="${PVM_DIR}/${VERSION}/share/man:$MANPATH"
      fi
      export PATH
      hash -r
      export MANPATH
      export PVM_PATH="${PVM_DIR}/${VERSION}/lib/node"
      export PVM_BIN="${PVM_DIR}/${VERSION}/bin"
      echo "Now using node ${VERSION}"
    ;;
    "run" )
      # run given version of node
      if [ $# -lt 2 ]; then
        pvm help
        return
      fi
      VERSION=$(pvm_version $2)
      if [ ! -d ${PVM_DIR}/${VERSION} ]; then
        echo "${VERSION} version is not installed yet"
        return;
      fi
      echo "Running node ${VERSION}"
      ${PVM_DIR}/${VERSION}/bin/node "${@:3}"
    ;;
    "ls" | "list" )
      print_versions "$(pvm_ls $2)"
      if [ $# -eq 1 ]; then
        echo -ne "current: \t"; pvm_version current
        pvm alias
      fi
      return
    ;;
    "alias" )
      mkdir -p ${PVM_DIR}/alias
      if [ $# -le 2 ]; then
        (cd ${PVM_DIR}/alias && for ALIAS in $(\ls $2* 2>/dev/null); do
            DEST=$(cat $ALIAS)
            VERSION=$(pvm_version $DEST)
            if [ "$DEST" = "${VERSION}" ]; then
                echo "$ALIAS -> $DEST"
            else
                echo "$ALIAS -> $DEST (-> ${VERSION})"
            fi
        done)
        return
      fi
      if [ ! "$3" ]; then
          rm -f ${PVM_DIR}/alias/$2
          echo "$2 -> *poof*"
          return
      fi
      mkdir -p ${PVM_DIR}/alias
      VERSION=$(pvm_version $3)
      if [ $? -ne 0 ]; then
        echo "! WARNING: Version '$3' does not exist." >&2
      fi
      echo $3 > "${PVM_DIR}/alias/$2"
      if [ ! "$3" = "${VERSION}" ]; then
          echo "$2 -> $3 (-> ${VERSION})"
      else
        echo "$2 -> $3"
      fi
    ;;
    "unalias" )
      mkdir -p ${PVM_DIR}/alias
      [ $# -ne 2 ] && pvm help && return
      [ ! -f ${PVM_DIR}/alias/$2 ] && echo "Alias $2 doesn't exist!" && return
      rm -f ${PVM_DIR}/alias/$2
      echo "Deleted alias $2"
    ;;
#    "copy-packages" )
#        if [ $# -ne 2 ]; then
#          pvm help
#          return
#        fi
#        VERSION=$(pvm_version $2)
#        ROOT=$(pvm use ${VERSION} && npm -g root)
#        INSTALLS=$(pvm use ${VERSION} > /dev/null && npm -g -p ll | grep "$ROOT\/[^/]\+$" | cut -d '/' -f 8 | cut -d ":" -f 2 | grep -v npm | tr "\n" " ")
#        npm install -g $INSTALLS
#    ;;
      "clear-cache" )
	  echo "Not implemented" && exit 0
          rm -f ${PVM_DIR}/v* 2>/dev/null
          echo "Cache cleared."
	  ;;
      "version" )
          print_versions "$(pvm_version $2)"
	  ;;
      * )
	  pvm help
	  ;;
  esac
}

pvm ls default >/dev/null 2>&1 && pvm use default >/dev/null
