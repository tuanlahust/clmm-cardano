import { Blockfrost, Data, Lucid, Script, TxHash } from "lucid-cardano";
import alice from "../accounts/alice.json" with { type: "json" };
import {
  GlobalMemoryValidatorSpend,
  OracleTickValidatorMint,
  PoolValidatorMint,
  PositionValidatorSpend,
  TickValidatorMint,
  TickValidatorSpend,
} from "../plutus.ts";
import { appendMintGlobalMemory, hash, sitoa } from "./utils.ts";
import { getPoolId, tickId } from "./configs.ts";

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

const globalMemoryValidator = new GlobalMemoryValidatorSpend();
const globalMemoryPolicyId = lucid.utils.mintingPolicyToId(
  globalMemoryValidator
);

const tickValidator = new TickValidatorSpend(globalMemoryPolicyId, getPoolId());
const tickPolicyId = lucid.utils.mintingPolicyToId(tickValidator);

const positionValidator = new PositionValidatorSpend(
  globalMemoryPolicyId,
  getPoolId()
);
const positionPolicyId = lucid.utils.mintingPolicyToId(positionValidator);

const oracleTickValidator = new OracleTickValidatorMint(globalMemoryPolicyId);
const oracleTickPolicyId = lucid.utils.mintingPolicyToId(oracleTickValidator);

const poolValidator = new PoolValidatorMint(
  globalMemoryPolicyId,
  tickPolicyId,
  positionPolicyId,
  oracleTickPolicyId,
  getPoolId()
);
const poolPolicyId = lucid.utils.mintingPolicyToId(poolValidator);

const txHash = await mint(tickValidator);

await lucid.awaitTx(txHash);
console.log("@@@ Mint tick tx hash =", txHash);

async function mint(tickValidator: Script): Promise<TxHash> {
  const tickAddress = lucid.utils.validatorToAddress(tickValidator);

  const txBuilder = await lucid.newTx().attachMintingPolicy(tickValidator);

  const localKey = poolPolicyId + "00" + sitoa(tickId);
  const leafAssetName = hash(hash(localKey));
  const globalKey = tickPolicyId + "00" + leafAssetName;

  const poolAssetName = hash(hash(getPoolId()));

  //Mint Tick

  const tickDatum: TickValidatorSpend["_tickDatum"] = {
    poolPolicyId,
    tick: tickId,
    prev: -1000000n,
    next: 1000000n,
    liquidityGross: 0n,
    liquidityNet: 0n,
    feeGrowthOutside_0X128: 0n,
    feeGrowthOutside_1X128: 0n,
    initialized: false,
  };

  const tickInput: TickValidatorMint["tickInput"] = {
    poolPolicyId,
    tick: tickId,
  };

  txBuilder
    .mintAssets(
      { [`${tickPolicyId}${leafAssetName}`]: 1n },
      Data.to(tickInput, TickValidatorMint.tickInput)
    )
    .payToAddressWithData(
      tickAddress,
      {
        inline: Data.to(tickDatum, TickValidatorSpend._tickDatum),
      },
      {
        [`${tickPolicyId}${leafAssetName}`]: 1n,
      }
    )
    .readFrom([await lucid.utxoByUnit(`${poolPolicyId}${poolAssetName}`)]);

  //Mint global memory
  await appendMintGlobalMemory(lucid, txBuilder, globalKey);

  const tx = await txBuilder.complete();
  const signedTx = await tx.sign().complete();
  return signedTx.submit();
}
