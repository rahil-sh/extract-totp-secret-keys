#!/bin/bash

# Upgrades Protoc from https://github.com/protocolbuffers/protobuf/releases

black='\e[0;30m'
blackBold='\e[1;30m'
blackBackground='\e[1;40m'
red='\e[0;31m'
redBold='\e[1;31m'
redBackground='\e[0;41m'
green='\e[0;32m'
greenBold='\e[1;32m'
greenBackground='\e[0;42m'
yellow='\e[0;33m'
yellowBold='\e[1;33m'
yellowBackground='\e[0;43m'
blue='\e[0;34m'
blueBold='\e[1;34m'
blueBackground='\e[0;44m'
magenta='\e[0;35m'
magentaBold='\e[1;35m'
magentaBackground='\e[0;45m'
cyan='\e[0;36m'
cyanBold='\e[1;36m'
cyanBackground='\e[0;46m'
white='\e[0;37m'
whiteBold='\e[1;37m'
whiteBackground='\e[0;47m'
reset='\e[0m'

abort() {
    echo '
***************
*** ABORTED ***
***************
    ' >&2
    echo "An error occurred on line $1. Exiting..." >&2
    date -Iseconds >&2
    exit 1
}

trap 'abort $LINENO' ERR
set -e -o pipefail

quit() {
    trap : 0
    exit 0
}

# Asks if [Yn] if script shoud continue, otherwise exit 1
# $1: msg or nothing
# Example call 1: askContinueYn
# Example call 1: askContinueYn "Backup DB?"
askContinueYn() {
    if [[ $1 ]]; then
        msg="$1 "
    else
        msg=""
    fi

    # http://stackoverflow.com/questions/3231804/in-bash-how-to-add-are-you-sure-y-n-to-any-command-or-alias
    read -e -p "${msg}Continue? [Y/n] " response
    response=${response,,}    # tolower
    if [[ $response =~ ^(yes|y|)$ ]] ; then
        # echo ""
        # OK
        :
    else
        echo "Aborted"
        exit 1
    fi
}

# Reference: https://gist.github.com/steinwaywhw/a4cd19cda655b8249d908261a62687f8

echo "Checking Protoc version..."
VERSION=$(curl -sL https://github.com/protocolbuffers/protobuf/releases/latest | grep -E "<title>" | perl -pe's%.*Protocol Buffers v(\d+\.\d+(\.\d+)?).*%\1%')
BASEVERSION=4
echo

interactive=false
ignore_version_check=true
clean=false
build_docker=true
run_gui=true
generate_result_files=false

while test $# -gt 0; do
    case $1 in
        -h|--help)
            echo "Upgrade Protoc"
            echo
            echo "$0 [options]"
            echo
            echo "Options:"
            echo "-i                      Interactive"
            echo "-C                      Ignore version check"
            echo "-D                      No docker build"
            echo "-G                      No not run gui"
            echo "-c                      Clean"
            echo "-r                      Generate result files"
            echo "-h, --help              Help"
            quit
            ;;
        -a)
            interactive=true
            shift
            ;;
        -C)
            ignore_version_check=false
            shift
            ;;
        -D)
            build_docker=false
            shift
            ;;
        -G)
            run_gui=false
            shift
            ;;
        -r)
            generate_result_files=true
            shift
            ;;
        -c)
            clean=true
            shift
            ;;
    esac
done

BIN="$HOME/bin"
DOWNLOADS="$HOME/downloads"

PYTHON="python3.11"
PIP="pip3.11"
PIPENV="$PYTHON -m pipenv"
FLAKE8="$PYTHON -m flake8"
MYPY="$PYTHON -m mypy"

# Upgrade protoc

DEST="protoc"

OLDVERSION=$(cat $BIN/$DEST/.VERSION.txt || echo "")
echo -e "\nProtoc remote version $VERSION\n"
echo -e "Protoc local version: $OLDVERSION\n"

if $clean; then
    cmd="rm -r dist/ build/ *.whl pytest.xml pytest-coverage.txt .coverage tests/reports || true; find . -name '*.pyc' -type f -delete; find . -name '__pycache__' -type d -exec rm -r {} \; || true; find . -name '*.egg-info' -type d -exec rm -r {} \; || true; find . -name '*_cache' -type d -exec rm -r {} \; || true; mkdir -p tests/reports;"
    if $interactive ; then askContinueYn "$cmd"; else echo -e "${cyan}$cmd${reset}";fi
    eval "$cmd"

    cmd="pipenv --rm || true"
    if $interactive ; then askContinueYn "$cmd"; else echo -e "${cyan}$cmd${reset}";fi
    eval "$cmd"

    cmd="sudo pipenv --rm || true"
    if $interactive ; then askContinueYn "$cmd"; else echo -e "${cyan}$cmd${reset}";fi
    eval "$cmd"
fi

if [ "$OLDVERSION" != "$VERSION" ] || ! $ignore_version_check; then
    echo "Upgrade protoc from $OLDVERSION to $VERSION"

    NAME="protoc-$VERSION"
    ARCHIVE="$NAME.zip"

    mkdir -p $DOWNLOADS
    # https://github.com/protocolbuffers/protobuf/releases/download/v21.6/protoc-21.6-linux-x86_64.zip
    cmd="wget --trust-server-names https://github.com/protocolbuffers/protobuf/releases/download/v$VERSION/protoc-$VERSION-linux-x86_64.zip -O $DOWNLOADS/$ARCHIVE"
    if $interactive ; then askContinueYn "$cmd"; else echo -e "${cyan}$cmd${reset}";fi
    eval "$cmd"

    cmd="echo -e '\nSize [Byte]'; stat --printf='%s\n' $DOWNLOADS/$ARCHIVE; echo -e '\nMD5'; md5sum $DOWNLOADS/$ARCHIVE; echo -e '\nSHA256'; sha256sum $DOWNLOADS/$ARCHIVE;"
    if $interactive ; then askContinueYn "$cmd"; else echo -e "${cyan}$cmd${reset}";fi
    eval "$cmd"

    cmd="mkdir -p $BIN/$NAME; unzip $DOWNLOADS/$ARCHIVE -d $BIN/$NAME"
    if $interactive ; then askContinueYn "$cmd"; else echo -e "${cyan}$cmd${reset}";fi
    eval "$cmd"

    cmd="echo $VERSION > $BIN/$NAME/.VERSION.txt; echo $VERSION > $BIN/$NAME/.VERSION_$VERSION.txt"
    if $interactive ; then askContinueYn "$cmd"; else echo -e "${cyan}$cmd${reset}";fi
    eval "$cmd"

    cmd="[ -d $BIN/$DEST.old ] && rm -rf $BIN/$DEST.old || echo 'No old dir to delete'"
    if $interactive ; then askContinueYn "$cmd"; else echo -e "${cyan}$cmd${reset}";fi
    eval "$cmd"

    cmd="[ -d $BIN/$DEST ] && mv -iT $BIN/$DEST $BIN/$DEST.old || echo 'No previous dir to keep'"
    if $interactive ; then askContinueYn "$cmd"; else echo -e "${cyan}$cmd${reset}";fi
    eval "$cmd"

    cmd="mv -iT $BIN/$NAME $BIN/$DEST"
    if $interactive ; then askContinueYn "$cmd"; else echo -e "${cyan}$cmd${reset}";fi
    eval "$cmd"

    cmd="rm $DOWNLOADS/$ARCHIVE"
    if $interactive ; then askContinueYn "$cmd"; else echo -e "${cyan}$cmd${reset}";fi
    eval "$cmd"

    cmd="$BIN/$DEST/bin/protoc --plugin=protoc-gen-mypy=$HOME/.local/bin/protoc-gen-mypy --python_out=src/protobuf_generated_python --mypy_out=src/protobuf_generated_python --proto_path=src google_auth.proto"
    if $interactive ; then askContinueYn "$cmd"; else echo -e "${cyan}$cmd${reset}";fi
    eval "$cmd"

    # Update README.md

    cmd="perl -i -pe 's%proto(buf|c)([- ])(\d\.)?$OLDVERSION%proto\$1\$2\${3}$VERSION%g' README.md && perl -i -pe 's%(protobuf/releases/tag/v)$OLDVERSION%\${1}$VERSION%g' README.md"
    if $interactive ; then askContinueYn "$cmd"; else echo -e "${cyan}$cmd${reset}";fi
    eval "$cmd"
else
    echo -e "\nVersion has not changed. Quit"
fi


# Upgrade pip requirements

cmd="sudo pip install -U pip"
if $interactive ; then askContinueYn "$cmd"; else echo -e "${cyan}$cmd${reset}";fi
eval "$cmd"

$PIP --version

cmd="$PIP install --use-pep517 -U -r requirements.txt"
if $interactive ; then askContinueYn "$cmd"; else echo -e "${cyan}$cmd${reset}";fi
eval "$cmd"

cmd="$PIP install --use-pep517 -U -r requirements-dev.txt"
if $interactive ; then askContinueYn "$cmd"; else echo -e "${cyan}$cmd${reset}";fi
eval "$cmd"

# Lint

LINT_OUT_FILE="tests/reports/flake8_results.txt"
cmd="$FLAKE8 . --count --select=E9,F63,F7,F82 --show-source --statistics | tee $LINT_OUT_FILE"
if $interactive ; then askContinueYn "$cmd"; else echo -e "${cyan}$cmd${reset}";fi
eval "$cmd"

cmd="$FLAKE8 . --count --exit-zero --max-complexity=10 --max-line-length=200 --statistics --exclude=.git,__pycache__,docs/source/conf.py,old,build,dist,protobuf_generated_python | tee -a $LINT_OUT_FILE"
if $interactive ; then askContinueYn "$cmd"; else echo -e "${cyan}$cmd${reset}";fi
eval "$cmd"

# Type checking

TYPE_CHECK_OUT_FILE="tests/reports/mypy_results.txt"
cmd="$MYPY --install-types --non-interactive src/*.py tests/*.py"
if $interactive ; then askContinueYn "$cmd"; else echo -e "${cyan}$cmd${reset}";fi
eval "$cmd"

# change to src as python -m mypy adds the current dir Python sys.path
# execute in a subshell in order not to loose the exit code and not to change the dir in the currrent shell
cmd="$MYPY --strict src/*.py tests/*.py | tee $TYPE_CHECK_OUT_FILE"
if $interactive ; then askContinueYn "$cmd"; else echo -e "${cyan}$cmd${reset}";fi
eval "$cmd"

# Test

cmd="$PYTHON src/extract_otp_secrets.py example_export.txt"
if $interactive ; then askContinueYn "$cmd"; else echo -e "${cyan}$cmd${reset}";fi
eval "$cmd"

cmd="$PYTHON src/extract_otp_secrets.py - < example_export.txt"
if $interactive ; then askContinueYn "$cmd"; else echo -e "${cyan}$cmd${reset}";fi
eval "$cmd"

COVERAGE_OUT_FILE="tests/reports/pytest-coverage.txt"
cmd="pytest --cov=extract_otp_secrets_test --junitxml=tests/reports/pytest.xml --cov-report html:tests/reports/html --cov-report=term-missing tests/ | tee $COVERAGE_OUT_FILE"
if $interactive ; then askContinueYn "$cmd"; else echo -e "${cyan}$cmd${reset}";fi
eval "$cmd"

# Pipenv

cmd="$PIP install -U pipenv"
if $interactive ; then askContinueYn "$cmd"; else echo -e "${cyan}$cmd${reset}";fi
eval "$cmd"

$PIPENV --version

cmd="$PIPENV update && $PIPENV --rm && $PIPENV install"
if $interactive ; then askContinueYn "$cmd"; else echo -e "${cyan}$cmd${reset}";fi
eval "$cmd"

$PIPENV run python --version

cmd="$PIPENV run pytest --cov=extract_otp_secrets_test tests/"
if $interactive ; then askContinueYn "$cmd"; else echo -e "${cyan}$cmd${reset}";fi
eval "$cmd"

# sudo pip

cmd="sudo $PIP install --use-pep517 -U -r requirements.txt"
if $interactive ; then askContinueYn "$cmd"; else echo -e "${cyan}$cmd${reset}";fi
eval "$cmd"

cmd="sudo $PIP install --use-pep517 -U -r requirements-dev.txt"
if $interactive ; then askContinueYn "$cmd"; else echo -e "${cyan}$cmd${reset}";fi
eval "$cmd"

cmd="sudo $PIP install -U pipenv"
if $interactive ; then askContinueYn "$cmd"; else echo -e "${cyan}$cmd${reset}";fi
eval "$cmd"

# pip -e install (must be after other pip installs in order to have this environment for development)

cmd="$PIP install -U -e ."
if $interactive ; then askContinueYn "$cmd"; else echo -e "${cyan}$cmd${reset}";fi
eval "$cmd"

cmd="extract_otp_secrets example_export.txt"
if $interactive ; then askContinueYn "$cmd"; else echo -e "${cyan}$cmd${reset}";fi
eval "$cmd"

cmd="extract_otp_secrets - < example_export.txt"
if $interactive ; then askContinueYn "$cmd"; else echo -e "${cyan}$cmd${reset}";fi
eval "$cmd"

# Build wheel

cmd="$PIP wheel ."
if $interactive ; then askContinueYn "$cmd"; else echo -e "${cyan}$cmd${reset}";fi
eval "$cmd"

# Generate results files

if $generate_result_files; then
    cmd="for color in '' '-n'; do for level in '' '-v' '-vv' '-vvv'; do $PYTHON src/extract_otp_secrets.py example_export.txt $color $level > tests/data/print_verbose_output$color$level.txt; done; done"
    if $interactive ; then askContinueYn "$cmd"; else echo -e "${cyan}$cmd${reset}";fi
    eval "$cmd"
fi

# Update Code Coverage in README.md

# https://github.com/marketplace/actions/pytest-coverage-comment
# Coverage-95%25-yellowgreen
echo -e "Update code coverage in README.md"
TOTAL_COVERAGE=$(cat $COVERAGE_OUT_FILE | grep 'TOTAL' | perl -ne 'print "$&" if /\b(\d{1,3})%/') && perl -i -pe "s/coverage-(\d{1,3}%)25-/coverage-${TOTAL_COVERAGE}25-/" README.md

if $build_docker; then
    # Build docker

    # Build Dockerfile_only_txt (Alpine)
    cmd="docker build . -t extract_otp_secrets_only_txt -f Dockerfile_only_txt --pull --build-arg RUN_TESTS=false"
    if $interactive ; then askContinueYn "$cmd"; else echo -e "${cyan}$cmd${reset}";fi
    eval "$cmd"

    cmd="docker run --rm -v \"$(pwd)\":/files:ro extract_otp_secrets_only_txt example_export.txt"
    if $interactive ; then askContinueYn "$cmd"; else echo -e "${cyan}$cmd${reset}";fi
    eval "$cmd"

    cmd="docker run --rm -i -v \"$(pwd)\":/files:ro extract_otp_secrets_only_txt - < example_export.txt"
    if $interactive ; then askContinueYn "$cmd"; else echo -e "${cyan}$cmd${reset}";fi
    eval "$cmd"

    cmd="docker run --entrypoint /extract/run_pytest.sh --rm -v \"$(pwd)\":/files:ro extract_otp_secrets_only_txt tests/extract_otp_secrets_test.py -k 'not qreader' -vvv --relaxed"
    if $interactive ; then askContinueYn "$cmd"; else echo -e "${cyan}$cmd${reset}";fi
    eval "$cmd"


    # Build extract_otp_secrets (Debian)
    cmd="docker build . -t extract_otp_secrets --pull --build-arg RUN_TESTS=false"
    if $interactive ; then askContinueYn "$cmd"; else echo -e "${cyan}$cmd${reset}";fi
    eval "$cmd"

    cmd="docker run --rm -v \"$(pwd)\":/files:ro extract_otp_secrets example_export.txt"
    if $interactive ; then askContinueYn "$cmd"; else echo -e "${cyan}$cmd${reset}";fi
    eval "$cmd"

    cmd="cat example_export.txt | docker run --rm -i -v \"$(pwd)\":/files:ro extract_otp_secrets - -c - > example_output.csv"
    if $interactive ; then askContinueYn "$cmd"; else echo -e "${cyan}$cmd${reset}";fi
    eval "$cmd"

    cmd="docker run --rm -i -v \"$(pwd)\":/files:ro extract_otp_secrets = < example_export.png"
    if $interactive ; then askContinueYn "$cmd"; else echo -e "${cyan}$cmd${reset}";fi
    eval "$cmd"

    cmd="docker run --entrypoint /extract/run_pytest.sh --rm -v \"$(pwd)\":/files:ro extract_otp_secrets"
    if $interactive ; then askContinueYn "$cmd"; else echo -e "${cyan}$cmd${reset}";fi
    eval "$cmd"

    cmd="docker image prune -f || echo 'No docker image pruned'"
    if $interactive ; then askContinueYn "$cmd"; else echo -e "${cyan}$cmd${reset}";fi
    eval "$cmd"

    if $run_gui; then
        cmd="docker run --rm -v "$(pwd)":/files:ro --device=\"/dev/video0:/dev/video0\" --env=\"DISPLAY\" -v /tmp/.X11-unix:/tmp/.X11-unix:ro extract_otp_secrets &"
        if $interactive ; then askContinueYn "$cmd"; else echo -e "${cyan}$cmd${reset}";fi
        eval "$cmd"
    fi
fi

if $run_gui; then
    cmd="$PYTHON src/extract_otp_secrets.py &"
    if $interactive ; then askContinueYn "$cmd"; else echo -e "${cyan}$cmd${reset}";fi
    eval "$cmd"
fi

line=$(printf '#%.0s' $(eval echo {1..$(( ($COLUMNS - 10) / 2))}))
echo -e "\n${blueBold}$line RESULTS $line${reset}"

cmd="cat $TYPE_CHECK_OUT_FILE $LINT_OUT_FILE $COVERAGE_OUT_FILE"
if $interactive ; then askContinueYn "$cmd"; else echo -e "${cyan}$cmd${reset}";fi
eval "$cmd"

echo -e "\n${greenBold}SUCCESS${reset}"

quit