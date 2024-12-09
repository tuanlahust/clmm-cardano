use aiken/math
use fullmath

fn check_amount0_for_liquidity(
  sqrt_price_a_x64: Int,
  sqrt_price_b_x64: Int,
  liquidity: Int,
  amount0: Int,
) -> Bool {
  expect liquidity > 0
  expect sqrt_price_a_x64 > 0 && sqrt_price_a_x64 < sqrt_price_b_x64
  fullmath.check_mul_div(
    liquidity * math.pow2(64) * ( sqrt_price_b_x64 - sqrt_price_a_x64 ),
    sqrt_price_a_x64 * sqrt_price_b_x64,
    amount0,
  )
}

fn check_amount1_for_liquidity(
  sqrt_price_a_x64: Int,
  sqrt_price_b_x64: Int,
  liquidity: Int,
  amount1: Int,
) -> Bool {
  expect liquidity > 0
  expect sqrt_price_a_x64 > 0 && sqrt_price_a_x64 < sqrt_price_b_x64
  fullmath.check_mul_div(
    liquidity * ( sqrt_price_b_x64 - sqrt_price_a_x64 ),
    math.pow2(64),
    amount1,
  )
}

pub fn check_amount_for_liquidity(
  sqrt_ratio_x64: Int,
  sqrt_ratio_a_x64: Int,
  sqrt_ratio_b_x64: Int,
  liquidity: Int,
  amount0: Int,
  amount1: Int,
) -> Bool {
  expect liquidity > 0
  expect sqrt_ratio_a_x64 > 0 && sqrt_ratio_a_x64 < sqrt_ratio_b_x64
  if sqrt_ratio_x64 <= sqrt_ratio_a_x64 {
    and {
      check_amount0_for_liquidity(
        sqrt_ratio_a_x64,
        sqrt_ratio_b_x64,
        liquidity,
        amount0,
      ),
      amount1 == 0,
    }
  } else if sqrt_ratio_x64 < sqrt_ratio_b_x64 {
    and {
      check_amount0_for_liquidity(
        sqrt_ratio_x64,
        sqrt_ratio_b_x64,
        liquidity,
        amount0,
      ),
      check_amount1_for_liquidity(
        sqrt_ratio_a_x64,
        sqrt_ratio_x64,
        liquidity,
        amount1,
      ),
    }
  } else {
    and {
      amount0 == 0,
      check_amount1_for_liquidity(
        sqrt_ratio_a_x64,
        sqrt_ratio_b_x64,
        liquidity,
        amount1,
      ),
    }
  }
}

test test_check_amount_for_liquidity_1() {
  let sqrt_ratio_x64 = 59418400002420440000
  let sqrt_price_a_x64 = 58523282279998970000
  let sqrt_price_b_x64 = 60313517724841910000
  let liquidity = 206081765
  let amount0 = 949519
  let amount1 = 9999999
  check_amount_for_liquidity(
    sqrt_ratio_x64,
    sqrt_price_a_x64,
    sqrt_price_b_x64,
    liquidity,
    amount0,
    amount1,
  )
}
