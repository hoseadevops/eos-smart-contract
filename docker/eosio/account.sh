#!/bin/bash
set -e

function _account_create()
{
  local line=$1
  local public_key=$(_get_public_key $line)
  run_cmd "sh eos.sh cli 'create account eosio $2 $public_key $public_key'"
}

function _init_account()
{
  _open_un_lock_wallet

  _account_create 30 $developer_name

  _account_create 3 eosio.token
  _account_create 3 eosio.msig

  _account_create 27 test
  _account_create 24 call.other
}
