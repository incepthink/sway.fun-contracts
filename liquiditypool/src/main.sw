contract;

mod errors;
mod events;

use sway_libs::{
    ownership::*,
};
use ::errors::{InitError, InputError, SwapError};
use ::events::{AddLiquidityEvent, SwapEvent, PoolInfo};
use std::{asset::transfer, auth::msg_sender, storage::storage_string::*, context::msg_amount, identity::Identity, call_frames::msg_asset_id};
use standards::src5::*;

configurable {
    FEE_RATE: u64 = 30,
    TOKEN_ASSET_ID: b256 = 0x0000000000000000000000000000000000000000000000000000000000000000,
    BASE_ASSET_ID: b256 = 0x0000000000000000000000000000000000000000000000000000000000000000,
}


storage {
    owner: State = State::Uninitialized,
    token_reserve: u64 = 0,
    base_reserve: u64 = 0,
    liquidity_locked: bool = false,
    pending_token_amount: u64 = 0,
    pending_base_amount: u64 = 0,
}

abi LiquidityPoolContract {
    #[storage(read, write)]
    fn constructor(owner: Identity);

    #[storage(read, write)]
    #[payable]
    fn deposit_liquidity();

    #[storage(read, write)]
    fn finalize_initial_liquidity();

    #[storage(read, write)]
    #[payable]
    fn swap_exact_tokens_for_base(min_base_out: u64) -> u64;

    #[storage(read, write)]
    #[payable]
    fn swap_exact_base_for_tokens(min_tokens_out: u64) -> u64;

    #[storage(read)]
    fn get_price() -> u64;

    #[storage(read)]
    fn get_pool_info() -> PoolInfo;
}

impl LiquidityPoolContract for Contract {
    #[storage(read, write)]
    fn constructor(owner: Identity) {
        initialize_ownership(owner);
        let token_asset_id = AssetId::from(TOKEN_ASSET_ID);
        let base_asset_id = AssetId::from(BASE_ASSET_ID);
        require(token_asset_id != base_asset_id, InitError::IdenticalAssets);
    }

    #[storage(read, write)]
    #[payable]
    fn deposit_liquidity() {
        only_owner();
        let amount = msg_amount();
        let asset_id = msg_asset_id();
        let token_asset_id = AssetId::from(TOKEN_ASSET_ID);
        let base_asset_id = AssetId::from(BASE_ASSET_ID);
        require(amount > 0, InputError::InvalidAmounts);

        if asset_id == token_asset_id {
            storage.pending_token_amount.write(storage.pending_token_amount.read() + amount);
        } else if asset_id == base_asset_id {
            storage.pending_base_amount.write(storage.pending_base_amount.read() + amount);
        } else {
            require(false, InputError::InvalidAsset);
        }
    }

    #[storage(read, write)]
    fn finalize_initial_liquidity() {
        only_owner();
        let token_amount = storage.pending_token_amount.read();
        let base_amount = storage.pending_base_amount.read();
        let token_asset_id = AssetId::from(TOKEN_ASSET_ID);
        let base_asset_id = AssetId::from(BASE_ASSET_ID);

        require(token_amount > 0 && base_amount > 0, InputError::InvalidAmounts);

        storage.token_reserve.write(token_amount);
        storage.base_reserve.write(base_amount);
        storage.liquidity_locked.write(true);

        // Reset pending amounts
        storage.pending_token_amount.write(0);
        storage.pending_base_amount.write(0);

        log(AddLiquidityEvent {
            token_amount,
            base_amount,
        });
    }

    #[storage(read, write)]
    #[payable]
    fn swap_exact_tokens_for_base(min_base_out: u64) -> u64 {
        let token_amount = msg_amount();
        let asset_id = msg_asset_id();
        let token_asset_id = AssetId::from(TOKEN_ASSET_ID);
        let base_asset_id = AssetId::from(BASE_ASSET_ID);
        let token_reserve = storage.token_reserve.read();
        let base_reserve = storage.base_reserve.read();
        
        require(token_amount > 0, InputError::InvalidAmount);
        require(asset_id == token_asset_id, InputError::InvalidAsset);

        let base_amount = calculate_swap_output(token_amount, token_reserve, base_reserve);
        require(base_amount >= min_base_out, SwapError::InsufficientOutputAmount);

        storage.token_reserve.write(token_reserve + token_amount);
        storage.base_reserve.write(base_reserve - base_amount);

        transfer(msg_sender().unwrap(), base_asset_id, base_amount);

        log(SwapEvent {
            input_asset: token_asset_id,
            output_asset: base_asset_id,
            input_amount: token_amount,
            output_amount: base_amount,
        });

        base_amount
    }

    #[storage(read, write)]
    #[payable]
    fn swap_exact_base_for_tokens(min_tokens_out: u64) -> u64 {
        require(storage.liquidity_locked.read(), SwapError::LiquidityNotAvailable);
        let base_amount = msg_amount();
        let asset_id = msg_asset_id();
        let token_asset_id = AssetId::from(TOKEN_ASSET_ID);
        let base_asset_id = AssetId::from(BASE_ASSET_ID);
        let token_reserve = storage.token_reserve.read();
        let base_reserve = storage.base_reserve.read();

        require(base_amount > 0, InputError::InvalidAmount);
        require(asset_id == base_asset_id, InputError::InvalidAsset);

        let token_amount = calculate_swap_output(base_amount, base_reserve, token_reserve);
        require(token_amount >= min_tokens_out, SwapError::InsufficientOutputAmount);

        storage.token_reserve.write(token_reserve - token_amount);
        storage.base_reserve.write(base_reserve + base_amount);

        transfer(msg_sender().unwrap(), token_asset_id, token_amount);

        log(SwapEvent {
            input_asset: base_asset_id,
            output_asset: token_asset_id,
            input_amount: base_amount,
            output_amount: token_amount,
        });

        token_amount
    }

    #[storage(read)]
    fn get_price() -> u64 {
        let token_reserve = storage.token_reserve.read();
        let base_reserve = storage.base_reserve.read();
        require(token_reserve > 0, InputError::ZeroReserve);

        base_reserve * 1_000_000 / token_reserve 
    }

    #[storage(read)]
    fn get_pool_info() -> PoolInfo {
        let token_asset_id = AssetId::from(TOKEN_ASSET_ID);
        let base_asset_id = AssetId::from(BASE_ASSET_ID);
        PoolInfo {
            token_reserve: storage.token_reserve.read(),
            base_reserve: storage.base_reserve.read(),
            token_asset_id,
            base_asset_id,
            liquidity_locked: storage.liquidity_locked.read(),
        }
    }
}

fn calculate_swap_output(input_amount: u64, input_reserve: u64, output_reserve: u64) -> u64 {
    let input_amount_with_fee = input_amount * (10000 - FEE_RATE);
    let numerator = input_amount_with_fee * output_reserve;
    let denominator = input_reserve + input_amount_with_fee;
    numerator / denominator
}