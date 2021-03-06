#!/bin/bash
set -e


function deploy()
{
  if [ ! -n "$2" ]; then
    dirs=$project_path/contracts
    for contract_dir in $dirs/*; do
      contract=$(basename $contract_dir)
      _deploy $contract_dir $contract
    done
  else
    contract_dir=$project_path/contracts/$2
    _deploy $contract_dir $2
  fi
}

function _deploy()
{
  _open_un_lock_wallet
  contract_dir=$1;
  contract=$2;
  run_cmd "sh eos.sh cpp 'contracts/$contract' '-g $contract.abi $contract.cpp'"
  run_cmd "sh eos.sh cpp 'contracts/$contract' '-o $contract.wast $contract.cpp'"
  run_cmd "sh eos.sh cli 'set contract $developer_name $contract_dir -x 1000s -p $developer_name@active'"
}
