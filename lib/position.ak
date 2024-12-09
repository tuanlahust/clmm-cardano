use aiken/math
use fullmath
use types.{PositionDatum}

pub fn update(
  before_position: PositionDatum,
  after_position: PositionDatum,
  liquidity: Int,
  fee_growth_inside_0_x128: Int,
  fee_growth_inside_1_x128: Int,
) -> Bool {
  expect fee_growth_inside_0_x128 >= 0 && fee_growth_inside_1_x128 >= 0

  let tokens_owed_0 =
    after_position.tokens_owed_0 - before_position.tokens_owed_0
  let tokens_owed_1 =
    after_position.tokens_owed_1 - before_position.tokens_owed_1

  and {
    after_position.liquidity == before_position.liquidity + liquidity,
    after_position.fee_growth_inside_0_last_x128 == fee_growth_inside_0_x128,
    after_position.fee_growth_inside_1_last_x128 == fee_growth_inside_1_x128,
    fullmath.check_mul_div(
      (
        fee_growth_inside_0_x128 - before_position.fee_growth_inside_0_last_x128
      ) * before_position.liquidity,
      math.pow2(128),
      tokens_owed_0,
    ),
    fullmath.check_mul_div(
      (
        fee_growth_inside_1_x128 - before_position.fee_growth_inside_1_last_x128
      ) * before_position.liquidity,
      math.pow2(128),
      tokens_owed_1,
    ),
  }
}
