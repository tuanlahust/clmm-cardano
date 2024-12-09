import { Blockfrost, Data, Lucid, Script, TxHash } from "lucid-cardano";
import alice from "../accounts/alice.json" with { type: "json" };
import {
  GlobalMemoryValidatorSpend,
  OracleTickValidatorMint,
  OracleTickValidatorSpend,
} from "../plutus.ts";
import {
  appendMintGlobalMemory,
  getSqrtRatioAtTick,
  hash,
  sitoa,
} from "./utils.ts";

declare global {
  interface BigInt {
    toJSON(): Number;
  }
}
BigInt.prototype.toJSON = function () {
  return Number(this);
};
function bigintReplacer(key: string, value: any) {
  return typeof key === 'bigint' ? value.toString() : value;
}

const lucid = await Lucid.new(
  new Blockfrost(
    "https://cardano-preprod.blockfrost.io/api/v0",
    "preprod11lyjeIE3zO12zCYyyNJ5zzLptMsbMwu"
  ),
  "Preprod"
);

lucid.selectWalletFromSeed(alice.seed);
console.log("@@@ Wallet address =", await lucid.wallet.address());

const globalMemoryValidator = new GlobalMemoryValidatorSpend();
const globalMemoryPolicyId = lucid.utils.mintingPolicyToId(
  globalMemoryValidator
);

const oracleTickValidator = new OracleTickValidatorSpend(globalMemoryPolicyId);

const size = 100n;
const minTick = 87100n;
const maxTick = minTick + size;
const minSqrtPriceX64 = getSqrtRatioAtTick(minTick);
const maxSqrtPriceX64 = getSqrtRatioAtTick(maxTick);
const step = (maxSqrtPriceX64 - minSqrtPriceX64) / BigInt(size);

const oracleTickDatum: OracleTickValidatorSpend["_oracleTick"] = {
  minTick,
  maxTick,
  minSqrtPriceX64,
  maxSqrtPriceX64,
  step,
};

console.log(`@@@ oracleTickDatum = ${JSON.stringify(oracleTickDatum, bigintReplacer)}`);

const txHash = await mint(oracleTickValidator);

await lucid.awaitTx(txHash);
console.log("@@@ Mint pool tx hash =", txHash);

async function mint(oracleTickValidator: Script): Promise<TxHash> {
  const oracleTickAddress = lucid.utils.validatorToAddress(oracleTickValidator);
  const oracleTickPolicyId = lucid.utils.mintingPolicyToId(oracleTickValidator);

  const localKey = sitoa(oracleTickDatum.minTick);
  console.log(`@@@ localKey = ${localKey}`);
  const leafAssetName = hash(hash(localKey));
  const globalKey = oracleTickPolicyId + "00" + leafAssetName;

  const txBuilder = await lucid
    .newTx()
    .attachMintingPolicy(oracleTickValidator);

  //Mint Pool
  txBuilder
    .mintAssets(
      { [`${oracleTickPolicyId}${leafAssetName}`]: 1n },
      Data.to(minTick, OracleTickValidatorMint.tickOffset)
    )
    .payToAddressWithData(
      oracleTickAddress,
      {
        inline: Data.to(oracleTickDatum, OracleTickValidatorSpend._oracleTick),
      },
      {
        [`${oracleTickPolicyId}${leafAssetName}`]: 1n,
      }
    );

  //Mint global memory
  await appendMintGlobalMemory(lucid, txBuilder, globalKey);

  const tx = await txBuilder.complete();
  const signedTx = await tx.sign().complete();
  return signedTx.submit();
}
