#!/bin/bash

# Copyright 2017 The authors
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# This script will scan all md (markdown) files to make sure lines are
# wrapped at 80 columns - except in very specific cases.
#
# Usage: verify-width.sh [ dir | file ... ]
# default arg is root of our source tree

set -o errexit
set -o nounset
set -o pipefail

REPO_ROOT=$( cd $(dirname "${BASH_SOURCE}")/.. && pwd)

verbose=""
debug=""
stop=""

# Error file processing
err=tmpCC-$RANDOM
trap clean EXIT
function clean {
  rm -f ${err}*
}

while [[ "$#" != "0" && "$1" == "-"* ]]; do
  opts="${1:1}"
  while [[ "$opts" != "" ]]; do
    case "${opts:0:1}" in
      v) verbose="1" ;;
      d) debug="1" ; verbose="1" ;;
      -) stop="1" ;;
      ?) echo "Usage: $0 [OPTION]... [DIR|FILE]..."
         echo "Verify all terms defined in spec are cased correctly."
         echo
         echo "  -v   show each file as it is checked"
         echo "  -?   show this help text"
         echo "  --   treat remainder of args as dir/files"
         exit 0 ;;
      *) echo "Unknown option '${opts:0:1}'"
         exit 1 ;;
    esac
    opts="${opts:1}"
  done
  shift
  if [[ "$stop" == "1" ]]; then
    break
  fi
done

# echo verbose:$verbose
# echo debug:$debug
# echo args:$*

arg=""

if [ "$*" == "" ]; then
  arg="${REPO_ROOT}"
fi

Files=$(find -L $* $arg \( -name "*.md" -o -name "*.htm*" \) | sort)

function checkFile {
  inquote=""

  # Prepend each line of the file with its line number
  cat -n $1 | while read num line ; do

    # Keep track of when we're in blocks of ``` code
    if [[ "${line}" =~ ^\`\`\`.* ]]; then
      if [[ "${inquote}" == "true" ]]; then
        inquote=""
      else
        inquote="true"
      fi
      continue
    fi

    # Skip when in ``` blocks of code
    if [[ "${inquote}" == "true" ]]; then
      continue
    fi

    # Already less than 80 so skip it
    if (( ${#line} < 81 )); then
      continue
    fi

    # Skip lines that are only image/hrefs - only allow spaces and ., at end
    if [[ "${line}" =~ ^\ *\!?\[.*\]\(.*\)[\.,]?$ ]]; then
      continue
    fi

    # Skip long headers - they cannot cross lines
    if [[ "${line}" =~ ^\# ]]; then
      continue
    fi

    if [[ "${line}" =~ ^\ *[-\*] ]]; then
      continue
    fi

    # Skip tables
    if [[ "${line}" =~ ^\| ]]; then
      continue
    fi

    echo line $num is too long
  done
}

for file in ${Files}; do
  # echo scanning $file
  dir=$(dirname $file)

  [[ -n "$verbose" ]] && echo "> $file"

  checkFile $file | tee -a $err
done

if [ -s ${err} ]; then exit 1 ; fi
