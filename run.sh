#!/usr/bin/env bash

# Dependencies:
# nvalgrind
# valgrind
# gdb
# g++

set -e

NVALGRIND=~/.local/bin/nvalgrind.sh
CPP_STD=c++17
DEFAULT_SRC=main.cpp
SDEBUG_FLAG=-DDSTDERR

BIN=a.out
INPUT=in.txt
OUTPUT=out.txt
EXPECTED=exp.txt

usage() {
    cat <<EOF
Usage: run.sh [options] [source.cpp]

Options:
  -c            Compare program output to $EXPECTED
  -e            Disable stderr debug macro ($SDEBUG_FLAG)
  -d            Debug with gdb
  -v            Run with valgrind via nvalgrind
  -s            Run with Address/UB sanitizers
  -h, --help    Show this help message

  If no source file is provided, defaults to $DEFAULT_SRC.

Input/output files:
  $INPUT        program stdin
  $OUTPUT       program stdout
  $EXPECTED     expected output
EOF
}

SRC="$DEFAULT_SRC"
MODE=1
COMPARE=0
SDEBUG=1
while [[ $# -gt 0 ]]; do
    case "$1" in
        -c) # compare with expected
            COMPARE=1
            shift
            ;;
        -e) # disable stderr debugging
            SDEBUG=0
            shift
            ;;
        -d) # debug
            MODE=2
            shift
            ;;
        -v) # valgrind
            MODE=3
            shift
            ;;
        -s) # sanitizer
            MODE=4
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        -*)
            echo "Unknown option: $1"
            exit 1
            ;;
        *)
            SRC="$1"
            shift
            ;;
    esac
done

cd "$(dirname "${BASH_SOURCE[0]}")"


FLAGS=(
    -std="$CPP_STD" -g

    "$SRC" -o "$BIN"

    -Wall -Wextra
    -Wno-strict-aliasing
)
if [ $SDEBUG = 1 ]; then
    FLAGS+=("$SDEBUG_FLAG")
fi

if [ $MODE = 1 ]; then
    g++ -O2 "${FLAGS[@]}"
    time ./$BIN < $INPUT > $OUTPUT
elif [ $MODE = 2 ]; then
    g++ "${FLAGS[@]}"
    gdb $BIN
elif [ $MODE = 3 ]; then
    g++ -O1 "${FLAGS[@]}"
    if [ -f $NVALGRIND ]; then
        $NVALGRIND -- ./$BIN < $INPUT > $OUTPUT
    else
        valgrind -- ./$BIN < $INPUT > $OUTPUT
    fi
elif [ $MODE = 4 ]; then
    g++ -fsanitize=address,undefined -O1 "${FLAGS[@]}"
    ./$BIN < $INPUT > $OUTPUT
fi

echo

if [ $COMPARE = 1 ]; then
    paste $EXPECTED $OUTPUT | awk -F'\t' '
      $1 != $2 {printf ":%d:\n%s\n%s\n", NR, $1, $2}
    '
else
    cat $OUTPUT
fi
