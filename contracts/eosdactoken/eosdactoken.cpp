/**
 *  @file
 *  @copyright defined in eos/LICENSE.txt
 */

#include "eosdactoken.hpp"

#include <algorithm>

namespace eosdac {

    void eosdactoken::create(account_name issuer,
                             asset maximum_supply,
                             bool transfer_locked) {
        require_auth(_self);

        auto sym = maximum_supply.symbol;
        eosio_assert(sym.is_valid(), "invalid symbol name");
        eosio_assert(maximum_supply.is_valid(), "invalid supply");
        eosio_assert(maximum_supply.amount > 0, "max-supply must be positive");

        stats statstable(_self, sym.name());
        auto existing = statstable.find(sym.name());
        eosio_assert(existing == statstable.end(), "token with symbol already exists");

        statstable.emplace(_self, [&](auto &s) {
            s.supply.symbol = maximum_supply.symbol;
            s.max_supply = maximum_supply;
            s.issuer = issuer;
            s.transfer_locked = transfer_locked;
        });
    }

    void eosdactoken::issue(account_name to, asset quantity, string memo) {
        auto sym = quantity.symbol;
        eosio_assert(sym.is_valid(), "invalid symbol name");

        auto sym_name = sym.name();
        stats statstable(_self, sym_name);
        auto existing = statstable.find(sym_name);
        eosio_assert(existing != statstable.end(), "token with symbol does not exist, create token before issue");
        const auto &st = *existing;

        require_auth(st.issuer);
        eosio_assert(quantity.is_valid(), "invalid quantity.");
        eosio_assert(quantity.amount > 0, "must issue positive quantity");

        eosio_assert(quantity.symbol == st.supply.symbol, "symbol precision mismatch");
        eosio_assert(quantity.amount <= st.max_supply.amount - st.supply.amount, "quantity exceeds available supply");

        statstable.modify(st, 0, [&](auto &s) {
            s.supply += quantity;
        });

        add_balance(st.issuer, quantity, st, st.issuer);

        if (to != st.issuer) {
            SEND_INLINE_ACTION(*this, transfer, {st.issuer, N(active)}, {st.issuer, to, quantity, memo});
        }
    }

    void eosdactoken::unlock(asset unlock) {
        eosio_assert(unlock.symbol.is_valid(), "invalid symbol name");
        auto sym_name = unlock.symbol.name();
        stats statstable(_self, sym_name);
        auto token = statstable.find(sym_name);
        eosio_assert(token != statstable.end(), "token with symbol does not exist, create token before unlock");
        const auto &st = *token;
        require_auth(st.issuer);

        statstable.modify(st, 0, [&](auto &s) {
            s.transfer_locked = false;
        });
    }

    void eosdactoken::transfer(account_name from,
                               account_name to,
                               asset quantity,
                               string       /*memo*/) {
        eosio_assert(from != to, "cannot transfer to self");
        require_auth(from);
        eosio_assert(is_account(to), "to account does not exist");
        auto sym = quantity.symbol.name();
        stats statstable(_self, sym);
        const auto &st = statstable.get(sym);

        if (st.transfer_locked) {
            require_auth(st.issuer);
        }
        require_recipient(from, to, configs().notifycontr);

        eosio_assert(quantity.is_valid(), "invalid quantity");
        eosio_assert(quantity.amount > 0, "must transfer positive quantity");
        eosio_assert(quantity.symbol == st.supply.symbol, "symbol precision mismatch");

        sub_balance(from, quantity, st);
        add_balance(to, quantity, st, from);
    }

    void eosdactoken::sub_balance(account_name owner, asset value, const currency_stats &st) {
        accounts from_acnts(_self, owner);

        const auto &from = from_acnts.get(value.symbol.name());
        eosio_assert(from.balance.amount >= value.amount, "overdrawn balance");


        if (from.balance.amount == value.amount) {
            from_acnts.erase(from);
        } else {
            from_acnts.modify(from, owner, [&](auto &a) {
                a.balance -= value;
            });
        }
    }

    void eosdactoken::add_balance(account_name owner, asset value, const currency_stats &st, account_name ram_payer) {
        accounts to_acnts(_self, owner);
        auto to = to_acnts.find(value.symbol.name());
        if (to == to_acnts.end()) {
            to_acnts.emplace(ram_payer, [&](auto &a) {
                a.balance = value;
            });
        } else {
            to_acnts.modify(to, 0, [&](auto &a) {
                a.balance += value;
            });
        }
    }

    void eosdactoken::burn(account_name from, asset quantity) {
        print("burn");
        require_auth(from);

        auto sym = quantity.symbol.name();
        stats statstable(_self, sym);
        const auto &st = statstable.get(sym, "Attempting to burn a token unknown to this contract");
        eosio_assert(!st.transfer_locked, "Burn tokens on transferLocked token. The issuer must `unlock` first");
        require_recipient(from);

        eosio_assert(quantity.is_valid(), "invalid quantity");
        eosio_assert(quantity.amount > 0, "must burn positive quantity");
        eosio_assert(quantity.symbol == st.supply.symbol, "symbol precision mismatch");

        sub_balance(from, quantity, st);

        statstable.modify(st, 0, [&](currency_stats &s) {
            s.supply -= quantity;
        });
    }

    void eosdactoken::newmemterms(string terms, string hash) {
        // print("In newmemterms(). ");

        require_auth(_self);

        // sample IPFS: QmXjkFQjnD8i8ntmwehoAHBfJEApETx8ebScyVzAHqgjpD
        eosio_assert(!terms.empty(), "Member terms cannot be empty.");
        eosio_assert(terms.length() <= 256, "Member terms document url should be less than 256 characters long.");

        eosio_assert(!hash.empty(), "Member terms document hash cannot be empty.");
        eosio_assert(hash.length() <= 32, "Member terms document hash should be less than 32 characters long.");

        // guard against duplicate of latest
        if (memberterms.begin() != memberterms.end()) {
            auto last = --memberterms.end();
            eosio_assert(!(terms == last->terms && hash == last->hash),
                         "Next member terms cannot be duplicate of the latest.");
        }

        uint64_t next_version = (memberterms.begin() == memberterms.end() ? 0 : (--memberterms.end())->version) + 1;

        memberterms.emplace(_self, [&](termsinfo &termsinfo) {
            termsinfo.terms = terms;
            termsinfo.hash = hash;
            termsinfo.version = next_version;
        });
    }

    void eosdactoken::memberreg(name sender, string agreedterms) {
        // agreedterms is expected to be the member terms document hash
        require_auth(sender);
        eosio_assert(memberterms.begin() != memberterms.end(), "No valid member terms found.");

        auto latest_member_terms = (--memberterms.end());
        eosio_assert(latest_member_terms->hash == agreedterms, "Agreed terms isn't the latest.");

        auto existingMember = registeredgmembers.find(sender);
        if (existingMember != registeredgmembers.end()) {
            registeredgmembers.modify(existingMember, sender, [&](member &mem) {
                mem.agreedtermsversion = latest_member_terms->version;
            });
        } else {
            registeredgmembers.emplace(sender, [&](member &mem) {
                mem.sender = sender;
                mem.agreedtermsversion = latest_member_terms->version;
            });
        }
    }

    void eosdactoken::updateconfig(name notifycontr) {
        require_auth(_self);

        contr_config newconfig{notifycontr};
        config_singleton.set(newconfig, _self);
    };

    void eosdactoken::updateterms(uint64_t termsid, string newterms) {

        require_auth(_self);

       auto existingterms = memberterms.find(termsid);
       eosio_assert(existingterms != memberterms.end(), "Existing terms not found for the given ID");
       
        memberterms.modify(existingterms, 0, [&](termsinfo &t) {
            t.terms = newterms;
        });
    }

    void eosdactoken::memberunreg(name sender) {
        require_auth(sender);

        auto regMember = registeredgmembers.find(sender);
        eosio_assert(regMember != registeredgmembers.end(), "Member is not registered");
        registeredgmembers.erase(regMember);
    }

    contr_config eosdactoken::configs() {
        contr_config conf = config_singleton.get_or_default(contr_config());
        config_singleton.set(conf, _self);
        return conf;
    }

} /// namespace eosdac

EOSIO_ABI(eosdac::eosdactoken, (memberreg)(memberunreg)(create)(issue)(transfer)(burn)(newmemterms)(unlock)
(updateconfig)(updateterms))
