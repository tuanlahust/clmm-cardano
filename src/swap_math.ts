import {
  getAmount0ForLiquidity,
  getAmount1ForLiquidity,
  getNextSqrtPriceFromInput,
} from "./liquidity_amounts";
import { getSqrtRatioAtTickStep, getTickAtSqrtRatio } from "./utils";

const FEE: bigint = 1_000_000n;

export function computeSwapStep(
  sqrtRatioCurrentX64: bigint,
  sqrtRatioTargetX64: bigint,
  liquidity: bigint,
  amountRemaining: bigint,
  fee: bigint
): {
  sqrtRatioNextX64: bigint;
  amountIn: bigint;
  amountOut: bigint;
  feeAmount: bigint;
} {
  const zeroForOne: boolean = sqrtRatioCurrentX64 >= sqrtRatioTargetX64;
  //require sqrtRatioCurrentX64 > 0, sqrtRatioTargetX64 > 0, liquidity > 0, amountRemaining > 0, fee > 0

  const amountRemainingLessFee = (amountRemaining * (FEE - fee)) / FEE;
  let amountIn = zeroForOne
    ? getAmount0ForLiquidity(sqrtRatioTargetX64, sqrtRatioCurrentX64, liquidity)
    : getAmount1ForLiquidity(
        sqrtRatioCurrentX64,
        sqrtRatioTargetX64,
        liquidity
      );

  let sqrtRatioNextX64;
  if (amountRemainingLessFee >= amountIn) {
    sqrtRatioNextX64 = sqrtRatioTargetX64;
  } else {
    sqrtRatioNextX64 = getNextSqrtPriceFromInput(
      sqrtRatioCurrentX64,
      liquidity,
      amountRemainingLessFee,
      zeroForOne
    );
  }

  let amountOut;
  const max = sqrtRatioTargetX64 == sqrtRatioNextX64;
  if (zeroForOne) {
    amountIn = max
      ? amountIn
      : getAmount0ForLiquidity(
          sqrtRatioNextX64,
          sqrtRatioCurrentX64,
          liquidity
        );
    amountOut = getAmount1ForLiquidity(
      sqrtRatioNextX64,
      sqrtRatioCurrentX64,
      liquidity
    );
  } else {
    amountIn = max
      ? amountIn
      : getAmount1ForLiquidity(
          sqrtRatioCurrentX64,
          sqrtRatioNextX64,
          liquidity
        );
    amountOut = getAmount0ForLiquidity(
      sqrtRatioCurrentX64,
      sqrtRatioNextX64,
      liquidity
    );
  }

  let feeAmount;
  if (sqrtRatioNextX64 != sqrtRatioTargetX64) {
    feeAmount = amountRemaining - amountIn;
  } else {
    feeAmount = (amountIn * FEE) / (FEE - fee);
  }

  return {
    sqrtRatioNextX64,
    amountIn,
    amountOut,
    feeAmount,
  };
}

export function swap(
  sqrtPriceX96: bigint,
  tick: bigint,
  liquidity: bigint,
  zeroForOne: boolean,
  amountSpecified: bigint,
  fee: bigint
) {
  let amountCalculated: bigint = 0n;
  let feeGrowthGlobalX128: bigint = 0n;
  while (amountSpecified > 0) {
    const tickNext = tick + 1n; // Find tick next use linked list
    const sqrtRatioTargetX64 = getSqrtRatioAtTickStep(tickNext);
    const { sqrtRatioNextX64, amountIn, amountOut, feeAmount } =
      computeSwapStep(
        sqrtPriceX96,
        sqrtRatioTargetX64,
        liquidity,
        amountSpecified,
        fee
      );

    amountSpecified -= amountIn + feeAmount;
    amountCalculated -= amountOut;

    feeGrowthGlobalX128 += (feeAmount * 2n ** 128n) / liquidity;
    if (sqrtPriceX96 == sqrtRatioNextX64) {
      let liquidityNet = 0n; //cross
      if (zeroForOne) {
        liquidityNet = 0n - liquidityNet;
      }
      liquidity += liquidityNet;
    } else {
      tick = getTickAtSqrtRatio(sqrtPriceX96);
    }
  }
}
