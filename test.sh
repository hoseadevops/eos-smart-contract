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

project_test_dir="$project_path/tests"

#---------- eosio container ------------#
source $project_docker_path/eosio/container.sh
source $project_docker_path/eosio/wallet.sh
source $project_docker_path/eosio/account.sh
source $project_docker_path/eosio/contract.sh
source $project_test_dir/case.sh

function assert()
{
    A=$1
    B=$2
    C=$3
    if [[ $A == *$B* ]]
      then
        echo "${C} \033[32m Passed: the result contains \"$B\". \033[0m"
      else
        FAIL_LINE=$( caller | awk '{print $1}')
        echo "\033[31m${C} Assertion failed. File case.sh Line $FAIL_LINE: \033[0m"
        echo "$1" | while read i
        do
            echo "${C} $i"
        done
        echo "${C} \033[31m Failed \033[0m"
    fi
}

function create_account()
{
#    sh eos.sh cli "wallet import -n hexing_wallet --private-key 5JioEXzAEm7yXwu6NMp3meB1P4s4im2XX3ZcC1EC5LwHXo69xYS"
#    sh eos.sh cli "wallet import -n hexing_wallet --private-key 5JHo6cvEc78EGGcEiMMfNDiTfmeEbUFvcLEnvD8EYvwzcu8XFuW"
#    sh eos.sh cli "wallet import -n hexing_wallet --private-key 5K86iZz9h8jwgGDttMPcHqFHHru5ueqnfDs5fVSHfm8bJt8PjK6"

    sh eos.sh cli "system newaccount eosio eosdactokena EOS7FuoE7h4Ruk3RkWXxNXAvhBnp7KSkq3g2NpYnLJpvtdPpXK3v8 --stake-cpu \"50 SYS\" --stake-net \"10 SYS\" --buy-ram-kbytes 5000 --transfer -x 2000"
    sh eos.sh cli "system newaccount eosio eosdactokenb EOS4xowXCvVTzGLr5rgGufqCrhnj7yGxsHfoMUVD4eRChXRsZzu3S --stake-cpu \"50 SYS\" --stake-net \"10 SYS\" --buy-ram-kbytes 5000 --transfer -x 2000"
    sh eos.sh cli "system newaccount eosio eosdactokenc EOS6Y1fKGLVr2zEFKKfAmRUoH1LzM7crJEBi4dL5ikYeGYqiJr6SS --stake-cpu \"50 SYS\" --stake-net \"10 SYS\" --buy-ram-kbytes 5000 --transfer -x 2000"

    sh eos.sh cli "transfer eosio eosdactokena \"1000 SYS\""
    sh eos.sh cli "transfer eosio eosdactokenb \"1000 SYS\""
    sh eos.sh cli "transfer eosio eosdactokenc \"1000 SYS\""
}

function _create_account()
{
    sh eos.sh cli "wallet import -n hexing_wallet --private-key 5Jbf3f26fz4HNWXVAd3TMYHnC68uu4PtkMnbgUa5mdCWmgu47sR"
    sh eos.sh cli "system newaccount eosio eosdactoken EOS7rjn3r52PYd2ppkVEKYvy6oRDP9MZsJUPB2MStrak8LS36pnTZ --stake-cpu \"50 SYS\" --stake-net \"10 SYS\" --buy-ram-kbytes 5000 --transfer -x 2000"
    sh eos.sh cli "transfer eosio eosdactoken \"1000 SYS\""

}

function deploy()
{
    create_account
    sh eos.sh cli "set contract eosdactokena ./contracts/eosdactoken --abi eosdactoken.abi -p eosdactokena@active"
}

function run()
{
    sh eos.sh restart
    sh test.sh deploy
    create_currency
    issue_currency
    create_lock_currency
    transfer_some_tokens
    unlock_tokens
    burn_tokens
    newmemterms
    member_reg
    memberunreg
}

function help()
{
cat <<EOF
    Usage: sh eos.sh [options]

        Valid options are:

        deploy

        run


        open_unlock_wallet
EOF
}

action=${1:-help}
ALL_COMMANDS="deploy run restart clean cpp cli deploy key_create send_cmd_to_eos_container open_unlock_wallet key_create get_keosd_ip"
list_contains ALL_COMMANDS "$action" || action=help gb
$action "$@"
