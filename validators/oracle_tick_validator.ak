use aiken/dict
use aiken/transaction.{Mint, ScriptContext, Transaction}
use aiken/transaction/credential
use aiken/transaction/value.{PolicyId, Value}
use consts
use fullmath
use global_memory
use keys
use types.{OracleTickDatum}
use utils

// sqrtPriceX64 = sqrt(1.001^tick) * 2^64
validator(global_policy_id: PolicyId) {
  fn mint(tick_offset: Int, ctx: ScriptContext) -> Bool {
    expect ScriptContext { purpose: Mint(policy_id), transaction } = ctx
    let Transaction { mint, inputs, outputs, .. } = transaction

    let mint_value: Value = value.from_minted_value(mint)
    expect [Pair(asset_name, 1)] =
      mint_value
        |> value.tokens(policy_id)
        |> dict.to_pairs

    let local_key = keys.get_oracle_tick_key(tick_offset)
    expect asset_name == utils.convert_key_to_asset(local_key)

    let address = credential.from_script(policy_id)
    let global_key = keys.get_global_key(policy_id, asset_name)

    expect oracle_tick: OracleTickDatum =
      utils.exact_nft_datum(outputs, policy_id, local_key)

    and {
      check_init_oracle_tick(oracle_tick, tick_offset),
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

  fn spend(_oracle_tick: OracleTickDatum, _r: Data, _ctx: ScriptContext) -> Bool {
    False
  }
}

fn check_init_oracle_tick(datum: OracleTickDatum, tick_offset: Int) -> Bool {
  let size = datum.max_tick - datum.min_tick
  and {
    size == consts.get_tick_size(),
    datum.step > 0,
    datum.min_tick == tick_offset,
    datum.min_tick % size == 0,
    datum.min_tick >= consts.get_min_tick(),
    datum.max_tick <= consts.get_max_tick(),
    fullmath.check_mul_div(
      datum.max_sqrt_price_x64 - datum.min_sqrt_price_x64,
      size,
      datum.step,
    ),
  }
}
// test test_check_init_oracle_tick_1() {
//   let datum =
//     TickSqrtPriceX64 {
//       min_tick: 88000,
//       max_tick: 88100,
//       min_sqrt_price_x64: #"ae7933995305d000000000000000000000000000",
//       max_sqrt_price_x64: #"b76a0ff4b72ab800000000000000000000000000",
//       size: 100,
//       step: #"16e37bcb3dcf1eb851eb851eb851eb851eb851",
//       remainder: #"5c",
//     }
//   check_init_oracle_tick(datum, datum)
// }

// test test_check_init_oracle_tick_2() {
//   let datum =
//     TickSqrtPriceX64 {
//       min_tick: -88000,
//       max_tick: -87900,
//       min_sqrt_price_x64: #"01779f236a",
//       max_sqrt_price_x64: #"018adecc1a",
//       size: 100,
//       step: #"3146ce",
//       remainder: #"38",
//     }
//   check_init_oracle_tick(datum, datum)
// }
