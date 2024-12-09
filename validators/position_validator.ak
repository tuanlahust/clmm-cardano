use aiken/dict
use aiken/hash.{Blake2b_224, Hash}
use aiken/transaction.{Mint, ScriptContext, Transaction}
use aiken/transaction/credential.{VerificationKey}
use aiken/transaction/value.{PolicyId, Value}
use global_memory
use keys
use types.{PoolDatum, PoolId, PositionDatum}
use utils

type PositionInput {
  pool_policy_id: PolicyId,
  tick_policy_id: PolicyId,
  owner: Hash<Blake2b_224, VerificationKey>,
  tick_lower: Int,
  tick_upper: Int,
}

validator(global_policy_id: PolicyId, pool_id: PoolId) {
  fn mint(position_input: PositionInput, ctx: ScriptContext) -> Bool {
    expect ScriptContext { purpose: Mint(policy_id), transaction } = ctx
    let Transaction {
      mint,
      inputs,
      outputs,
      reference_inputs: ref_inputs,
      extra_signatories,
      ..
    } = transaction

    let mint_value: Value = value.from_minted_value(mint)
    expect [Pair(asset_name, 1)] =
      mint_value
        |> value.tokens(policy_id)
        |> dict.to_pairs

    let PositionInput {
      pool_policy_id,
      tick_policy_id,
      owner,
      tick_lower,
      tick_upper,
    } = position_input

    let local_key =
      keys.get_position_key(pool_policy_id, owner, tick_lower, tick_upper)

    expect [owner] == extra_signatories
    expect asset_name == utils.convert_key_to_asset(local_key)

    let address = credential.from_script(policy_id)
    let lower_key = keys.get_tick_key(pool_policy_id, tick_lower)
    let upper_key = keys.get_tick_key(pool_policy_id, tick_upper)
    let global_key = keys.get_global_key(policy_id, asset_name)

    expect pool_datum: PoolDatum =
      utils.exact_nft_datum(utils.i2o(ref_inputs), pool_policy_id, pool_id)
    expect position_datum: PositionDatum =
      utils.exact_nft_datum(outputs, policy_id, local_key)

    and {
      check_mint_position(
        pool_datum,
        position_datum,
        pool_policy_id,
        tick_policy_id,
        policy_id,
      ),
      utils.check_same_address(outputs, policy_id, address),
      utils.has_nft_by_key(tick_policy_id, lower_key, utils.i2o(ref_inputs)),
      utils.has_nft_by_key(tick_policy_id, upper_key, utils.i2o(ref_inputs)),
      global_memory.check_mint_nft_global(
        mint_value,
        global_policy_id,
        global_key,
        inputs,
        outputs,
      ),
    }
  }

  fn spend(
    _position_datum: PositionDatum,
    _r: Void,
    _ctx: ScriptContext,
  ) -> Bool {
    True
  }
}

fn check_mint_position(
  pool_datum: PoolDatum,
  position_datum: PositionDatum,
  pool_policy_id: PolicyId,
  tick_policy_id: PolicyId,
  position_policy_id: PolicyId,
) -> Bool {
  and {
    pool_datum.tick_policy_id == tick_policy_id,
    pool_datum.position_policy_id == position_policy_id,
    position_datum.pool_policy_id == pool_policy_id,
    position_datum.tick_lower < position_datum.tick_upper,
  }
}
