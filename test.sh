#!/bin/bash

set -e

function read_kv_config()
{
    local file=$1
    local key=$2
    cat $file | grep "$key=" | awk -F '=' '{print $2}'
}

NODEOS_PORT=$(read_kv_config .env NODEOS_PORT)
VERSION=$(read_kv_config .env VERSION)

project_path=$(cd $(dirname $0); pwd -P)
project_docker_path="$project_path/docker"
source $project_docker_path/bash.sh
developer_name=$('whoami');


app_basic_name=eos-dev
app="$app_basic_name-$developer_name"

eosio_image=eosio/eos:$VERSION

# container
eosio_container=$app

# container dir
project_docker_eosio_dir="$project_docker_path/eosio"

project_docker_runtime_dir="$project_docker_path/runtime"
project_docker_persistent_dir="$project_docker_path/persistent"

project_test_dir="$project_path/test"

#---------- eosio container ------------#
source $project_docker_path/eosio/container.sh
source $project_docker_path/eosio/wallet.sh
source $project_docker_path/eosio/account.sh
source $project_docker_path/eosio/contract.sh
source $project_test_dir/case.sh

function assert()
{
    if [ $1 -eq 0 ]; then
        FAIL_LINE=$( caller | awk '{print $1}')
        echo "Assertion failed. Line $FAIL_LINE:"
        head -n $FAIL_LINE $BASH_SOURCE | tail -n 1
        exit 99
    fi
}

function deploy()
{
    sh eos.sh cli "wallet import -n hexing_wallet --private-key 5JioEXzAEm7yXwu6NMp3meB1P4s4im2XX3ZcC1EC5LwHXo69xYS"
    sh eos.sh cli "wallet import -n hexing_wallet --private-key 5JHo6cvEc78EGGcEiMMfNDiTfmeEbUFvcLEnvD8EYvwzcu8XFuW"

    sh eos.sh cli "system newaccount eosio eosdactokena EOS7FuoE7h4Ruk3RkWXxNXAvhBnp7KSkq3g2NpYnLJpvtdPpXK3v8 --stake-cpu \"50 SYS\" --stake-net \"10 SYS\" --buy-ram-kbytes 5000 --transfer"
    sh eos.sh cli "system newaccount eosio eosdactokenb EOS4xowXCvVTzGLr5rgGufqCrhnj7yGxsHfoMUVD4eRChXRsZzu3S --stake-cpu \"50 SYS\" --stake-net \"10 SYS\" --buy-ram-kbytes 5000 --transfer"

    sh eos.sh cli "transfer eosio eosdactokena \"1000 SYS\""
    sh eos.sh cli "transfer eosio eosdactokenb \"1000 SYS\""

    sh eos.sh cli "set contract eosdactokena ./contracts/eosdactoken --abi eosdactoken.abi -p eosdactokena@active"
}


function help()
{
cat <<EOF
    Usage: sh eos.sh [options]

        Valid options are:

        deploy



        open_unlock_wallet
EOF
}

action=${1:-help}
ALL_COMMANDS="deploy restart clean cpp cli deploy key_create send_cmd_to_eos_container open_unlock_wallet key_create get_keosd_ip"
list_contains ALL_COMMANDS "$action" || action=help
$action "$@"
