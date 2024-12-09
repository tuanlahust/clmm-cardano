import { Blockfrost, Data, fromText, Lucid, TxHash } from "lucid-cardano";
import acc from "../accounts/alice.json" with { type: "json" };
import { DebugValidatorMint, DebugValidatorSpend } from "../plutus.ts";
import { getSqrtRatioAtTick, hash } from "./utils.ts";

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

lucid.selectWalletFromSeed(acc.seed);
console.log("@@@ Wallet address =", await lucid.wallet.address());

const txHash = await mint();

await lucid.awaitTx(txHash);
console.log("@@@ Mint pool tx hash =", txHash);

async function mint(): Promise<TxHash> {
  const debugValidator = new DebugValidatorMint();
  const debugPolicyId = lucid.utils.mintingPolicyToId(debugValidator);
  const debugAddress = lucid.utils.validatorToAddress(debugValidator);

  const addressDetails = lucid.utils.getAddressDetails(acc.address);
  console.log("### Address = " + JSON.stringify(addressDetails));

  const items: bigint[] = [];
  for (let i = 0n; i < 100n; i++) {
    let t = hash(fromText(i.toString()));
    const sqrtPriceX64 = getSqrtRatioAtTick(87067n + i);
    items.push(sqrtPriceX64);
  }

  const txBuilder = await lucid.newTx();

  console.log(`@@@ PolicyId = ${debugPolicyId}, assetName = ${fromText("DEF")}`)

  txBuilder
    .attachMintingPolicy(debugValidator)
    .mintAssets({ [`${debugPolicyId}${fromText("ABC")}`]: 100000000000n }, Data.to(4n))
    .addSigner(acc.address);

  const tx = await txBuilder.complete();
  const signedTx = await tx.sign().complete();
  return signedTx.submit();
}
