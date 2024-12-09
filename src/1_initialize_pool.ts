import { Data, Script, TxHash } from "lucid-cardano";
import { PoolValidatorSpend } from "../plutus.ts";
import { getSqrtRatioAtTickStep, hash, sitoa } from "./utils.ts";
import {
  fee,
  token0,
  token1,
  tickSpacing,
  getPoolId,
  poolValidator,
  lucid,
  tickPolicyId,
  positionPolicyId,
  minTick,
  getPoolUTxO,
  getOracleTickUTxO,
} from "./configs.ts";

declare global {
  interface BigInt {
    toJSON(): Number;
  }
}
BigInt.prototype.toJSON = function () {
  return Number(this);
};

const tick = 2340n;
const sqrtPriceX64 = getSqrtRatioAtTickStep(tick);

const poolInitializeRedeemer: PoolValidatorSpend["poolRedeemer"] = {
  wrapper: {
    Initialize: [
      {
        tick,
        sqrtPriceX64,
      },
    ],
  },
};

const poolDatum: PoolValidatorSpend["poolDatum"] = {
  tickPolicyId,
  positionPolicyId,
  token0,
  token1,
  fee,
  linked: false,
  tickSpacing,
  liquidity: 0n,
  sqrtPriceX64,
  tick,
  feeGrowthGlobal_0X128: 0n,
  feeGrowthGlobal_1X128: 0n,
  initialized: true,
};
console.log(`@@@ Pool datum before mint = ${JSON.stringify(poolDatum)}`);

const txHash = await mint(poolValidator);

await lucid.awaitTx(txHash);
console.log("@@@ Mint pool tx hash =", txHash);

async function mint(poolValidator: Script): Promise<TxHash> {
  const poolAddress = lucid.utils.validatorToAddress(poolValidator);
  const poolPolicyId = lucid.utils.mintingPolicyToId(poolValidator);

  const localKey = getPoolId();
  const leafAssetName = hash(hash(localKey));

  const txBuilder = await lucid.newTx().attachMintingPolicy(poolValidator);

  //Mint Pool
  txBuilder
    .readFrom([await getOracleTickUTxO(minTick)])
    .collectFrom(
      [await getPoolUTxO(localKey)],
      Data.to(poolInitializeRedeemer, PoolValidatorSpend.poolRedeemer)
    )
    .payToAddressWithData(
      poolAddress,
      {
        inline: Data.to(poolDatum, PoolValidatorSpend.poolDatum),
      },
      {
        [`${poolPolicyId}${leafAssetName}`]: 1n,
      }
    )
    .addSigner(await lucid.wallet.address());

  const tx = await txBuilder.complete();
  const signedTx = await tx.sign().complete();
  return signedTx.submit();
}
