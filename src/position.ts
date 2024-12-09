import { PositionValidatorSpend } from "../plutus.ts";
import { getPositionDatum, poolPolicyId } from "./configs.ts";

export async function updatePosition(
  owner: string,
  tickLower: bigint,
  tickUpper: bigint,
  liquidityDelta: bigint,
  feeGrowthInside0X128: bigint,
  feeGrowthInside1X128: bigint
): Promise<PositionValidatorSpend["_positionDatum"]> {
  const self = await getPositionDatum(
    poolPolicyId,
    owner,
    tickLower,
    tickUpper
  );

  let liquidityNext;
  if (liquidityDelta == 0n) {
    liquidityNext = self.liquidity;
  } else {
    liquidityNext = self.liquidity + liquidityDelta;
  }

  const tokensOwed0 =
    ((feeGrowthInside0X128 - self.feeGrowthInside_0LastX128) * self.liquidity) /
    2n ** 128n;
  const tokensOwed1 =
    ((feeGrowthInside1X128 - self.feeGrowthInside_1LastX128) * self.liquidity) /
    2n ** 128n;

  if (liquidityDelta != 0n) {
    self.liquidity = liquidityNext;
  }

  self.feeGrowthInside_0LastX128 = feeGrowthInside0X128;
  self.feeGrowthInside_1LastX128 = feeGrowthInside1X128;

  if (tokensOwed0 > 0 || tokensOwed1 > 0) {
    self.tokensOwed_0 += tokensOwed0;
    self.tokensOwed_1 += tokensOwed1;
  }

  return self;
}
