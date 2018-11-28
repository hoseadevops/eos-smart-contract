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

    local rmb=ACI
    local output
    echo " "
    echo 'describe "Create a new lock currency"'
    echo '  Context "Create with transfer_locked true"'
    output=`sh eos.sh cli_test "push action eosdactokena create '[\"eosdactokenb\", \"10000.0000 $rmb\", true]' -x 2000s -p eosdactokena@active"`
    assert "$output" "eosdactokena::create" "    "

    echo '  context "Issue tokens with valid auth should succeed"'
    output=`sh eos.sh cli_test "push action eosdactokena issue '[\"eosdactokenb\", \"1000.0000 $rmb\", \"memo\"]' -x 2000s -p eosdactokenb@active"`
    assert "$output" "eosdactokena::issue" "    "

    echo '  context "Transfer with valid issuer auth from locked token should succeed"'
    output=`sh eos.sh cli_test "push action eosdactokena transfer '[\"eosdactokenb\", \"eosdactokenc\", \"100.0000 $rmb\", \"memo\"]' -p eosdactokenb@active"`
    assert "$output" "100.0000 $rmb" "    "

    echo '  context "Transfer from locked token with non-issuer auth should fail"'
    output=`sh eos.sh cli_test "push action eosdactokena transfer '[\"eosdactokenc\", \"eosdactokena\", \"100.0000 $rmb\", \"memo\"]' -p eosdactokenc@active"`
    assert "$output" "Error 3090004" "    "

    echo '  context "Unlock locked token with non-issuer auth should fail"'
    output=`sh eos.sh cli_test "push action eosdactokena unlock '[\"100.0000 $rmb\"]' -p eosdactokenc@active"`
    assert "$output" "Error 3090004" "    "

    echo '  context "Transfer from locked token with non-issuer auth should fail after failed unlock attempt"'
    output=`sh eos.sh cli_test "push action eosdactokena transfer '[\"eosdactokenb\", \"eosdactokenc\", \"100.0000 $rmb\", \"memo\"]' -p eosdactoken@active"`
    assert "$output" "Error 3090003" "    "

    echo '  context "Unlock locked token with issuer auth should succeed"'
    output=`sh eos.sh cli_test "push action eosdactokena unlock '[\"100.0000 $rmb\"]' -p eosdactokenb@active"`
    assert "$output" "eosdactokena::unlock" "    "

    echo '  context "Transfer from unlocked token with non-issuer auth should succeed after successful unlock"'
    output=`sh eos.sh cli_test "push action eosdactokena transfer '[\"eosdactokenb\", \"eosdactokenc\", \"10.0000 $rmb\", \"memo\"]' -p eosdactokenb@active"`
    assert "$output" "10.0000 $rmb" "    "
}

function transfer_some_tokens()
{
   _open_un_lock_wallet

    local rmb=BEI
    local output
    echo " "
    echo 'describe "transfer some tokens"'
    echo '  Context "Create with transfer_locked true"'
    output=`sh eos.sh cli_test "push action eosdactokena create '[\"eosdactokenb\", \"10000.0000 $rmb\", false]' -x 2000s -p eosdactokena@active"`
    assert "$output" "eosdactokena::create" "    "

    echo '  context "Issue tokens with valid auth should succeed"'
    output=`sh eos.sh cli_test "push action eosdactokena issue '[\"eosdactokenb\", \"1000.0000 $rmb\", \"memo\"]' -x 2000s -p eosdactokenb@active"`
    assert "$output" "eosdactokena::issue" "    "

    echo '  context "with valid auth should succeed"'
    output=`sh eos.sh cli_test "push action eosdactokena transfer '[\"eosdactokenb\", \"eosdactokenc\", \"100.0000 $rmb\", \"memo\"]' -p eosdactokenb@active"`
#    output=`sh eos.sh cli_test "push action eosdactokena transfer '{\"from\":\"eosdactokenb\", \"to\":\"eosdactokenc\", \"quantity\":\"100.0000 $rmb\", \"memo\":\"memo\"}' -p eosdactokenb@active"`
    assert "$output" "100.0000 $rmb" "    "
}


function unlock_tokens()
{
   _open_un_lock_wallet

    local rmb=CCB
    local output
    echo " "
    echo 'describe "Unlock tokens"'
    echo '  Context "Create with transfer_locked true"'
    output=`sh eos.sh cli_test "push action eosdactokena create '[\"eosdactokenb\", \"10000.0000 $rmb\", true]' -x 2000s -p eosdactokena@active"`
    assert "$output" "eosdactokena::create" "    "

    echo '  context "Issue tokens with valid auth should succeed"'
    output=`sh eos.sh cli_test "push action eosdactokena issue '[\"eosdactokenb\", \"1000.0000 $rmb\", \"memo\"]' -x 2000s -p eosdactokenb@active"`
    assert "$output" "eosdactokena::issue" "    "

    echo '  context "without auth should fail"'
    output=`sh eos.sh cli_test "push action eosdactokena unlock '[\"100.0000 $rmb\"]' -p eosdactokenc@active"`
    assert "$output" "Error 3090004" "    "

    echo '  context "with auth should succeed"'
    output=`sh eos.sh cli_test "push action eosdactokena unlock '[\"100.0000 $rmb\"]' -p eosdactokenb@active"`
    assert "$output" "eosdactokena::unlock" "    "

}

function burn_tokens()
{

   _open_un_lock_wallet

    local rmb=DDD
    local output
    echo " "
    echo 'describe "Burn tokens"'
    echo '  Context "Create with transfer_locked true"'
    output=`sh eos.sh cli_test "push action eosdactokena create '[\"eosdactokenb\", \"10000.0000 $rmb\", true]' -x 2000s -p eosdactokena@active"`
    assert "$output" "eosdactokena::create" "    "

    echo '  context "Issue tokens with valid auth should succeed"'
    output=`sh eos.sh cli_test "push action eosdactokena issue '[\"eosdactokenb\", \"1000.0000 $rmb\", \"memo\"]' -x 2000s -p eosdactokenb@active"`
    assert "$output" "eosdactokena::issue" "    "

    echo '    context "before unlocking token"'

    echo '      context "unlocking should fail"'
    output=`sh eos.sh cli_test "push action eosdactokena burn '[\"eosdactokenb\", \"100.0000 $rmb\"]' -p eosdactokenb@active"`
    assert "$output" "Error 3050003" "      "

    echo ' '
    echo '    context "After unlocking token"'

    echo '      context "with auth should succeed"'
    output=`sh eos.sh cli_test "push action eosdactokena unlock '[\"100.0000 $rmb\"]' -p eosdactokenb@active"`
    assert "$output" "eosdactokena::unlock" "      "

    echo '      context "more than available supply should fail"'
    output=`sh eos.sh cli_test "push action eosdactokena burn '[\"eosdactokenb\", \"1001.0000 $rmb\"]' -p eosdactokenb@active"`
    assert "$output" "Error 3050003" "      "

    echo '      context "without auth should fail"'
    output=`sh eos.sh cli_test "push action eosdactokena burn '[\"eosdactokenb\", \"1001.0000 $rmb\"]'"`
    assert "$output" "Error 3040003" "      "

    echo '      context "with wrong auth should fail"'
    output=`sh eos.sh cli_test "push action eosdactokena burn '[\"eosdactokenb\", \"1001.0000 $rmb\"]' -p eosdactokenc@active"`
    assert "$output" "Error 3090004" "      "

    echo '      context "with legal amount of tokens should succeed"'
    output=`sh eos.sh cli_test "push action eosdactokena burn '[\"eosdactokenb\", \"500.0000 $rmb\"]' -p eosdactokenb@active"`
    assert "$output" "eosdactokena::burn" "      "
}

function newmemterms()
{
    _open_un_lock_wallet
    local rmb=FDD
    local output
    echo " "
    echo 'describe "newmemterms"'
    echo '  context "without valid auth"'
    output=`sh eos.sh cli_test "push action eosdactokena newmemterms '[\"terms\", \"termshashsdsdsd\"]' -x 2000s -p eosdactokenc@active"`
    assert "$output" "Error 3090004" "    "

    echo '  context "without empty terms"'
    output=`sh eos.sh cli_test "push action eosdactokena newmemterms '[\"\", \"termshashsdsdsd\"]' -x 2000s -p eosdactokena@active"`
    assert "$output" "Error 3050003" "    "

    echo '  context "with long terms"'
    output=`sh eos.sh cli_test "push action eosdactokena newmemterms '[\"aasdfasdfasddasdfasdfasdfasddasdfasdfasdfasddasdfasdfasdfasddasdfasdfasdfasddasdfasdfasdfasddasdfasdfasdfasddasdfasdfasdfasddasdfasdfasdfasddasdfasdfasdfasddasdfasdfasdfasddasdfasdfasdfasddasdfasdfasdfasddasdfasdfasdfasddasdfasdfasdfasddasdfasdfasdfasddasdf\", \"termshashsdsdsd\"]' -x 2000s -p eosdactokena@active"`
    assert "$output" "Error 3050003" "    "

    echo '  context "without empty hash"'
    output=`sh eos.sh cli_test "push action eosdactokena newmemterms '[\"termshashsdsdsd\", \"\"]' -x 2000s -p eosdactokena@active"`
    assert "$output" "Error 3050003" "    "

    echo '  context "with long hash"'
    output=`sh eos.sh cli_test "push action eosdactokena newmemterms '[\"termshashsdsdsd\", \"asdfasdfasdfasdfasdfasdfasdfasdfl\"]' -x 2000s -p eosdactokena@active"`
    assert "$output" "Error 3050003" "    "


    echo '  context "with valid terms and hash"'
    output=`sh eos.sh cli_test "push action eosdactokena newmemterms '[\"termsh\", \"asdfasdfasdfal\"]' -x 2000s -p eosdactokena@active"`
    assert "$output" "eosdactokena::newmemterms" "    "
}

function member_reg()
{
   _open_un_lock_wallet

    local output
    echo " "
    echo 'describe "Member reg"'
    echo '  context "without auth should fail"'
    output=`sh eos.sh cli_test "push action eosdactokena memberreg '[\"eosdactokenc\" \"memo\"]' -x 2000s"`
    assert "$output" "Error 3040003" "    "

    echo '  context "with mismatching auth should fail"'
    output=`sh eos.sh cli_test "push action eosdactokena memberreg '[\"eosdactoken\" \"memo\"]' -x 2000s -p eosdactokenbc@active"`
    assert "$output" "Error 3090003" "      "

    echo '  context "with valid auth for second account should succeed"'
    output=`sh eos.sh cli_test "push action eosdactokena memberreg '[\"eosdactokenb\" \"asdfasdfasdfal\"]' -x 2000s -p eosdactokenb@active"`
    assert "$output" "eosdactokena::memberreg" "    "

    echo '  context "Read back the result for regmembers hasagreed should have one accounts"'
    output=`sh eos.sh cli_test "get table eosdactokena eosdactokena members"`
    local sender=$(echo "$output"|jq '.rows'|jq .[].sender)
    assert "$sender" "eosdactokenb" "    "

    echo '  context "Update existing member reg"'
    output=`sh eos.sh cli_test "push action eosdactokena memberreg '[\"eosdactokenc\" \"asdfasdfasdfal\"]' -x 2000s -p eosdactokenc@active"`
    assert "$output" "eosdactokena::memberreg" "    "

    echo '  context "Read back the result for regmembers hasagreed should have two accounts"'
    output=`sh eos.sh cli_test "get table eosdactokena eosdactokena members"`
    local sender=$(echo "$output"|jq '.rows'|jq .[].sender)
    assert "$sender" "eosdactokenb" "    "

}

function memberunreg()
{
   _open_un_lock_wallet

    local output
    echo " "
    echo 'describe "Unregister existing member"'
    echo '  context "without correct auth"'
    output=`sh eos.sh cli_test "push action eosdactokena memberunreg '[\"eosdactokenc\"]' -x 2000s"`
    assert "$output" "Error 3040003" "    "

    echo '  context "with mismatching auth"'
    output=`sh eos.sh cli_test "push action eosdactokena memberunreg '[\"eosdactokenc\"]' -x 2000s -p eosdactokenb@active"`
    assert "$output" "Error 3090004" "    "

    echo '  context "with correct auth"'
    output=`sh eos.sh cli_test "push action eosdactokena memberunreg '[\"eosdactokenc\"]' -x 2000s -p eosdactokenc@active"`
    assert "$output" "eosdactokena::memberunreg" "    "
}