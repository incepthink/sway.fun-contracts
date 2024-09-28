library;

pub struct AddLiquidityEvent {
    pub token_amount: u64,
    pub base_amount: u64,
}

pub struct SwapEvent {
    pub input_asset: AssetId,
    pub output_asset: AssetId,
    pub input_amount: u64,
    pub output_amount: u64,
}

pub struct PoolInfo {
    pub token_reserve: u64,
    pub base_reserve: u64,
    pub token_asset_id: AssetId,
    pub base_asset_id: AssetId,
    pub liquidity_locked: bool,
}
