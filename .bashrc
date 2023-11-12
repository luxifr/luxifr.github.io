#!/bin/bash

# shellcheck source=/dev/null
. "$HOME/.bashrc"

HUGO_VERSION="$(cat HUGO_VERSION)"
ROOT_DIR="$(pwd)"

DOCKER_IMAGE="ghcr.io/hugomods/hugo:git-$HUGO_VERSION"

# shellcheck disable=SC2139 # I *want* that expansion here
alias drun='docker run -u "$(id -u)" --rm -it -v '"$ROOT_DIR"':/src'

alias hugo='drun "$DOCKER_IMAGE" hugo -s /src'
alias hugo-serve='drun --name hugo_server -p 1313:1313 "$DOCKER_IMAGE" hugo serve --bind 0.0.0.0 --disableFastRender'
