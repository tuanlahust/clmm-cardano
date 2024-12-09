use aiken/hash.{Blake2b_224, Hash}
use aiken/transaction/credential.{VerificationKey}
use aiken/transaction/value.{AssetName, PolicyId}
use types.{PoolId, Token}
use utils

pub fn get_pool_key(pool_id: PoolId) -> ByteArray {
  pool_id
}

pub fn get_token_key(token0: Token, token1: Token, fee: Int) -> ByteArray {
  utils.hash(
    utils.join([utils.t2t(token0), utils.t2t(token1), utils.itoa(fee)]),
  )
}

pub fn get_oracle_tick_key(tick_offset: Int) -> ByteArray {
  utils.itoa(tick_offset)
}

pub fn get_tick_key(pool_policy_id: PolicyId, tick: Int) -> ByteArray {
  utils.join([pool_policy_id, utils.itoa(tick)])
}

pub fn get_position_key(
  pool_policy_id: PolicyId,
  owner: Hash<Blake2b_224, VerificationKey>,
  tick_lower: Int,
  tick_upper: Int,
) -> ByteArray {
  utils.join(
    [pool_policy_id, owner, utils.itoa(tick_lower), utils.itoa(tick_upper)],
  )
}

pub fn get_global_key(policy_id: PolicyId, asset_name: AssetName) -> ByteArray {
  utils.join([policy_id, asset_name])
}
