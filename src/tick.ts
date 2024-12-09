import { TickValidatorSpend } from "../plutus.ts";
import { getTickDatum, poolPolicyId } from "./configs.ts";

export async function updateTick(
  tick: bigint,
  tickCurrent: bigint,
  liquidityDelta: bigint,
  feeGrowthGlobal0X128: bigint,
  feeGrowthGlobal1X128: bigint,
  isUpper: boolean
): Promise<TickValidatorSpend["_tickDatum"]> {
  const info = await getTickDatum(poolPolicyId, tick);

  const liquidityGrossBefore = info.liquidityGross;
  const liquidityGrossAfter = liquidityGrossBefore + liquidityDelta;

  if (liquidityGrossBefore == 0n) {
    if (tick <= tickCurrent) {
      info.feeGrowthOutside_0X128 = feeGrowthGlobal0X128;
      info.feeGrowthOutside_1X128 = feeGrowthGlobal1X128;
    }
    info.initialized = true;
  }

  info.liquidityGross = liquidityGrossAfter;
  info.liquidityNet = isUpper
    ? info.liquidityNet - liquidityDelta
    : info.liquidityNet + liquidityDelta;

  return info;
}

export async function getFeeGrowthInside(
  tickLower: bigint,
  tickUpper: bigint,
  tickCurrent: bigint,
  feeGrowthGlobal0X128: bigint,
  feeGrowthGlobal1X128: bigint
): Promise<{ feeGrowthInside0X128: bigint; feeGrowthInside1X128: bigint }> {
  const lower = await getTickDatum(poolPolicyId, tickLower);
  const upper = await getTickDatum(poolPolicyId, tickUpper);

  let feeGrowthBelow0X128: bigint;
  let feeGrowthBelow1X128: bigint;
  if (tickCurrent >= tickLower) {
    feeGrowthBelow0X128 = lower.feeGrowthOutside_0X128;
    feeGrowthBelow1X128 = lower.feeGrowthOutside_1X128;
  } else {
    feeGrowthBelow0X128 = feeGrowthGlobal0X128 - lower.feeGrowthOutside_0X128;
    feeGrowthBelow1X128 = feeGrowthGlobal1X128 - lower.feeGrowthOutside_1X128;
  }

  let feeGrowthAbove0X128: bigint;
  let feeGrowthAbove1X128: bigint;
  if (tickCurrent < tickUpper) {
    feeGrowthAbove0X128 = upper.feeGrowthOutside_0X128;
    feeGrowthAbove1X128 = upper.feeGrowthOutside_1X128;
  } else {
    feeGrowthAbove0X128 = feeGrowthGlobal0X128 - upper.feeGrowthOutside_0X128;
    feeGrowthAbove1X128 = feeGrowthGlobal1X128 - upper.feeGrowthOutside_1X128;
  }

  return {
    feeGrowthInside0X128:
      feeGrowthGlobal0X128 - feeGrowthBelow0X128 - feeGrowthAbove0X128,
    feeGrowthInside1X128:
      feeGrowthGlobal1X128 - feeGrowthBelow1X128 - feeGrowthAbove1X128,
  };
}
