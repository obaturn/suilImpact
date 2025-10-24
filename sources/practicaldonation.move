#[allow(duplicate_alias, unused_use)]
module practicaldonation::practicaldonation;
use sui::object::{Self, UID};
use sui::event;
use sui::tx_context::{Self as tx_context, TxContext};
use std::string::{Self, String};
use std::string as string_std;
use sui::transfer;
use sui::coin::{Self, Coin};
use sui::balance::{Self, Balance};
use sui::sui::SUI;
const E_NOT_OWNER: u64 = 1;
const E_INSUFFICIENT_FUNDS: u64 = 2;
const E_INVALID_AMOUNT : u64 =3;
const E_RECIPIENT_NOT_VERIFIED: u64 = 4;
const E_INVALID_INDEX: u64 = 5;
const E_INVALID_ADDRESS: u64 = 6;
const E_RECIPIENT_ALREADY_VERIFIED: u64 = 7;


public struct DonationEvent has copy, drop {
    donor: address,
    amount: u64,
    category: DonationCategory,
    data: DonationData,
}
public enum DonationData has copy, drop {
    Money { amount: u64 },
    PhysicalItem { item: PhysicalItems },
    DigitalAsset { asset: DigitalAsset },
}
public enum DonationCategory has copy, drop {
    MONEY,
    PHYSICAL_GOODS,
    DIGITAL_ASSETS,
    
}
public struct RecipientRegistered has copy, drop {
    recipient_address: address,
    help_needed: String,
    help_amount: u64,
}

public struct RecipientVerified has copy, drop {
    recipient_index: u64,
    recipient_address: address,
}

public struct FundsDistributed has copy, drop {
    recipient_index: u64,
    recipient_address: address,
    amount: u64,
}

public struct HelpConfirmed has copy, drop {
    recipient_index: u64,
    recipient_address: address,
}

public struct PhysicalItems has store,copy, drop {
    name: String,
    description: String,
    quantity: u64,
    estimated_value: u64,
}
public struct DigitalAsset has store, copy, drop {
    asset_id: ID,
    name: String,
    description: String,
    asset_type: String, // e.g., "NFT", "Token", etc.
}
public struct Recipient has  store , drop{
   
    address: address,
    help_needed: String,
    verification_status: bool,
    received_status: bool,
    help_amount : u64,
}
public struct PracticalDonation has key, store {
    id: UID,
    owner: address,
    metadata_uri: vector<u64>,
    verified: bool,
    total_money_donated: u64,
    physical_items: vector<PhysicalItems>,
    digital_assets: vector<DigitalAsset>,
    total_physical_value: u64,
    total_digital_value: u64,
    balance: Balance<SUI>,
    recipients: vector<Recipient>,
    
}

public fun create_practical_donation(ctx: &mut TxContext,
    owner: address,
    metadata_uri: vector<u64>,
    verified: bool,
): PracticalDonation {
    let prc = PracticalDonation {
        id: object::new(ctx),
        owner,
        metadata_uri,
        verified,
        total_money_donated: 0,
        physical_items: vector::empty<PhysicalItems>(),
        digital_assets: vector::empty<DigitalAsset>(),
        total_physical_value: 0,
        total_digital_value: 0,
        balance: balance::zero<SUI>(),
        recipients: vector::empty<Recipient>(),
    
    };
    prc
}

public fun donate(donation: &mut PracticalDonation, payment: Coin<SUI>, ctx: &mut TxContext) {
    let amount = coin::value(&payment);
    balance::join(&mut donation.balance, coin::into_balance(payment));
    donation.total_money_donated = donation.total_money_donated + amount;
    event::emit(DonationEvent {
        donor: tx_context::sender(ctx),
        amount,
        category: DonationCategory::MONEY,
        data: DonationData::Money { amount },
    });
}

public fun donate_physical_item(donation: &mut PracticalDonation, item: PhysicalItems, ctx: &mut TxContext) {
    donation.total_physical_value = donation.total_physical_value + item.estimated_value;
    vector::push_back(&mut donation.physical_items, item);
    event::emit(DonationEvent {
        donor: tx_context::sender(ctx),
        amount: item.estimated_value,
        category: DonationCategory::PHYSICAL_GOODS,
        data: DonationData::PhysicalItem { item },
    });
}
public fun donate_digital_asset<T: key + store>(
    donation: &mut PracticalDonation,
    nft: T,  // The actual NFT object
    name: String,
    description: String,
    asset_type: String,
    ctx: &mut TxContext
) {
    // Get the ID before transferring
    let asset_id = object::id(&nft);

    // Transfer the NFT to the donation contract
    transfer::public_transfer(nft, donation.owner);

    // Create metadata record
    let asset = DigitalAsset {
        asset_id,  // Use the ID obtained before transfer
        name,
        description,
        asset_type,
    };

    // Update tracking
    donation.total_digital_value = donation.total_digital_value + 0; // Or calculate value
    vector::push_back(&mut donation.digital_assets, asset);

    // Emit event
    event::emit(DonationEvent {
        donor: tx_context::sender(ctx),
        amount: 0,
        category: DonationCategory::DIGITAL_ASSETS,
        data: DonationData::DigitalAsset { asset },
    });
}
public fun withdraw_funds(donation: &mut PracticalDonation, amount: u64, ctx: &mut TxContext) {
    let caller = tx_context::sender(ctx);
    assert!(caller == donation.owner, E_NOT_OWNER);

    // Check if there's enough balance
    assert!(balance::value(&donation.balance) >= amount, E_INSUFFICIENT_FUNDS);

    // Check for valid amount
    assert!(amount > 0, E_INVALID_AMOUNT);

    // Withdraw the coins
    let withdrawn_balance = balance::split(&mut donation.balance, amount);
    let withdrawn_coin = coin::from_balance(withdrawn_balance, ctx);

    // Transfer to owner
    transfer::public_transfer(withdrawn_coin, donation.owner);

    // Update total donated (subtracting the withdrawn amount)
    donation.total_money_donated = donation.total_money_donated - amount;
}

public fun register_recipient(
    donation: &mut PracticalDonation,
    address: address,
    help_needed: String,
    help_amount: u64,
) {
    
    assert!(address != @0x0, E_INVALID_ADDRESS);
    assert!(help_amount > 0, E_INVALID_AMOUNT);

    let recipient = Recipient {
        address,
        help_needed,
        verification_status: false,
        received_status: false,
        help_amount,
    };
    vector::push_back(&mut donation.recipients, recipient);
    event::emit(RecipientRegistered {
        recipient_address: address,
        help_needed,
        help_amount,
    });
}
public fun verify_recipient(donation: &mut PracticalDonation, index: u64 , ctx: &mut TxContext) {
    let caller = tx_context::sender(ctx);
    assert!(caller == donation.owner, E_NOT_OWNER);

    
    assert!(index < vector::length(&donation.recipients), E_INVALID_INDEX);

    let recipient_ref = vector::borrow_mut(&mut donation.recipients, index);

    // Check recipient is not already verified
    assert!(!recipient_ref.verification_status, E_RECIPIENT_ALREADY_VERIFIED);

    recipient_ref.verification_status = true;
    event::emit(RecipientVerified {
        recipient_index: index,
        recipient_address: recipient_ref.address,
    });
}
public fun distribute_to_recipient(donation: &mut PracticalDonation, index: u64, ctx: &mut TxContext) {
    let caller = tx_context::sender(ctx);
    assert!(caller == donation.owner, E_NOT_OWNER);

    // Validate index is within bounds
    assert!(index < vector::length(&donation.recipients), E_INVALID_INDEX);

    let recipient_ref = vector::borrow(&donation.recipients, index);
    assert!(recipient_ref.verification_status, E_RECIPIENT_NOT_VERIFIED);

    let amount = recipient_ref.help_amount;
    assert!(balance::value(&donation.balance) >= amount, E_INSUFFICIENT_FUNDS);

    let withdrawn_balance = balance::split(&mut donation.balance, amount);
    let withdrawn_coin = coin::from_balance(withdrawn_balance, ctx);

    transfer::public_transfer(withdrawn_coin, recipient_ref.address);

    donation.total_money_donated = donation.total_money_donated - amount;
    event::emit(FundsDistributed {
        recipient_index: index,
        recipient_address: recipient_ref.address,
        amount,
    });
}
public fun get_recipient_count(donation: &PracticalDonation): u64 {
    vector::length(&donation.recipients)
}
public fun confirm_help_received(donation: &mut PracticalDonation, index: u64) {
    
    assert!(index < vector::length(&donation.recipients), E_INVALID_INDEX);

    let recipient_ref = vector::borrow_mut(&mut donation.recipients, index);
    recipient_ref.received_status = true;
    event::emit(HelpConfirmed {
        recipient_index: index,
        recipient_address: recipient_ref.address,
    });
}
public fun get_balance(donation: &PracticalDonation): u64 {
    balance::value(&donation.balance)
}
public fun get_recipient(donation: &PracticalDonation, index: u64): &Recipient {
    assert!(index < vector::length(&donation.recipients), E_INVALID_INDEX);
    vector::borrow(&donation.recipients, index)
}
public fun get_total_donated(donation: &PracticalDonation): u64 {
    donation.total_money_donated
}
public fun is_recipient_verified(donation: &PracticalDonation, index: u64): bool {
    assert!(index < vector::length(&donation.recipients), E_INVALID_INDEX);
    let recipient_ref = vector::borrow(&donation.recipients, index);
    recipient_ref.verification_status
}