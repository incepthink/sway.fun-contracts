contract;

mod errors;

use sway_libs::{
    ownership::*,
};
use std::{context::msg_amount, hash::Hash, storage::storage_string::*, auth::msg_sender, identity::Identity};
use errors::{PaymentError, ContributionError};
use standards::src5::*;

storage {
    owner: State = State::Uninitialized,
    fair_mint_active: bool = false,
    contributions: StorageMap<Identity, u64> = StorageMap {},
    total_contributed: u64 = 0,
    total_tokens_sold: u64 = 0,
    price_per_token: u64 = 1_000,
    max_tokens: u64 = 100_000_000,
}

configurable {
    MAX_TOKENS: u64 = 100_000_000,
    PRICE_PER_TOKEN: u64 = 1_000,
}

abi PaymentContract {
    #[storage(read, write)]
    fn constructor(owner: Identity);

    #[storage(read, write)]
    fn start_fair_mint();

    #[storage(read, write)]
    fn end_fair_mint();

    #[storage(read, write)] #[payable]
    fn contribute();

    #[storage(read)]
    fn get_contribution(buyer: Identity) -> u64;

    #[storage(read)]
    fn total_contributed() -> u64;

    #[storage(read)]
    fn total_tokens_sold() -> u64;
}

impl PaymentContract for Contract {
    #[storage(read, write)]
    fn constructor(owner: Identity) {
        initialize_ownership(owner);
        storage.price_per_token.write(PRICE_PER_TOKEN);
        storage.max_tokens.write(MAX_TOKENS);
    }

    #[storage(read, write)]
    fn start_fair_mint() {
        only_owner();
        if storage.fair_mint_active.read() {
            require(false, PaymentError::MintAlreadyActive);
        }
        storage.fair_mint_active.write(true);
    }

    #[storage(read, write)]
    fn end_fair_mint() {
        only_owner();
        if !storage.fair_mint_active.read() {
            require(false, PaymentError::MintNotActive);
        }
        storage.fair_mint_active.write(false);
    }

     #[storage(read, write)] #[payable]
    fn contribute() {
        let amount = msg_amount();
        let sender = msg_sender().unwrap(); // Unwrap the Result

        if !storage.fair_mint_active.read() {
            require(false, PaymentError::MintNotActive);
        }

        let tokens_to_allocate = amount / storage.price_per_token.read();

        if storage.total_tokens_sold.read() + tokens_to_allocate > storage.max_tokens.read() {
            require(false, PaymentError::MaxSupplyExceeded);
        }

        let contribution = storage.contributions.get(sender).try_read().unwrap_or(0);
        storage.contributions.insert(sender, contribution + amount); // Corrected

        storage.total_contributed.write(storage.total_contributed.read() + amount);
        storage.total_tokens_sold.write(storage.total_tokens_sold.read() + tokens_to_allocate);
    }

     #[storage(read)]
    fn get_contribution(buyer: Identity) -> u64 {
        return storage.contributions.get(buyer).try_read().unwrap_or(0);
    }

    #[storage(read)]
    fn total_contributed() -> u64 {
        storage.total_contributed.read()
    }

    #[storage(read)]
    fn total_tokens_sold() -> u64 {
        storage.total_tokens_sold.read()
    }
}

