import { Assets, Data, Script, TxHash } from "lucid-cardano";
import {
  PoolValidatorSpend,
  PositionValidatorSpend,
  TickValidatorSpend,
} from "../plutus.ts";
import { hash } from "./utils.ts";
import {
  getPoolId,
  poolValidator,
  lucid,
  getPoolDatum,
  minTick,
  token0,
  token1,
  getOracleTickDatum,
  getPoolUTxO,
  getOracleTickUTxO,
  getPositionUTxO,
  getTickUTxO,
  tickValidator,
  positionValidator,
  getTickDatum,
} from "./configs.ts";
import {
  getAmountsForLiquidity,
  getLiquidityForAmounts,
} from "./liquidity_amounts.ts";
import { getFeeGrowthInside, updateTick } from "./tick.ts";
import { updatePosition } from "./position.ts";
import alice from "../accounts/alice.json" with { type: "json" };
import validators from "../validators.json" with { type: "json" };

declare global {
  interface BigInt {
    toJSON(): Number;
  }
}
BigInt.prototype.toJSON = function () {
  return Number(this);
};

const tickLower: bigint = 2310n;
const tickUpper: bigint = 2370n;

const poolDatum = await getPoolDatum(getPoolId());
const oracleTick = await getOracleTickDatum(tickLower);
console.log(`@@@ Pool datum before mint = ${JSON.stringify(poolDatum)}`);

const sqrtPriceX64 = poolDatum.sqrtPriceX64;
const sqrtPriceAX64 =
  oracleTick.minSqrtPriceX64 + (tickLower - minTick) * oracleTick.step;
const sqrtPriceBX64 =
  oracleTick.minSqrtPriceX64 + (tickUpper - minTick) * oracleTick.step;

const amount0 = 1000000n;
const amount1 = 10000000n;
const deltaLiquidity = getLiquidityForAmounts(
  sqrtPriceX64,
  sqrtPriceAX64,
  sqrtPriceBX64,
  amount0,
  amount1
);

poolDatum.liquidity += deltaLiquidity;
poolDatum.linked = true;

const real_amount: { amount0: bigint; amount1: bigint } =
  getAmountsForLiquidity(
    sqrtPriceX64,
    sqrtPriceAX64,
    sqrtPriceBX64,
    deltaLiquidity
  );
console.log(`@@@ Real amount = ${JSON.stringify(real_amount)}`);

// Modify position
const addressDetails = lucid.utils.getAddressDetails(alice.address);
const owner = addressDetails.paymentCredential?.hash!;

const tickLowerDatum = await updateTick(
  tickLower,
  poolDatum.tick,
  deltaLiquidity,
  poolDatum.feeGrowthGlobal_0X128,
  poolDatum.feeGrowthGlobal_1X128,
  false
);

const tickUpperDatum = await updateTick(
  tickUpper,
  poolDatum.tick,
  deltaLiquidity,
  poolDatum.feeGrowthGlobal_0X128,
  poolDatum.feeGrowthGlobal_1X128,
  true
);

tickLowerDatum.prev = -1000000n;
tickLowerDatum.next = tickUpperDatum.tick;
tickUpperDatum.prev = tickLowerDatum.tick;
tickUpperDatum.next = 1000000n;

const { feeGrowthInside0X128, feeGrowthInside1X128 } = await getFeeGrowthInside(
  tickLower,
  tickUpper,
  poolDatum.tick,
  poolDatum.feeGrowthGlobal_0X128,
  poolDatum.feeGrowthGlobal_1X128
);

const positionDatum = await updatePosition(
  owner,
  tickLower,
  tickUpper,
  deltaLiquidity,
  feeGrowthInside0X128,
  feeGrowthInside1X128
);

// Pool
const poolParams: PoolValidatorSpend["poolRedeemer"] = {
  wrapper: {
    IMint: [
      {
        tpLower: { tick: tickLower, sqrtPriceX64: sqrtPriceAX64 },
        tpUpper: { tick: tickUpper, sqrtPriceX64: sqrtPriceBX64 },
        amount0: real_amount.amount0,
        amount1: real_amount.amount1,
        liquidity: deltaLiquidity,
        feeGrowthInside: {
          feeGrowthInside_0X128: feeGrowthInside0X128,
          feeGrowthInside_1X128: feeGrowthInside1X128,
        },
      },
    ],
  },
};

console.log(`@@@ Pool params = ${JSON.stringify(poolParams)}`);

const txHash = await mint(poolValidator);

await lucid.awaitTx(txHash);
console.log("@@@ Mint pool tx hash =", txHash);

async function mint(poolValidator: Script): Promise<TxHash> {
  const poolAddress = lucid.utils.validatorToAddress(poolValidator);
  const tickAddress = lucid.utils.validatorToAddress(tickValidator);
  const positionAddress = lucid.utils.validatorToAddress(positionValidator);
  const poolPolicyId = lucid.utils.mintingPolicyToId(poolValidator);

  const localKey = getPoolId();
  const leafAssetName = hash(hash(localKey));
  const poolToken = `${poolPolicyId}${leafAssetName}`;

  const utxoPool = await getPoolUTxO(getPoolId());
  const positionUtxo = await getPositionUTxO(
    poolPolicyId,
    owner,
    tickLower,
    tickUpper
  );
  const tickLowerUtxo = await getTickUTxO(poolPolicyId, tickLower);
  const tickUpperUtxo = await getTickUTxO(poolPolicyId, tickUpper);
  const oracleTickUtxo = await getOracleTickUTxO(tickLower);

  const beforeAmount0 =
    utxoPool.assets[`${token0.policyId}${token0.assetName}`] || 0n;
  const beforeAmount1 =
    utxoPool.assets[`${token1.policyId}${token1.assetName}`] || 0n;

  const assets: Assets = {};
  assets[poolToken] = 1n;
  assets[`${token0.policyId}${token0.assetName}`] =
    beforeAmount0 + real_amount.amount0;
  assets[`${token1.policyId}${token1.assetName}`] =
    beforeAmount1 + real_amount.amount1;
  console.log(`@@@ assets = ${JSON.stringify(assets)}`);

  const positionRedeemer: PositionValidatorSpend["_r"] = {
    wrapper: undefined,
  };
  const tickLowerRedeemer: TickValidatorSpend["_r"] = {
    wrapper: undefined,
  };
  const tickUpperRedeemer: TickValidatorSpend["_r"] = {
    wrapper: undefined,
  };

  console.log(
    `@@@ Tick lower before ${JSON.stringify(await getTickDatum(poolPolicyId, tickLower))}`
  );
  console.log(`@@@ Tick lower after ${JSON.stringify(tickLowerDatum)}`);

  const txBuilder = await lucid.newTx();

  //Mint Pool
  txBuilder
    .readFrom([oracleTickUtxo])
    .attachSpendingValidator(positionValidator)
    .collectFrom(
      [positionUtxo],
      Data.to(positionRedeemer, PositionValidatorSpend._r)
    )
    .payToAddressWithData(
      positionAddress,
      { inline: Data.to(positionDatum, PositionValidatorSpend._positionDatum) },
      positionUtxo.assets
    )
    /////////////////////////////////
    .attachSpendingValidator(tickValidator)
    .collectFrom(
      [tickLowerUtxo],
      Data.to(tickLowerRedeemer, TickValidatorSpend._r)
    )
    .collectFrom(
      [tickUpperUtxo],
      Data.to(tickUpperRedeemer, TickValidatorSpend._r)
    )
    .payToAddressWithData(
      tickAddress,
      { inline: Data.to(tickLowerDatum, TickValidatorSpend._tickDatum) },
      tickLowerUtxo.assets
    )
    .payToAddressWithData(
      tickAddress,
      { inline: Data.to(tickUpperDatum, TickValidatorSpend._tickDatum) },
      tickUpperUtxo.assets
    )
    /////////////////////////////////
    // .attachSpendingValidator(poolValidator)
    .readFrom(
      await lucid.utxosByOutRef([{ txHash: validators.pool, outputIndex: 0 }])
    )
    .collectFrom(
      [utxoPool],
      Data.to(poolParams, PoolValidatorSpend.poolRedeemer)
    )
    .payToAddressWithData(
      poolAddress,
      {
        inline: Data.to(poolDatum, PoolValidatorSpend.poolDatum),
      },
      assets
    )
    .addSigner(await lucid.wallet.address());

  const tx = await txBuilder.complete();
  const signedTx = await tx.sign().complete();
  return signedTx.submit();
}
