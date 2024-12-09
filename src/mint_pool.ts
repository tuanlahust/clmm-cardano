import { Blockfrost, Data, Lucid, Script, TxHash } from "lucid-cardano";
import alice from "../accounts/alice.json" with { type: "json" };
import { PoolValidatorMint, PoolValidatorSpend } from "../plutus.ts";
import { appendMintGlobalMemory, hash } from "./utils.ts";
import {
  fee,
  tickSpacing,
  positionPolicyId,
  tickPolicyId,
  poolValidator,
  getPoolId,
  token0,
  token1,
} from "./configs.ts";

declare global {
  interface BigInt {
    toJSON(): Number;
  }
}
BigInt.prototype.toJSON = function () {
  return Number(this);
};

const lucid = await Lucid.new(
  new Blockfrost(
    "https://cardano-preprod.blockfrost.io/api/v0",
    "preprod11lyjeIE3zO12zCYyyNJ5zzLptMsbMwu"
  ),
  "Preprod"
);

lucid.selectWalletFromSeed(alice.seed);
console.log("@@@ Wallet address =", await lucid.wallet.address());

const poolDatum: PoolValidatorSpend["poolDatum"] = {
  tickPolicyId,
  positionPolicyId,
  token0,
  token1,
  fee,
  linked: false,
  tickSpacing,
  liquidity: 0n,
  sqrtPriceX64: 0n,
  tick: 0n,
  feeGrowthGlobal_0X128: 0n,
  feeGrowthGlobal_1X128: 0n,
  initialized: false,
};

const poolMint: PoolValidatorMint["poolMint"] = {
  token0,
  token1,
  fee,
};

const txHash = await mint(poolValidator);

await lucid.awaitTx(txHash);
console.log("@@@ Mint pool tx hash =", txHash);

async function mint(poolValidator: Script): Promise<TxHash> {
  const poolAddress = lucid.utils.validatorToAddress(poolValidator);
  const poolPolicyId = lucid.utils.mintingPolicyToId(poolValidator);

  const localKey = getPoolId();
  const leafAssetName = hash(hash(localKey));
  const globalKey = poolPolicyId + "00" + leafAssetName;

  const txBuilder = await lucid.newTx().attachMintingPolicy(poolValidator);

  //Mint Pool
  txBuilder
    .mintAssets(
      { [`${poolPolicyId}${leafAssetName}`]: 1n },
      Data.to(poolMint, PoolValidatorMint.poolMint)
    )
    .payToAddressWithData(
      poolAddress,
      {
        inline: Data.to(poolDatum, PoolValidatorSpend.poolDatum),
      },
      {
        [`${poolPolicyId}${leafAssetName}`]: 1n,
      }
    );

  //Mint global memory
  await appendMintGlobalMemory(lucid, txBuilder, globalKey);

  const tx = await txBuilder.complete();
  const signedTx = await tx.sign().complete();
  return signedTx.submit();
}
