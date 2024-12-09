use consts
use types.{OracleTickDatum, TickPrice}

fn get_sqrt_ratio_at_tick(
  tick: Int,
  oracle_tick: OracleTickDatum,
) -> Option<Int> {
  if tick < oracle_tick.min_tick || tick >= oracle_tick.max_tick {
    None
  } else {
    Some(
      oracle_tick.min_sqrt_price_x64 + ( tick - oracle_tick.min_tick ) * oracle_tick.step,
    )
  }
}

pub fn check_tick_sqrt_price_x64(
  tick_price: TickPrice,
  oracle_tick: OracleTickDatum,
) -> Bool {
  let sqrt_ratio = get_sqrt_ratio_at_tick(tick_price.tick, oracle_tick)
  when sqrt_ratio is {
    None -> False
    Some(s) -> s == tick_price.sqrt_price_x64
  }
}

pub fn get_tick_offset(tick: Int) -> Int {
  if tick < consts.get_min_tick() {
    consts.get_min_tick()
  } else if tick > consts.get_max_tick() {
    consts.get_max_tick()
  } else {
    tick / consts.get_tick_size() * consts.get_tick_size()
  }
}

test test_get_tick_offset_1() {
  get_tick_offset(0) == 0
}

test test_get_tick_offset_2() {
  get_tick_offset(99) == 0
}

test test_get_tick_offset_3() {
  get_tick_offset(101) == 100
}

test test_get_tick_offset_4() {
  get_tick_offset(-9) == -100
}

test test_get_tick_offset_5() {
  get_tick_offset(-101) == -200
}
