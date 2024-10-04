contract;

mod errors;

use sway_libs::{
    ownership::*,
};
use std::{context::{msg_amount, balance_of}, hash::Hash, storage::storage_string::*, auth::msg_sender, identity::Identity, asset::transfer};
use errors::{PaymentError, ContributionError};
use standards::src5::*;

storage {
    owner: State = State::Uninitialized,
    fair_mint_active: bool = false,
    contributions: StorageMap<Identity, u64> = StorageMap {},
    total_contributed: u64 = 0,
}

abi FairMintContract {
    #[storage(read, write)]
    fn constructor(owner: Identity);

    #[storage(read, write)]
    fn start_fair_mint();

    #[storage(read, write)]
    fn end_fair_mint();

    #[storage(read, write)]
    #[payable]
    fn contribute();

    #[storage(read)]
    fn get_contribution(buyer: Identity) -> u64;

    #[storage(read)]
    fn total_contributed() -> u64;

    #[storage(read, write)]
    fn withdraw_funds(amount: u64);
}

impl FairMintContract for Contract {
    #[storage(read, write)]
    fn constructor(owner: Identity) {
        initialize_ownership(owner);
    }

    #[storage(read, write)]
    fn start_fair_mint() {
        only_owner();
        require(!storage.fair_mint_active.read(), PaymentError::MintAlreadyActive);
        storage.fair_mint_active.write(true);
    }

    #[storage(read, write)]
    fn end_fair_mint() {
        only_owner();
        require(storage.fair_mint_active.read(), PaymentError::MintNotActive);
        storage.fair_mint_active.write(false);
    }

    #[storage(read, write)]
    #[payable]
    fn contribute() {
        let amount = msg_amount();
        let sender = msg_sender().unwrap();

        require(storage.fair_mint_active.read(), PaymentError::MintNotActive);
        require(amount > 0, ContributionError::InvalidAmount);

        let previous_contribution = storage.contributions.get(sender).try_read().unwrap_or(0);
        storage.contributions.insert(sender, previous_contribution + amount);
        storage.total_contributed.write(storage.total_contributed.read() + amount);
    }

    #[storage(read)]
    fn get_contribution(buyer: Identity) -> u64 {
        return storage.contributions.get(buyer).try_read().unwrap_or(0);
    }

    #[storage(read)]
    fn total_contributed() -> u64 {
        storage.total_contributed.read()
    }

    #[storage(read, write)]
    fn withdraw_funds(amount: u64) {
        only_owner();
        let contract_balance = balance_of(ContractId::this(), AssetId::base());

        require(amount <= contract_balance, PaymentError::InsufficientFunds);

         match storage.owner.read() {
        State::Initialized(owner) => {
            transfer(owner, AssetId::base(), amount);
        }
        _ => {
            // Handle the case where the owner is not initialized
            revert(0);
        }
    }
    }
}
