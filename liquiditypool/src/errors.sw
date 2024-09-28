library;

pub enum InitError {
    IdenticalAssets: (),
    LiquidityAlreadyAdded: (),
}

pub enum InputError {
    InvalidAmounts: (),
    InvalidAmount: (),
    NotOwner: (),
    InvalidAsset: (),
    ZeroReserve: (),
}

pub enum SwapError {
    LiquidityNotAvailable: (),
    InsufficientOutputAmount: (),
}
