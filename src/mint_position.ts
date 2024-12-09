import { Data, Script, TxHash } from "lucid-cardano";
import alice from "../accounts/alice.json" with { type: "json" };
import { PositionValidatorMint, PositionValidatorSpend } from "../plutus.ts";
import { appendMintGlobalMemory, hash, sitoa } from "./utils.ts";
import {
  getPoolId,
  lucid,
  positionPolicyId,
  positionValidator,
  poolPolicyId,
  tickPolicyId,
  getTickUTxO,
  getPoolUTxO,
} from "./configs.ts";

declare global {
  interface BigInt {
    toJSON(): Number;
  }
}
BigInt.prototype.toJSON = function () {
  return Number(this);
};

console.log("@@@ Wallet address =", await lucid.wallet.address());

const tickLower = 2310n;
const tickUpper = 2370n;
const addressDetails = lucid.utils.getAddressDetails(alice.address);
const owner = addressDetails.paymentCredential?.hash!;

console.log(`@@@ owner = ${owner}`);

const txHash = await mint(positionValidator);

await lucid.awaitTx(txHash);
console.log("@@@ Mint position tx hash =", txHash);

async function mint(positionValidator: Script): Promise<TxHash> {
  const positionAddress = lucid.utils.validatorToAddress(positionValidator);

  const localKey =
    poolPolicyId +
    "00" +
    owner +
    "00" +
    sitoa(tickLower) +
    "00" +
    sitoa(tickUpper);
  const leafAssetName = hash(hash(localKey));
  const globalKey = positionPolicyId + "00" + leafAssetName;

  //Mint Tick

  const positionDatum: PositionValidatorSpend["_positionDatum"] = {
    poolPolicyId,
    owner,
    tickLower,
    tickUpper,
    liquidity: 0n,
    feeGrowthInside_0LastX128: 0n,
    feeGrowthInside_1LastX128: 0n,
    tokensOwed_0: 0n,
    tokensOwed_1: 0n,
  };

  const positionInput: PositionValidatorMint["positionInput"] = {
    poolPolicyId,
    tickPolicyId,
    owner,
    tickLower,
    tickUpper,
  };

  const txBuilder = await lucid.newTx().attachMintingPolicy(positionValidator);
  txBuilder
    .mintAssets(
      { [`${positionPolicyId}${leafAssetName}`]: 1n },
      Data.to(positionInput, PositionValidatorMint.positionInput)
    )
    .payToAddressWithData(
      positionAddress,
      {
        inline: Data.to(positionDatum, PositionValidatorSpend._positionDatum),
      },
      {
        [`${positionPolicyId}${leafAssetName}`]: 1n,
      }
    )
    .readFrom([await getTickUTxO(poolPolicyId, tickLower)])
    .readFrom([await getTickUTxO(poolPolicyId, tickUpper)])
    .readFrom([await getPoolUTxO(getPoolId())])
    .addSigner(alice.address);

  //Mint global memory
  await appendMintGlobalMemory(lucid, txBuilder, globalKey);

  const tx = await txBuilder.complete();
  const signedTx = await tx.sign().complete();
  return signedTx.submit();
}
