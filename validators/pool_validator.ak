use aiken/bytearray
use aiken/dict
use aiken/hash.{Blake2b_224, Hash}
use aiken/transaction.{Input, Mint, Output, ScriptContext, Spend, Transaction}
use aiken/transaction/credential.{VerificationKey}
use aiken/transaction/value.{PolicyId, Value}
use consts
use global_memory
use keys
use liquidity_amounts
use position
use tick
use tick_math
use types.{
  CollectRequest, FeeGrowthInside, ICollect, IMint, ISwap, Initialize,
  MintRequest, PoolAction, PoolDatum, PoolId, PositionDatum, TickDatum,
  TickPrice, Token,
}
use utils

type PoolMint {
  token0: Token,
  token1: Token,
  fee: Int,
}

validator(
  global_policy_id: PolicyId,
  tick_policy_id: PolicyId,
  position_policy_id: PolicyId,
  oracle_tick_policy_id: PolicyId,
  pool_id: PoolId,
) {
  fn mint(pool_mint: PoolMint, ctx: ScriptContext) -> Bool {
    expect ScriptContext { purpose: Mint(policy_id), transaction } = ctx
    let Transaction { mint, inputs, outputs, .. } = transaction

    let mint_value: Value = value.from_minted_value(mint)
    expect [Pair(asset_name, 1)] =
      mint_value
        |> value.tokens(policy_id)
        |> dict.to_pairs

    let local_key = keys.get_pool_key(pool_id)
    let PoolMint { token0, token1, fee } = pool_mint
    let address = credential.from_script(policy_id)
    let global_key = keys.get_global_key(policy_id, asset_name)

    expect pool_datum: PoolDatum =
      utils.exact_nft_datum(outputs, policy_id, local_key)

    and {
      local_key == keys.get_token_key(token0, token1, fee),
      asset_name == utils.convert_key_to_asset(local_key),
      check_mint_pool(
        pool_datum,
        tick_policy_id,
        position_policy_id,
        token0,
        token1,
        fee,
      ),
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

  fn spend(
    pool_datum: PoolDatum,
    pool_redeemer: PoolAction,
    ctx: ScriptContext,
  ) -> Bool {
    expect ScriptContext {
      transaction: Transaction {
        outputs,
        inputs: org_inputs,
        reference_inputs: ref_inputs,
        extra_signatories,
        ..
      },
      purpose: Spend(out_ref),
    } = ctx

    let local_key = keys.get_pool_key(pool_id)
    let asset_name = utils.convert_key_to_asset(local_key)
    let policy_id = utils.get_policy_from_spend(org_inputs, out_ref)
    let address = credential.from_script(policy_id)
    let inputs = utils.i2o(org_inputs)

    expect [owner] = extra_signatories
    expect after_pool: PoolDatum =
      utils.exact_nft_datum(outputs, policy_id, local_key)
    expect Some(before_value) =
      utils.find_nft_value(inputs, policy_id, asset_name)
    expect Some(after_value) =
      utils.find_nft_value(outputs, policy_id, asset_name)

    let check_spend =
      when pool_redeemer is {
        //Initialize
        Initialize(tp) -> {
          let oracle_tick =
            utils.get_oracle_tick(oracle_tick_policy_id, tp.tick, ref_inputs)
          expect tick_math.check_tick_sqrt_price_x64(tp, oracle_tick)
          check_initialize_pool(pool_datum, after_pool, tp)
        }
        //Add (remove) liquidity
        IMint(req) -> and {
            check_oracle_ticks(oracle_tick_policy_id, ref_inputs, req),
            check_liquidity_amounts(
              req,
              pool_datum,
              after_pool,
              before_value,
              after_value,
            ),
            modify_position(
              owner,
              policy_id,
              tick_policy_id,
              position_policy_id,
              pool_datum,
              after_pool,
              req,
              inputs,
              outputs,
            ),
          }
        ICollect(req) ->
          check_collect(
            owner,
            req,
            policy_id,
            position_policy_id,
            pool_datum,
            before_value,
            after_value,
            inputs,
            outputs,
          )
        ISwap -> False
      }
    and {
      check_spend,
      check_pool_metadata(pool_datum, after_pool),
      utils.check_same_address(outputs, policy_id, address),
    }
  }
}

fn check_mint_pool(
  pool_datum: PoolDatum,
  tick_policy_id: PolicyId,
  position_policy_id: PolicyId,
  token0: Token,
  token1: Token,
  fee: Int,
) -> Bool {
  expect bytearray.compare(utils.t2t(token0), utils.t2t(token1)) == Less
  expect Some(tick_spacing) = utils.get_tick_spacing_by_fee(fee)
  and {
    pool_datum.tick_policy_id == tick_policy_id,
    pool_datum.position_policy_id == position_policy_id,
    pool_datum.token0 == token0,
    pool_datum.token1 == token1,
    pool_datum.fee == fee,
    pool_datum.tick_spacing == tick_spacing,
    pool_datum.liquidity == 0,
    pool_datum.sqrt_price_x64 == 0,
    pool_datum.tick == 0,
    pool_datum.fee_growth_global_0_x128 == 0,
    pool_datum.fee_growth_global_1_x128 == 0,
    pool_datum.initialized == False,
    pool_datum.linked == False,
  }
}

fn check_pool_metadata(before: PoolDatum, after: PoolDatum) -> Bool {
  and {
    before.tick_policy_id == after.tick_policy_id,
    before.position_policy_id == after.position_policy_id,
    before.token0 == after.token0,
    before.token1 == after.token1,
    before.fee == after.fee,
    before.tick_spacing == after.tick_spacing,
  }
}

// Initialize
fn check_initialize_pool(
  before: PoolDatum,
  after: PoolDatum,
  tp: TickPrice,
) -> Bool {
  and {
    before.initialized == False,
    after.initialized == True,
    after.tick == tp.tick,
    after.sqrt_price_x64 == tp.sqrt_price_x64,
    after.sqrt_price_x64 > 0,
    after.liquidity == 0,
    after.fee_growth_global_0_x128 == 0,
    after.fee_growth_global_1_x128 == 0,
  }
}

fn check_oracle_ticks(
  oracle_tick_policy_id,
  ref_inputs: List<Input>,
  req: MintRequest,
) -> Bool {
  let oracle_tick_lower =
    utils.get_oracle_tick(oracle_tick_policy_id, req.tp_lower.tick, ref_inputs)
  let oracle_tick_upper =
    utils.get_oracle_tick(oracle_tick_policy_id, req.tp_upper.tick, ref_inputs)
  and {
    req.tp_lower.tick < req.tp_upper.tick,
    req.tp_lower.tick >= consts.get_min_tick(),
    req.tp_upper.tick <= consts.get_max_tick(),
    tick_math.check_tick_sqrt_price_x64(req.tp_lower, oracle_tick_lower),
    tick_math.check_tick_sqrt_price_x64(req.tp_upper, oracle_tick_upper),
  }
}

fn check_liquidity_amounts(
  req: MintRequest,
  bf_pool: PoolDatum,
  af_pool: PoolDatum,
  bf_value: Value,
  af_value: Value,
) -> Bool {
  and {
    af_pool.liquidity == bf_pool.liquidity + req.liquidity,
    check_value(req, bf_value, af_value, bf_pool.token0, bf_pool.token1),
    liquidity_amounts.check_amount_for_liquidity(
      bf_pool.sqrt_price_x64,
      req.tp_lower.sqrt_price_x64,
      req.tp_upper.sqrt_price_x64,
      req.liquidity,
      req.amount0,
      req.amount1,
    ),
  }
}

fn check_value(
  req: MintRequest,
  bf_value: Value,
  af_value: Value,
  token0: Token,
  token1: Token,
) -> Bool {
  if is_mint(req.liquidity) {
    and {
      req.amount0 > 0,
      req.amount1 > 0,
      quantity_of(af_value, token0) == quantity_of(bf_value, token0) + req.amount0,
      quantity_of(af_value, token1) == quantity_of(bf_value, token1) + req.amount1,
    }
  } else {
    and {
      req.amount0 < 0,
      req.amount1 < 0,
      quantity_of(af_value, token0) == quantity_of(bf_value, token0),
      quantity_of(af_value, token1) == quantity_of(bf_value, token1),
    }
  }
}

fn quantity_of(v: Value, t: Token) -> Int {
  value.quantity_of(v, t.policy_id, t.asset_name)
}

fn modify_position(
  owner: Hash<Blake2b_224, VerificationKey>,
  pool_policy_id: PolicyId,
  tick_policy_id: PolicyId,
  position_policy_id: PolicyId,
  before_pool: PoolDatum,
  after_pool: PoolDatum,
  req: MintRequest,
  inputs: List<Output>,
  outputs: List<Output>,
) -> Bool {
  let position_key =
    keys.get_position_key(
      pool_policy_id,
      owner,
      req.tp_lower.tick,
      req.tp_upper.tick,
    )
  expect before_position: PositionDatum =
    utils.exact_nft_datum(inputs, position_policy_id, position_key)
  expect after_position: PositionDatum =
    utils.exact_nft_datum(outputs, position_policy_id, position_key)

  let lower_key = keys.get_tick_key(pool_policy_id, req.tp_lower.tick)
  let upper_key = keys.get_tick_key(pool_policy_id, req.tp_upper.tick)
  expect before_tick_lower: TickDatum =
    utils.exact_nft_datum(inputs, tick_policy_id, lower_key)
  expect after_tick_lower: TickDatum =
    utils.exact_nft_datum(outputs, tick_policy_id, lower_key)
  expect before_tick_upper: TickDatum =
    utils.exact_nft_datum(inputs, tick_policy_id, upper_key)
  expect after_tick_upper: TickDatum =
    utils.exact_nft_datum(outputs, tick_policy_id, upper_key)

  and {
    update_position(
      req,
      before_pool,
      before_position,
      after_position,
      before_tick_lower,
      after_tick_lower,
      before_tick_upper,
      after_tick_upper,
    ),
    check_linked_ticks(
      req,
      pool_policy_id,
      tick_policy_id,
      before_pool,
      after_pool,
      inputs,
      outputs,
    ),
  }
}

fn update_position(
  req: MintRequest,
  before_pool: PoolDatum,
  before_position: PositionDatum,
  after_position: PositionDatum,
  before_tick_lower: TickDatum,
  after_tick_lower: TickDatum,
  before_tick_upper: TickDatum,
  after_tick_upper: TickDatum,
) -> Bool {
  let check_tick_lower =
    check_tick(
      before_tick_lower,
      after_tick_lower,
      before_pool.tick,
      req.liquidity,
      before_pool.fee_growth_global_0_x128,
      before_pool.fee_growth_global_1_x128,
      False,
    )

  let check_tick_upper =
    check_tick(
      before_tick_upper,
      after_tick_upper,
      before_pool.tick,
      req.liquidity,
      before_pool.fee_growth_global_0_x128,
      before_pool.fee_growth_global_1_x128,
      True,
    )

  let check_fee_growth_inside =
    tick.check_fee_growth_inside(
      after_tick_lower,
      after_tick_upper,
      before_pool.tick,
      before_pool.fee_growth_global_0_x128,
      before_pool.fee_growth_global_1_x128,
      req.fee_growth_inside,
    )

  let check_position_update =
    position.update(
      before_position,
      after_position,
      req.liquidity,
      req.fee_growth_inside.fee_growth_inside_0_x128,
      req.fee_growth_inside.fee_growth_inside_1_x128,
    )

  and {
    check_tick_lower,
    check_tick_upper,
    check_fee_growth_inside,
    check_position_update,
    check_burn_position(req, before_position, after_position),
  }
}

fn check_tick(
  before_tick: TickDatum,
  after_tick: TickDatum,
  tick_current: Int,
  liquidity: Int,
  fee_growth_global_0_x128: Int,
  fee_growth_global_1_x128: Int,
  is_upper: Bool,
) {
  if liquidity == 0 {
    True
  } else {
    tick.update(
      before_tick,
      after_tick,
      tick_current,
      liquidity,
      fee_growth_global_0_x128,
      fee_growth_global_1_x128,
      is_upper,
    )
  }
}

fn check_burn_position(
  req: MintRequest,
  before_position: PositionDatum,
  after_position: PositionDatum,
) -> Bool {
  if is_mint(req.liquidity) {
    True
  } else {
    and {
      after_position.tokens_owed_0 == before_position.tokens_owed_0 + req.amount0,
      after_position.tokens_owed_1 == before_position.tokens_owed_1 + req.amount1,
    }
  }
}

fn is_mint(liquidity: Int) -> Bool {
  liquidity >= 0
}

fn check_collect(
  owner: Hash<Blake2b_224, VerificationKey>,
  req: CollectRequest,
  pool_policy_id: PolicyId,
  position_policy_id: PolicyId,
  bf_pool: PoolDatum,
  bf_value: Value,
  af_value: Value,
  inputs: List<Output>,
  outputs: List<Output>,
) -> Bool {
  let token0 = bf_pool.token0
  let token1 = bf_pool.token1
  let position_key =
    keys.get_position_key(pool_policy_id, owner, req.tick_lower, req.tick_upper)

  expect bf_pos: PositionDatum =
    utils.exact_nft_datum(inputs, position_policy_id, position_key)
  expect af_pos: PositionDatum =
    utils.exact_nft_datum(outputs, position_policy_id, position_key)

  and {
    req.amount0 >= 0,
    req.amount1 >= 0,
    bf_pos.tokens_owed_0 <= af_pos.tokens_owed_0,
    bf_pos.tokens_owed_1 <= af_pos.tokens_owed_1,
    af_pos.tokens_owed_0 == bf_pos.tokens_owed_0 - req.amount0,
    af_pos.tokens_owed_1 == bf_pos.tokens_owed_1 - req.amount1,
    quantity_of(af_value, token0) == quantity_of(bf_value, token0) - req.amount0,
    quantity_of(af_value, token1) == quantity_of(bf_value, token1) - req.amount1,
  }
}

fn check_linked_ticks(
  req: MintRequest,
  pool_policy_id: PolicyId,
  tick_policy_id: PolicyId,
  before_pool: PoolDatum,
  after_pool: PoolDatum,
  inputs: List<Output>,
  outputs: List<Output>,
) {
  if before_pool.linked {
    and {
      after_pool.linked,
      do_check_linked_tick(
        req.tp_lower.tick,
        pool_policy_id,
        tick_policy_id,
        inputs,
        outputs,
      ),
      do_check_linked_tick(
        req.tp_upper.tick,
        pool_policy_id,
        tick_policy_id,
        inputs,
        outputs,
      ),
    }
  } else {
    and {
      after_pool.linked,
      check_first_linked(
        req.tp_lower.tick,
        req.tp_upper.tick,
        pool_policy_id,
        tick_policy_id,
        outputs,
      ),
    }
  }
}

fn check_first_linked(
  tick_lower: Int,
  tick_upper: Int,
  pool_policy_id: PolicyId,
  tick_policy_id: PolicyId,
  outputs: List<Output>,
) -> Bool {
  let lower_key = keys.get_tick_key(pool_policy_id, tick_lower)
  let upper_key = keys.get_tick_key(pool_policy_id, tick_upper)
  expect lower: TickDatum =
    utils.exact_nft_datum(outputs, tick_policy_id, lower_key)
  expect upper: TickDatum =
    utils.exact_nft_datum(outputs, tick_policy_id, upper_key)
  and {
    tick_lower < tick_upper,
    tick.is_head(lower.prev),
    lower.next == tick_upper,
    tick.is_tail(upper.next),
    upper.prev == tick_lower,
  }
}

fn do_check_linked_tick(
  tick: Int,
  pool_policy_id: PolicyId,
  tick_policy_id: PolicyId,
  inputs: List<Output>,
  outputs: List<Output>,
) -> Bool {
  let tick_key = keys.get_tick_key(pool_policy_id, tick)
  expect before_tick: TickDatum =
    utils.exact_nft_datum(inputs, tick_policy_id, tick_key)
  expect after_tick: TickDatum =
    utils.exact_nft_datum(outputs, tick_policy_id, tick_key)

  if tick.is_initialized(before_tick, after_tick) {
    let prev_id =
      tick.find_prev_node(
        after_tick,
        pool_policy_id,
        tick_policy_id,
        inputs,
        outputs,
      )
    let next_id =
      tick.find_next_node(
        after_tick,
        pool_policy_id,
        tick_policy_id,
        inputs,
        outputs,
      )
    if tick.is_head(prev_id) {
      let head_key = keys.get_tick_key(pool_policy_id, next_id)
      expect before_head: TickDatum =
        utils.exact_nft_datum(inputs, tick_policy_id, head_key)
      tick.is_head(before_head.prev)
    } else if tick.is_tail(next_id) {
      let tail_key = keys.get_tick_key(pool_policy_id, prev_id)
      expect before_tail: TickDatum =
        utils.exact_nft_datum(inputs, tick_policy_id, tail_key)
      tick.is_tail(before_tail.next)
    } else {
      let prev_key = keys.get_tick_key(pool_policy_id, prev_id)
      let next_key = keys.get_tick_key(pool_policy_id, next_id)
      expect before_prev: TickDatum =
        utils.exact_nft_datum(inputs, tick_policy_id, prev_key)
      expect before_next: TickDatum =
        utils.exact_nft_datum(inputs, tick_policy_id, next_key)
      and {
        before_prev.next == before_next.tick,
        before_next.prev == before_prev.tick,
      }
    }
  } else {
    True
  }
}
