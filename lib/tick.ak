use aiken/transaction.{Output}
use aiken/transaction/value.{PolicyId}
use keys
use types.{FeeGrowthInside, TickDatum}
use utils

type FeeX128 {
  fee_0_x128: Int,
  fee_1_x128: Int,
}

pub fn check_fee_growth_inside(
  tick_lower: TickDatum,
  tick_upper: TickDatum,
  tick_current: Int,
  fee_growth_global_0_x128: Int,
  fee_growth_global_1_x128: Int,
  fee_growth_inside: FeeGrowthInside,
) -> Bool {
  expect fee_growth_global_0_x128 >= 0 && fee_growth_global_1_x128 >= 0

  let FeeX128 {
    fee_0_x128: fee_growth_below_0_x128,
    fee_1_x128: fee_growth_below_1_x128,
  } =
    get_fee_growth_below(
      tick_lower,
      tick_current,
      fee_growth_global_0_x128,
      fee_growth_global_1_x128,
    )

  let FeeX128 {
    fee_0_x128: fee_growth_above_0_x128,
    fee_1_x128: fee_growth_above_1_x128,
  } =
    get_fee_growth_above(
      tick_upper,
      tick_current,
      fee_growth_global_0_x128,
      fee_growth_global_1_x128,
    )

  and {
    fee_growth_inside.fee_growth_inside_0_x128 == fee_growth_global_0_x128 - fee_growth_below_0_x128 - fee_growth_above_0_x128,
    fee_growth_inside.fee_growth_inside_1_x128 == fee_growth_global_1_x128 - fee_growth_below_1_x128 - fee_growth_above_1_x128,
  }
}

fn get_fee_growth_below(
  tick_lower: TickDatum,
  tick_current: Int,
  fee_growth_global_0_x128: Int,
  fee_growth_global_1_x128: Int,
) -> FeeX128 {
  if tick_current >= tick_lower.tick {
    FeeX128 {
      fee_0_x128: tick_lower.fee_growth_outside_0_x128,
      fee_1_x128: tick_lower.fee_growth_outside_1_x128,
    }
  } else {
    FeeX128 {
      fee_0_x128: fee_growth_global_0_x128 - tick_lower.fee_growth_outside_0_x128,
      fee_1_x128: fee_growth_global_1_x128 - tick_lower.fee_growth_outside_1_x128,
    }
  }
}

fn get_fee_growth_above(
  tick_upper: TickDatum,
  tick_current: Int,
  fee_growth_global_0_x128: Int,
  fee_growth_global_1_x128: Int,
) -> FeeX128 {
  if tick_current < tick_upper.tick {
    FeeX128 {
      fee_0_x128: tick_upper.fee_growth_outside_0_x128,
      fee_1_x128: tick_upper.fee_growth_outside_1_x128,
    }
  } else {
    FeeX128 {
      fee_0_x128: fee_growth_global_0_x128 - tick_upper.fee_growth_outside_0_x128,
      fee_1_x128: fee_growth_global_1_x128 - tick_upper.fee_growth_outside_1_x128,
    }
  }
}

pub fn update(
  before_tick: TickDatum,
  after_tick: TickDatum,
  tick_current: Int,
  liquidity: Int,
  fee_growth_global_0_x128: Int,
  fee_growth_global_1_x128: Int,
  is_upper: Bool,
) -> Bool {
  let check_initialized =
    check_initialize_tick(
      before_tick,
      after_tick,
      tick_current,
      fee_growth_global_0_x128,
      fee_growth_global_1_x128,
    )

  let check_liquidity_gross =
    after_tick.liquidity_gross == before_tick.liquidity_gross + liquidity

  let check_liquidity_net =
    when is_upper is {
      True -> after_tick.liquidity_net == before_tick.liquidity_net - liquidity
      False -> after_tick.liquidity_net == before_tick.liquidity_net + liquidity
    }

  and {
    check_initialized,
    check_liquidity_gross,
    check_liquidity_net,
  }
}

fn check_initialize_tick(
  before_tick: TickDatum,
  after_tick: TickDatum,
  tick_current: Int,
  fee_growth_global_0_x128: Int,
  fee_growth_global_1_x128: Int,
) -> Bool {
  if before_tick.liquidity_gross == 0 && !before_tick.initialized {
    if before_tick.tick <= tick_current {
      and {
        after_tick.fee_growth_outside_0_x128 == fee_growth_global_0_x128,
        after_tick.fee_growth_outside_1_x128 == fee_growth_global_1_x128,
        after_tick.initialized == True,
      }
    } else {
      after_tick.initialized == True
    }
  } else {
    True
  }
}

pub fn is_initialized(bf: TickDatum, af: TickDatum) -> Bool {
  !bf.initialized && af.initialized
}

pub fn is_head(tick: Int) -> Bool {
  tick == -1000000
}

pub fn is_tail(tick: Int) -> Bool {
  tick == 1000000
}

pub fn find_prev_node(
  tick: TickDatum,
  pool_policy_id: PolicyId,
  tick_policy_id: PolicyId,
  inputs: List<Output>,
  outputs: List<Output>,
) -> Int {
  if is_head(tick.prev) {
    tick.prev
  } else {
    let prev_key = keys.get_tick_key(pool_policy_id, tick.prev)
    expect before_prev: TickDatum =
      utils.exact_nft_datum(inputs, tick_policy_id, prev_key)
    expect after_prev: TickDatum =
      utils.exact_nft_datum(outputs, tick_policy_id, prev_key)
    expect after_prev.next == tick.tick

    if is_initialized(before_prev, after_prev) {
      find_prev_node(
        after_prev,
        pool_policy_id,
        tick_policy_id,
        inputs,
        outputs,
      )
    } else {
      tick.prev
    }
  }
}

pub fn find_next_node(
  tick: TickDatum,
  pool_policy_id: PolicyId,
  tick_policy_id: PolicyId,
  inputs: List<Output>,
  outputs: List<Output>,
) -> Int {
  if is_tail(tick.next) {
    tick.next
  } else {
    let next_key = keys.get_tick_key(pool_policy_id, tick.next)
    expect before_next: TickDatum =
      utils.exact_nft_datum(inputs, tick_policy_id, next_key)
    expect after_next: TickDatum =
      utils.exact_nft_datum(outputs, tick_policy_id, next_key)
    expect after_next.prev == tick.tick

    if is_initialized(before_next, after_next) {
      find_next_node(
        after_next,
        pool_policy_id,
        tick_policy_id,
        inputs,
        outputs,
      )
    } else {
      tick.next
    }
  }
}
