library;

pub enum AmountError {
    AmountMismatch: (),
}

pub enum MintError {
    MaxMinted: (),
    NotAuthorized: (),
}

pub enum SetError {
    ValueAlreadySet: (),
}