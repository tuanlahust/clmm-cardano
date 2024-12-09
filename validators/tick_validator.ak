use aiken/dict
use aiken/transaction.{Mint, ScriptContext, Transaction}
use aiken/transaction/credential
use aiken/transaction/value.{PolicyId, Value}
use consts
use global_memory
use keys
use types.{PoolDatum, PoolId, TickDatum}
use utils

type TickInput {
  pool_policy_id: PolicyId,
  tick: Int,
}

validator(global_policy_id: PolicyId, pool_id: PoolId) {
  fn mint(tick_input: TickInput, ctx: ScriptContext) -> Bool {
    expect ScriptContext { purpose: Mint(policy_id), transaction } = ctx
    let Transaction { mint, inputs, outputs, reference_inputs: ref_inputs, .. } =
      transaction

    let mint_value: Value = value.from_minted_value(mint)
    expect [Pair(asset_name, 1)] =
      mint_value
        |> value.tokens(policy_id)
        |> dict.to_pairs

    let TickInput { pool_policy_id, tick } = tick_input
    let local_key = keys.get_tick_key(pool_policy_id, tick)
    let address = credential.from_script(policy_id)
    let global_key = keys.get_global_key(policy_id, asset_name)

    expect asset_name == utils.convert_key_to_asset(local_key)
    expect tick_datum: TickDatum =
      utils.exact_nft_datum(outputs, policy_id, local_key)
    expect pool_datum: PoolDatum =
      utils.exact_nft_datum(utils.i2o(ref_inputs), pool_policy_id, pool_id)

    and {
      check_mint_tick(pool_datum, tick_datum, pool_policy_id, policy_id),
      utils.check_same_address(outputs, policy_id, address),
      global_memory.check_mint_nft_global(
        mint_value,
        global_policy_id,
        global_key,
        inputs,
        outputs,
      ),
    }
  }

  fn spend(_tick_datum: TickDatum, _r: Void, _ctx: ScriptContext) -> Bool {
    True
  }
}

fn check_mint_tick(
  pool_datum: PoolDatum,
  tick_datum: TickDatum,
  pool_policy_id: PolicyId,
  tick_policy_id: PolicyId,
) -> Bool {
  and {
    pool_datum.tick_policy_id == tick_policy_id,
    tick_datum.pool_policy_id == pool_policy_id,
    tick_datum.tick % pool_datum.tick_spacing == 0,
    tick_datum.tick >= consts.get_min_tick(),
    tick_datum.tick <= consts.get_max_tick(),
    tick_datum.liquidity_gross == 0,
    tick_datum.liquidity_net == 0,
    tick_datum.fee_growth_outside_0_x128 == 0,
    tick_datum.fee_growth_outside_1_x128 == 0,
    tick_datum.initialized == False,
  }
}
