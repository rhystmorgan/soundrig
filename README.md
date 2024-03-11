# soundrig

SoundRig CIP68 Album Contracts

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

---

## To Do 

How many albums should we enable as standard?

How should we allow to mint more albums?

What fees do we charge and where are those payments verified?