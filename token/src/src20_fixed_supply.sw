contract;

mod errors;
mod interface;

use sway_libs::{
    asset::{
        base::{
            _decimals,
            _name,
            _set_decimals,
            _set_name,
            _set_symbol,
            _symbol,
            _total_assets,
            _total_supply,
            SetAssetAttributes,
        },
        supply::{
            _burn,
            _mint,
        },
    },
    ownership::{
        _owner,
        initialize_ownership,
        only_owner,
    }
};
use sway_libs::asset::metadata::*;
use standards::{src20::SRC20, src3::SRC3, src5::{SRC5, State}, src7::{Metadata, SRC7}};
use interface::Constructor;
use std::{context::msg_amount, hash::Hash, storage::storage_string::*, string::String, asset::transfer};
use errors::{AmountError, MintError, SetError};

// The SRC-20 storage block
storage {
    total_assets: u64 = 0,
    total_supply: StorageMap<AssetId, u64> = StorageMap {},
    name: StorageMap<AssetId, StorageString> = StorageMap {},
    symbol: StorageMap<AssetId, StorageString> = StorageMap {},
    decimals: StorageMap<AssetId, u8> = StorageMap {},
    cumulative_supply: StorageMap<AssetId, u64> = StorageMap {},
    metadata: StorageMetadata = StorageMetadata {},
    launched: bool = false,
}

configurable {
    /// The maximum supply, this will be passed as an argument during deployment.configurable constants which can be changed during the contract deployment in the SDK
    MAX_SUPPLY: u64 = 100_000_000,
}

#[storage(read, write)]
fn launch() {
    only_owner();
    storage.launched.write(true);
}

impl SRC20 for Contract {
    #[storage(read)]
    fn total_assets() -> u64 {
        _total_assets(storage.total_assets)
    }

    #[storage(read)]
    fn total_supply(asset: AssetId) -> Option<u64> {
        _total_supply(storage.total_supply, asset)
    }

    #[storage(read)]
    fn name(asset: AssetId) -> Option<String> {
        _name(storage.name, asset)
    }

    #[storage(read)]
    fn symbol(asset: AssetId) -> Option<String> {
        _symbol(storage.symbol, asset)
    }

    #[storage(read)]
    fn decimals(asset: AssetId) -> Option<u8> {
        _decimals(storage.decimals, asset)
    }
}

impl SRC3 for Contract {
    #[storage(read,write)]
    fn mint(recipient: Identity, sub_id: SubId, amount: u64) {
        only_owner();

        let asset = AssetId::new(ContractId::this(), sub_id);
        let cumulative_supply = storage.cumulative_supply.get(asset).try_read().unwrap_or(0);
        require(
            cumulative_supply + amount <= MAX_SUPPLY,
            MintError::MaxMinted,
        );
        storage
            .cumulative_supply
            .insert(asset, cumulative_supply + amount);
        let _ = _mint(
            storage
                .total_assets,
            storage
                .total_supply,
            recipient,
            sub_id,
            amount,
        );
    }

    #[payable]
    #[storage(read, write)]
    fn burn(sub_id: SubId, amount: u64) {
        require(msg_amount() == amount, AmountError::AmountMismatch);
        _burn(storage.total_supply, sub_id, amount);
    }
}

impl SRC5 for Contract {
     #[storage(read)]
    fn owner() -> State {
        _owner()
    }
}

impl SRC7 for Contract {
    #[storage(read)]
    fn metadata(asset: AssetId, key: String) -> Option<Metadata> {
        // Return the stored metadata
        storage.metadata.get(asset, key)
    }
}

impl SetAssetAttributes for Contract {
    #[storage(write)]
    fn set_name(asset: AssetId, name: String) {
        only_owner();

        require(
            storage
                .name
                .get(asset)
                .read_slice()
                .is_none(),
            SetError::ValueAlreadySet,
        );
        _set_name(storage.name, asset, name);
    }

    #[storage(write)]
    fn set_symbol(asset: AssetId, symbol: String) {
        only_owner();

        require(
            storage
                .symbol
                .get(asset)
                .read_slice()
                .is_none(),
            SetError::ValueAlreadySet,
        );
        _set_symbol(storage.symbol, asset, symbol);
    }

    #[storage(write)]
    fn set_decimals(asset: AssetId, decimals: u8) {
        only_owner();

        require(
            storage
                .decimals
                .get(asset)
                .try_read()
                .is_none(),
            SetError::ValueAlreadySet,
        );
        _set_decimals(storage.decimals, asset, decimals);
    }
}

impl SetAssetMetadata for Contract {
    #[storage(read, write)]
    fn set_metadata(asset: AssetId, key: String, metadata: Metadata) {
        _set_metadata(storage.metadata, asset, key, metadata);
    }
}

abi Transfer {
    #[storage(read, write)]
    fn transfer(target: Identity, asset_id: AssetId, coins: u64);
}

impl Transfer for Contract {
    #[storage(read, write)]
    fn transfer(target: Identity, asset_id: AssetId, coins: u64) {
        let owner_state = _owner();
        let launched = storage.launched.read();

       if !launched {
            require(
                match owner_state {
                    State::Initialized(owner) => target == owner,
                    _ => false,
                },
                "Forbidden Action"
            );
        }

        transfer(target, asset_id, coins);
    }
}

impl Constructor for Contract {
    #[storage(read, write)]
    fn constructor(owner: Identity) {
        initialize_ownership(owner);
    }
}





