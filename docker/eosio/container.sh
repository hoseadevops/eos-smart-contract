#!/bin/bash
set -e

function run_eosio()
{
    _network_create

    local args='--restart=always'

    args="$args --cap-add SYS_PTRACE"

    args="$args -p $NODEOS_PORT:8888 --network eosdev"

    args="$args -v $project_path:$project_path"

    args="$args -w $project_path"

    args="$args -v $project_docker_runtime_dir/eosio/work:/work"

    args="$args -v $project_docker_runtime_dir/eosio/data:/mnt/dev/data"

    args="$args -v $project_docker_persistent_dir/nodeos:/mnt/dev/nodeos/config"

    args="$args -v $project_docker_persistent_dir/contracts:/mnt/dev/contracts"

    local cmd1="bash eos.sh send_cmd_to_eos_container 'cp -rf /contracts/* /mnt/dev/contracts'"

    run_cmd "docker run -d $args --name nodeos-$eosio_container $eosio_image \
    /bin/bash -c 'nodeos -d \
    /mnt/dev/data \
    --config-dir=/mnt/dev/nodeos/config \
    --http-server-address=0.0.0.0:8888 \
    --access-control-allow-origin=* --contracts-console --http-validate-host=false'; $cmd1"

    run_keosd
}


function run_keosd()
{
    local args='--restart=always'

    args="$args --cap-add SYS_PTRACE"

    args="$args -p 9876:9876 --network eosdev"

    args="$args -v $project_path:$project_path"

    args="$args -w $project_path"

    args="$args -v $project_docker_persistent_dir/keosd:/root/eosio-wallet"

    run_cmd "docker run -d $args --name keosd-$eosio_container $eosio_image /bin/bash -c 'keosd --http-server-address=0.0.0.0:9876'"
}

function rm_eosio()
{
    rm_container keosd-$eosio_container
    rm_container nodeos-$eosio_container
}

function send_cmd_to_eos_container()
{
    local cmd=$2
    run_cmd "docker exec -it nodeos-$eosio_container bash -c '$cmd'"
}

function cpp()
{
    local dir=$2
    local cmd=$3
    run_cmd "docker exec -it nodeos-$eosio_container bash -c 'cd $dir; eosiocpp $cmd'"
}

get_keosd_ip()
{
    local ip_keosd
    ip_keosd=`docker inspect --format='{{.NetworkSettings.Networks.eosdev.IPAddress}}' keosd-$eosio_container`
    echo ${ip_keosd};
}

function cli()
{
    local cmd=$2
    local ip=$(get_keosd_ip)
    if [ ! -n "$3" ]; then
        run_cmd "docker exec -it nodeos-$eosio_container /opt/eosio/bin/cleos -u http://0.0.0.0:8888 --wallet-url http://$ip:9876 $cmd"
    else
        docker exec -it nodeos-$eosio_container /opt/eosio/bin/cleos -u http://0.0.0.0:8888 --wallet-url http://$ip:9876 $cmd > /dev/null
    fi
}

function cli_test()
{
    local cmd=$2
    local ip=$(get_keosd_ip)
    local ret;
    ret=`docker exec -it nodeos-$eosio_container bash -c "/opt/eosio/bin/cleos -u http://0.0.0.0:8888 --wallet-url http://$ip:9876 $cmd || true"`
    echo "$ret"
}

function _init_contract()
{
    _open_un_lock_wallet
    run_cmd "sh eos.sh cli 'set contract eosio.token $project_docker_persistent_dir/contracts/eosio.token -x 1000s -p eosio.token@active'"
    _open_un_lock_wallet
    run_cmd "sh eos.sh cli 'set contract eosio.msig $project_docker_persistent_dir/contracts/eosio.msig -x 1000s -p eosio.msig@active'"
    _open_un_lock_wallet
    run_cmd "sh eos.sh cli 'set contract eosio $project_docker_persistent_dir/contracts/eosio.bios -x 1000s -p eosio@active'"
    _open_un_lock_wallet
    _build
}

function _build()
{
    # Bootstrap new chain
    sh eos.sh cli "push action eosio.token create '[ \"eosio\", \"10000000000.0000 SYS\" ]' -p eosio.token"
    sh eos.sh cli "push action eosio.token issue '[ \"eosio\", \"1000000000.0000 SYS\", \"memo\" ]' -p eosio"
    sh eos.sh cli "push action eosio setpriv '[\"eosio.msig\", 1]' -p eosio@active"
    sh eos.sh cli "set contract eosio ./docker/persistent/contracts/eosio.system/ -x 2000s -p eosio@active"
    # Deploy eosio.wrap
#    sh test.sh cli "wallet import -n hexing_wallet --private-key 5J3JRDhf4JNhzzjEZAsQEgtVuqvsPPdZv4Tm6SjMRx1ZqToaray"
    sh eos.sh cli "system newaccount eosio eosio.wrap EOS7LpGN1Qz5AbCJmsHzhG7sWEGd9mwhTXWmrYXqxhTknY2fvHQ1A --stake-cpu \"50 SYS\" --stake-net \"10 SYS\" --buy-ram-kbytes 5000 --transfer"
    sh eos.sh cli "push action eosio setpriv '[\"eosio.wrap\", 1]' -p eosio@active"
    sh eos.sh cli "set contract eosio.wrap ./docker/persistent/contracts/eosio.sudo/"
}

function _network_create()
{
    if (docker network ls|grep -q eosdev); then
        echo "network eosdev is created";
    else
        run_cmd "docker network create eosdev"
    fi
}