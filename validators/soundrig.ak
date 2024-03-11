use aiken/dict
use aiken/list
use aiken/transaction.{
  InlineDatum, Input, Mint, Output, ScriptContext, Spend, Transaction,
  find_input, find_script_outputs,
}
use aiken/transaction/credential.{ScriptCredential, from_script}
use aiken/transaction/value.{
  PolicyId, from_minted_value, lovelace_of, quantity_of, tokens,
}
use soundrig/okapi as ok

type MintAction {
  a: Int,
  tn: ByteArray,
  n: Int,
}

type MetadataAction {
  a: Int,
  m: ok.TokenMetadata,
}

type LockAction {
  a: Int,
}

type RefAction {
  a: Int,
  m: ok.ScriptHash,
}

type RefMintAction {
  a: Int,
  s: ok.ScriptHash,
  m: ok.ScriptHash,
}

type RefDatum {
  m: ok.ScriptHash,
  p: PolicyId,
}

type VestingDatum {
  a: Int,
}

//            //
// Album Mint //
//            //

validator(owner: ok.VerificationKeyHash) {
  fn srmint(r: MintAction, ctx: ScriptContext) {
    let ScriptContext { transaction, purpose } = ctx
    expect Mint(policy_id) = purpose

    let Transaction { mint, outputs, .. } = transaction

    expect [(ref_asset_name, ref_amount), (user_asset_name, user_amount)] =
      mint
        |> value.from_minted_value
        |> value.tokens(policy_id)
        |> dict.to_list()

    expect ok.tx_signed_by(transaction, owner)
    when r.a is {
      0 -> {
        // Has reference input
        expect Some(input) =
          transaction.reference_inputs
            |> list.head()

        // Ref input has ReferenceDatum
        let Input { output, .. } = input
        expect InlineDatum(datum) = output.datum
        expect datum: RefDatum = datum
        let ref_datum = datum

        // Album Ref Token to Locking Script
        expect
          list.any(
            outputs,
            fn(output) {
              expect InlineDatum(datum) = output.datum
              expect _datum: ok.TokenDatum = datum
              output.address == from_script(ref_datum.m) && value.quantity_of(
                output.value,
                policy_id,
                ref_asset_name,
              ) == 1
            },
          )
        // Fractionalised user tokens to sale validator
        expect
          list.any(
            outputs,
            fn(output) {
              value.quantity_of(output.value, policy_id, user_asset_name) == r.n
            },
          )
        let token_name_list = ok.fraction_pair_prefix(r.tn)
        let ref_tn_check =
          ok.compare_token_names(ref_asset_name, list.at(token_name_list, 0))
        let user_tn_check =
          ok.compare_token_names(user_asset_name, list.at(token_name_list, 1))
        ref_amount == 1 && user_amount == r.n && ref_tn_check? && user_tn_check?
      }
      _ -> {
        let token_name_list = ok.fraction_pair_prefix(r.tn)
        let ref_tn_check =
          ok.compare_token_names(ref_asset_name, list.at(token_name_list, 0))
        let user_tn_check =
          ok.compare_token_names(user_asset_name, list.at(token_name_list, 1))
        ref_amount == -1 && user_amount == -r.n && ref_tn_check? && user_tn_check?
      }
    }
  }
}

//                           //
// Reference Token Validator //
//                           //

validator(cs: PolicyId, owner: ok.VerificationKeyHash) {
  fn srlock(d: ok.TokenDatum, r: MetadataAction, c: ScriptContext) {
    let ScriptContext { transaction, purpose } = c
    expect Spend(ownRef) = purpose

    let Transaction { outputs, .. } = transaction

    expect Some(input) =
      transaction.inputs
        |> find_input(ownRef)

    let Input { .. } = input

    expect ScriptCredential(script_hash) =
      input.output.address.payment_credential

    // own inpot has single ref token
    let input_cs = dict.values(tokens(input.output.value, cs)) == [1]

    when r.a is {
      1 -> {
        expect
          list.any(
            outputs,
            fn(output) {
              expect InlineDatum(datum) = output.datum
              expect datum: ok.TokenDatum = datum
              let output_cs = dict.values(tokens(output.value, cs)) == [1]
              let lovelace_value_check =
                lovelace_of(input.output.value) <= lovelace_of(output.value)
              let metadata_name_check = datum.metadata.name == d.metadata.name
              output.address == from_script(script_hash) && output_cs? && lovelace_value_check? && metadata_name_check? && r.m == datum.metadata
            },
          )
        input_cs? && ok.tx_signed_by(transaction, owner)?
      }
      _ -> ok.tx_signed_by(transaction, owner)?
    }
  }
}

//                      //
// Album Sale Validator //
//                      //

validator(owner: ok.VerificationKeyHash) {
  fn srvest(d: VestingDatum, r: LockAction, c: ScriptContext) -> Bool {
    when r.a is {
      1 -> {
        let out = ok.get_own_singleton_output(c)
        let in = ok.get_own_input(c)

        expect InlineDatum(datum) = out.datum
        expect datum: VestingDatum = datum

        // only withdraw a single token
        ok.keep_own_lovelace_value(c) && ok.has_one_singleton_asset_less(
          in.value,
          out.value,
        ) && d == datum
      }
      _ -> ok.tx_signed_by(c.transaction, owner)
    }
  }
}

//                          //
// Reference UTxO Validator //
//                          //

validator(owner: ok.VerificationKeyHash) {
  fn reference_validator(
    dat: RefDatum,
    red: RefAction,
    ctx: ScriptContext,
  ) -> Bool {
    let ScriptContext { transaction, purpose } = ctx
    expect Spend(ownRef) = purpose

    let Transaction { .. } = transaction

    expect Some(input) =
      transaction.inputs
        |> find_input(ownRef)

    let Input { .. } = input

    expect ScriptCredential(script_hash) =
      input.output.address.payment_credential

    expect Some(output) =
      transaction.outputs
        |> find_script_outputs(script_hash)
        |> list.head()

    let Output { .. } = output

    expect InlineDatum(datum) = output.datum
    expect datum: RefDatum = datum

    // lovelace value unchanged
    let lovelace_value_check =
      lovelace_of(input.output.value) <= lovelace_of(output.value)

    let tx_signed_by = list.has(transaction.extra_signatories, owner)

    let datum_refCS_check = datum.p == dat.p

    let input_cs = dict.values(tokens(input.output.value, dat.p)) == [1]
    let output_cs = dict.values(tokens(output.value, dat.p)) == [1]

    when red.a is {
      1 -> {
        let update_metadata_script = datum.m == red.m

        input_cs? && output_cs? && update_metadata_script? && datum_refCS_check? && lovelace_value_check? && tx_signed_by?
      }

      _ -> output_cs? && tx_signed_by?
    }
  }
}

//               //
// Ref UTxO Mint //
//               //

validator(owner: ok.VerificationKeyHash) {
  fn reference_mint(r: RefMintAction, ctx: ScriptContext) -> Bool {
    let ScriptContext { transaction, purpose } = ctx
    expect Mint(policy_id) = purpose

    let Transaction { mint, outputs, .. } = transaction

    expect [(asset_name, amount)] =
      mint
        |> from_minted_value()
        |> tokens(policy_id)
        |> dict.to_list()

    when r.a is {
      1 -> {
        expect
          list.any(
            outputs,
            fn(output) {
              expect InlineDatum(datum) = output.datum
              expect datum: RefDatum = datum
              output.address == from_script(r.s) && quantity_of(
                output.value,
                policy_id,
                asset_name,
              ) == 1 && datum.m == r.m
            },
          )
        amount == 1 && ok.tx_signed_by(transaction, owner)
      }
      _ -> amount == -1 && ok.tx_signed_by(transaction, owner)
    }
  }
}
