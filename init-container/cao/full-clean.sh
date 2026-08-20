#!/usr/bin/env bash

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

nerdctl compose -f vault-init.yaml -f docker-compose.yaml -f middleware-compose.yaml -f chmod.yaml down

nerdctl network rm maestro
nerdctl rm maestro-registry -f
nerdctl rm vault-init -f 2> /dev/null

nerdctl volume rm $(nerdctl volume ls | awk '{print $1}' | tail -n +2)

nerdctl rm -f $(nerdctl ps -a)
nerdctl rmi -f $(nerdctl images -aq)
