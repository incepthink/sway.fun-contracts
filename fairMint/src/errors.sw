library;

pub enum PaymentError {
    MintNotActive: (),
    MintAlreadyActive: (),
    MaxSupplyExceeded: (),
    Unauthorized: (),
    InsufficientFunds: (),
}

pub enum ContributionError {
    InsufficientAmount: (),
    InvalidAmount: (),
}