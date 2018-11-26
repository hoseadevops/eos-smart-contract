#!/usr/bin/env bash


function create_currency()
{
    _open_un_lock_wallet

    local output
    echo "describe: Create a new currency"
    echo "  context: without account auth should fail"
    output=`sh eos.sh cli_test "push action eosdactokena create '[\"eosdactokenb\", \"10000.0000 ABY\", false]' -x 2000s"`
    assert "$output" "Error 3040003" "    "

    echo "  context: with mismatching auth should fail"
    output=`sh eos.sh cli_test "push action eosdactokena create '[\"eosdactokenb\", \"10000.0000 ABY\", false]' -x 2000s -p eosdactokenb@active"`
    assert "$output" "Error 3090004" "    "

    echo "  context: with matching issuer and account auth should succeed."
    output=`sh eos.sh cli_test "push action eosdactokena create '[\"eosdactokenb\", \"10000.0000 ABY\", false]' -x 2000s -p eosdactokena@active"`
    assert "$output" "executed transaction" "    "
}

function issue_currency()
{
   _open_un_lock_wallet

    local output
    echo " "
    echo 'describe "Issue new currency"'
    echo '  context "without valid auth should fail"'
    output=`sh eos.sh cli_test "push action eosdactokena issue '[\"eosdactokenb\", \"10000.0000 ABY\", \"memo\"]' -x 2000s"`
    assert "$output" "Transaction should have at least one required authority" "    "

    echo '  context "without owner auth should fail"'
    output=`sh eos.sh cli_test "push action eosdactokena issue '[\"eosdactokenc\", \"10000.0000 ABY\", \"memo\"]' -x 2000s -p eosdactokenc@active"`
    assert "$output" "Error 3090004" "    "

    echo '  context "with mismatching auth should fail"'
    output=`sh eos.sh cli_test "push action eosdactokena issue '[\"eosdactokenb\", \"10000.0000 ABY\", \"memo\"]' -x 2000s -p eosdactokena"`
    assert "$output" "Error 3090004" "    "

    echo '  context "with valid auth should succeed"'
    output=`sh eos.sh cli_test "push action eosdactokena issue '[\"eosdactokenb\", \"1000.0000 ABY\", \"memo\"]' -x 2000s -p eosdactokenb@active"`
    assert "$output" "eosdactokena::issue" "    "

    echo '  context "greater than max should fail"'
    output=`sh eos.sh cli_test "push action eosdactokena issue '[\"eosdactokenb\", \"9001.0000 ABY\", \"memo\"]' -x 2000s -p eosdactokenb@active"`
    assert "$output" "Error 3050003" "    "

    echo '  context "for inflation with valid auth should succeed"'
    output=`sh eos.sh cli_test "push action eosdactokena issue '[\"eosdactokenb\", \"2000.0000 ABY\", \"memo\"]' -x 2000s -p eosdactokenb@active"`
    assert "$output" "eosdactokena::issue" "    "

    echo '  context "Read back the stats after issuing currency should display max supply, supply and issuer"'
    output=`sh eos.sh cli_test "get currency stats eosdactokena ABY"`
    local supply=$(echo "$output"|jq '.ABY.supply')
    local max_supply=$(echo "$output"|jq '.ABY.max_supply')
    local issuer=$(echo "$output"|jq '.ABY.issuer')
    assert "$issuer" "eosdactokenb" "    "
    assert "$supply" "3000.0000 ABY" "    "
    assert "$max_supply" "10000.0000 ABY" "    "
}

function create_lock_currency()
{
   _open_un_lock_wallet

    local output
    echo " "
    echo 'describe "Create a new lock currency"'
    echo '  Context "Create with transfer_locked true"'
    output=`sh eos.sh cli_test "push action eosdactokena create '[\"eosdactokenb\", \"10000.0000 CCC\", true]' -x 2000s -p eosdactokena@active"`
    assert "$output" "eosdactokena::create" "    "

    echo '  context "Issue tokens with valid auth should succeed"'
    output=`sh eos.sh cli_test "push action eosdactokena issue '[\"eosdactokenb\", \"1000.0000 CCC\", \"memo\"]' -x 2000s -p eosdactokenb@active"`
    assert "$output" "eosdactokena::issue" "    "

    echo '  context "Transfer with valid issuer auth from locked token should succeed"'
    output=`sh eos.sh cli_test "push action eosdactokena transfer '[\"eosdactokenb\", \"eosdactokenc\", \"100.0000 CCC\", \"memo\"]' -p eosdactokenb@active"`
    echo "$output"

}