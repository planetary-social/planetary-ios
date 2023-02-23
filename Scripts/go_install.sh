#!/bin/bash
set -e


# source: https://github.com/canha/golang-tools-install-script

VERSION="1.19"

[ -z "$GOROOT" ] && GOROOT="$HOME/.go"
[ -z "$GOPATH" ] && GOPATH="$HOME/go"

OS="$(uname -s)"
ARCH="$(uname -m)"

case $OS in
    "Linux")
        case $ARCH in
        "x86_64")
            ARCH=amd64
            ;;
        "armv6")
            ARCH=armv6l
            ;;
        "armv8")
            ARCH=arm64
            ;;
        .*386.*)
            ARCH=386
            ;;
        esac
        PLATFORM="linux-$ARCH"
    ;;
    "Darwin")
        case $ARCH in
        "x86_64")
            PLATFORM="darwin-amd64"
            ;;
        "arm64")
            PLATFORM="darwin-arm64"
            ;;
        esac
    ;;
esac

print_help() {
    echo "Usage: bash goinstall.sh OPTIONS"
    echo -e "\nOPTIONS:"
    echo -e "  --remove\tRemove currently installed version"
}

if [ -n "`$SHELL -c 'echo $ZSH_VERSION'`" ]; then
    shell_profile="zshrc"
elif [ -n "`$SHELL -c 'echo $BASH_VERSION'`" ]; then
    shell_profile="bashrc"
fi

PACKAGE_NAME="go$VERSION.$PLATFORM.tar.gz"

if [ "$1" == "--remove" ]; then
    rm -rf "$GOROOT"
    if [ "$OS" == "Darwin" ]; then
        sed -i "" '/# GoLang/d' "$HOME/.${shell_profile}"
        sed -i "" '/export GOROOT/d' "$HOME/.${shell_profile}"
        sed -i "" '/$GOROOT\/bin/d' "$HOME/.${shell_profile}"
        sed -i "" '/export GOPATH/d' "$HOME/.${shell_profile}"
        sed -i "" '/$GOPATH\/bin/d' "$HOME/.${shell_profile}"
    else
        sed -i '/# GoLang/d' "$HOME/.${shell_profile}"
        sed -i '/export GOROOT/d' "$HOME/.${shell_profile}"
        sed -i '/$GOROOT\/bin/d' "$HOME/.${shell_profile}"
        sed -i '/export GOPATH/d' "$HOME/.${shell_profile}"
        sed -i '/$GOPATH\/bin/d' "$HOME/.${shell_profile}"
    fi
    echo "Go removed."
    exit 0
elif [ "$1" == "--help" ]; then
    print_help
    exit 0
elif [ ! -z "$1" ]; then
    echo "Unrecognized option: $1"
    exit 1
fi

if [ -d "$GOROOT" ]; then
    installed_version=$(${GOROOT}/bin/go version | cut -f3 -d' ')
    expected_version="go$VERSION"
    echo "Installed Go version $installed_version, expected Go version $expected_version"

    if [ "$installed_version" = "$expected_version" ]; then
      echo "Expected Go version is already installed"
      exit 0
    else
      echo "Incorrect Go version detected, removing"
      rm -r "$GOROOT"
    fi
fi

echo "Downloading $PACKAGE_NAME ..."
if hash wget 2>/dev/null; then
    wget https://storage.googleapis.com/golang/$PACKAGE_NAME -O /tmp/go.tar.gz
else
    curl -o /tmp/go.tar.gz https://storage.googleapis.com/golang/$PACKAGE_NAME
fi

if [ $? -ne 0 ]; then
    echo "Download failed! Exiting."
    exit 1
fi

echo "Extracting File..."
mkdir -p "$GOROOT"
tar -C "$GOROOT" --strip-components=1 -xzf /tmp/go.tar.gz

rm -f /tmp/go.tar.gz
