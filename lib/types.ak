use aiken/hash.{Blake2b_224, Hash}
use aiken/transaction/credential.{VerificationKey}
use aiken/transaction/value.{AssetName, PolicyId}

pub type NameNode =
  ByteArray

pub type PoolId =
  ByteArray

pub type DataNode {
  name: NameNode,
  bitmap: ByteArray,
}

pub type Token {
  policy_id: PolicyId,
  asset_name: AssetName,
}

pub type PoolDatum {
  tick_policy_id: PolicyId,
  position_policy_id: PolicyId,
  token0: Token,
  token1: Token,
  fee: Int,
  linked: Bool,
  tick_spacing: Int,
  tick: Int,
  sqrt_price_x64: Int,
  liquidity: Int,
  fee_growth_global_0_x128: Int,
  fee_growth_global_1_x128: Int,
  initialized: Bool,
}

pub type TickDatum {
  pool_policy_id: PolicyId,
  tick: Int,
  prev: Int,
  next: Int,
  liquidity_gross: Int,
  liquidity_net: Int,
  fee_growth_outside_0_x128: Int,
  fee_growth_outside_1_x128: Int,
  initialized: Bool,
}

pub type PositionDatum {
  pool_policy_id: PolicyId,
  owner: Hash<Blake2b_224, VerificationKey>,
  tick_lower: Int,
  tick_upper: Int,
  liquidity: Int,
  fee_growth_inside_0_last_x128: Int,
  fee_growth_inside_1_last_x128: Int,
  tokens_owed_0: Int,
  tokens_owed_1: Int,
}

pub type TickPrice {
  tick: Int,
  sqrt_price_x64: Int,
}

pub type OracleTickDatum {
  min_tick: Int,
  max_tick: Int,
  min_sqrt_price_x64: Int,
  max_sqrt_price_x64: Int,
  step: Int,
}

pub type PoolAction {
  Initialize(TickPrice)
  IMint(MintRequest)
  ICollect(CollectRequest)
  ISwap
}

pub type FeeGrowthInside {
  fee_growth_inside_0_x128: Int,
  fee_growth_inside_1_x128: Int,
}

pub type MintRequest {
  tp_lower: TickPrice,
  tp_upper: TickPrice,
  amount0: Int,
  amount1: Int,
  liquidity: Int,
  fee_growth_inside: FeeGrowthInside,
}

pub type CollectRequest {
  tick_lower: Int,
  tick_upper: Int,
  amount0: Int,
  amount1: Int,
}
