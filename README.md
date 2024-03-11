# soundrig

SoundRig CIP68 Album Contracts

---

## Contract Structure

Album Minting Policy - Mints the AlbumNFT (sends to Album Validator) and the Fractionalised UserTokens ( sends to Distribution Validator ) 

Album Validator - Locks the AlbumNFT ( only updatable by the owner through soundrig )

Distribution Validator - Locks the UserTokens ready to be purchased ( one at a time )

Reference Minting Validator - Mints the token that identifies the reference data for the Album Minting Policy

Reference Validator - Mints a token and attaches a datum for the Album Minting Policy to use as a reference input

---

## Draft State

this is the initial state of the SoundRig Contracts

currently the lucid code only mints and doesnt burn

we dont charge for redeeming an album ( pending payment methods )

we also dont charge for the creation of the album ( pending payment methods )

## Metadata Structure

until we are ready to test the metadata mechanism, I have reverted to the standard metadata structure for CIP-68

```
Datum {
  metadata: {
    name: ,
    image: ,
    mediaType: ,
  },
  version: 0,
}
```

this will change when we start testing properly, but for the meantime it will enable us to continue working on the dapp

---

## IMPORTANT DETAILS

We will only mint the reference token once, but it needs to be available to mint albums,

it is added as a reference input to the transactions

We will need to fix a few things in these contracts

e.g. We need to only allow album updates if the transaction is signed by the creator of the album

this is not implemented yet

---

## To Do 

How many albums should we enable as standard?

How should we allow to mint more albums?

What fees do we charge and where are those payments verified?