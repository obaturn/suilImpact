#[allow(duplicate_alias, unused_use)]
module practicaldonation::practicaldonation;
use sui::object::{Self, UID};
use sui::event;
use sui::tx_context::{Self as tx_context, TxContext};
use std::string::{Self, String};
use std::string as string_std;
use sui::transfer;
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
    
    };
    prc
}

public fun donate(donation: &mut PracticalDonation, amount: u64, ctx: &mut TxContext) {
    donation.total_money_donated = donation.total_money_donated+ amount;
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
