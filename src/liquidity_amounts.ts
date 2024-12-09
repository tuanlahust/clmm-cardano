export const Q64: bigint = 2n ** 64n;

export function getLiquidityForAmount0(
  sqrtRatioAX96: bigint,
  sqrtRatioBX96: bigint,
  amount0: bigint
): bigint {
  const intermediate = (sqrtRatioBX96 * sqrtRatioAX96) / Q64;
  return (amount0 * intermediate) / (sqrtRatioBX96 - sqrtRatioAX96);
}

export function getLiquidityForAmount1(
  sqrtRatioAX96: bigint,
  sqrtRatioBX96: bigint,
  amount1: bigint
): bigint {
  return (amount1 * Q64) / (sqrtRatioBX96 - sqrtRatioAX96);
}

export function getLiquidityForAmounts(
  sqrtRatioX96: bigint,
  sqrtRatioAX96: bigint,
  sqrtRatioBX96: bigint,
  amount0: bigint,
  amount1: bigint
): bigint {
  if (sqrtRatioX96 <= sqrtRatioAX96) {
    return getLiquidityForAmount0(sqrtRatioAX96, sqrtRatioBX96, amount0);
  } else if (sqrtRatioX96 < sqrtRatioBX96) {
    const liquidity0: bigint = getLiquidityForAmount0(
      sqrtRatioX96,
      sqrtRatioBX96,
      amount0
    );
    const liquidity1: bigint = getLiquidityForAmount1(
      sqrtRatioAX96,
      sqrtRatioX96,
      amount1
    );
    return liquidity0 < liquidity1 ? liquidity0 : liquidity1;
  } else {
    return getLiquidityForAmount1(sqrtRatioAX96, sqrtRatioBX96, amount1);
  }
}

export function getAmount0ForLiquidity(
  sqrtRatioAX96: bigint,
  sqrtRatioBX96: bigint,
  liquidity: bigint
): bigint {
  const numerator1 = liquidity * Q64;
  const numerator2 =
    sqrtRatioBX96 > sqrtRatioAX96
      ? sqrtRatioBX96 - sqrtRatioAX96
      : sqrtRatioAX96 - sqrtRatioBX96;
  return (numerator1 * numerator2) / (sqrtRatioBX96 * sqrtRatioAX96);
}

export function getAmount1ForLiquidity(
  sqrtRatioAX96: bigint,
  sqrtRatioBX96: bigint,
  liquidity: bigint
): bigint {
  const numerator =
    sqrtRatioBX96 > sqrtRatioAX96
      ? sqrtRatioBX96 - sqrtRatioAX96
      : sqrtRatioAX96 - sqrtRatioBX96;
  return (liquidity * numerator) / Q64;
}

export function getAmountsForLiquidity(
  sqrtRatioX96: bigint,
  sqrtRatioAX96: bigint,
  sqrtRatioBX96: bigint,
  liquidity: bigint
): { amount0: bigint; amount1: bigint } {
  let amount0: bigint = 0n;
  let amount1: bigint = 0n;
  if (sqrtRatioX96 <= sqrtRatioAX96) {
    amount0 = getAmount0ForLiquidity(sqrtRatioAX96, sqrtRatioBX96, liquidity);
  } else if (sqrtRatioX96 < sqrtRatioBX96) {
    amount0 = getAmount0ForLiquidity(sqrtRatioX96, sqrtRatioBX96, liquidity);
    amount1 = getAmount1ForLiquidity(sqrtRatioAX96, sqrtRatioX96, liquidity);
  } else {
    amount1 = getAmount1ForLiquidity(sqrtRatioAX96, sqrtRatioBX96, liquidity);
  }
  return { amount0, amount1 };
}

export function getNextSqrtPriceFromInput(
  sqrtPX64: bigint,
  liquidity: bigint,
  amountIn: bigint,
  zeroForOne: boolean
): bigint {
  return zeroForOne
    ? getNextSqrtPriceFromAmount0(sqrtPX64, liquidity, amountIn)
    : getNextSqrtPriceFromAmount1(sqrtPX64, liquidity, amountIn);
}

function getNextSqrtPriceFromAmount0(
  sqrtPX64: bigint,
  liquidity: bigint,
  amount: bigint
): bigint {
  if (amount == 0n) {
    return sqrtPX64;
  }
  const numerator1 = liquidity * Q64;
  const product = amount * sqrtPX64;
  const denominator = numerator1 + product;
  if (product / amount == sqrtPX64 && denominator >= numerator1) {
    return (numerator1 * sqrtPX64) / denominator;
  } else {
    return numerator1 * (numerator1 / sqrtPX64 + amount);
  }
}

function getNextSqrtPriceFromAmount1(
  sqrtPX64: bigint,
  liquidity: bigint,
  amount: bigint
): bigint {
  const qoutient = (amount * Q64) / liquidity;
  return sqrtPX64 + qoutient;
}
