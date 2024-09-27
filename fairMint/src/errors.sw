library;

pub enum PaymentError {
    MintNotActive: (),
    MintAlreadyActive: (),
    MaxSupplyExceeded: (),
    Unauthorized: (),
}

pub enum ContributionError {
    InsufficientAmount: (),
}