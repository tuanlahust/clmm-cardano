import { Blockfrost, Data, Lucid, TxHash } from "lucid-cardano";
import acc from "../accounts/alice.json" with { type: "json" };
import { poolValidator } from "./configs.ts";

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

const filePath = "validators.json";
const fileData = await Deno.readTextFile(filePath);
const json = JSON.parse(fileData);

const txHash = await deploy();

json["pool"] = txHash;
await Deno.writeTextFile(filePath, JSON.stringify(json));

await lucid.awaitTx(txHash);
console.log("@@@ Mint pool tx hash =", txHash);

async function deploy(): Promise<TxHash> {
  const contractAddress = lucid.utils.validatorToAddress(poolValidator);

  const txBuilder = await lucid.newTx();
  txBuilder.payToContract(
    contractAddress,
    { inline: Data.void(), scriptRef: poolValidator },
    { ["lovelace"]: 1000000n }
  );

  const tx = await txBuilder.complete();
  const signedTx = await tx.sign().complete();
  return signedTx.submit();
}
