import { Blockfrost, Data, Lucid, Script, TxHash, UTxO } from "lucid-cardano";
import alice from "../accounts/alice.json" with { type: "json" };
import {
  GlobalMemoryValidatorMint,
  GlobalMemoryValidatorSpend,
} from "../plutus.ts";
import { hash } from "./utils.ts";

const lucid = await Lucid.new(
  new Blockfrost(
    "https://cardano-preprod.blockfrost.io/api/v0",
    "preprod11lyjeIE3zO12zCYyyNJ5zzLptMsbMwu"
  ),
  "Preprod"
);

lucid.selectWalletFromSeed(alice.seed);
console.log("@@@ Wallet address =", await lucid.wallet.address());

const validatorMint = new GlobalMemoryValidatorMint();

const txHash = await mint(validatorMint);
await lucid.awaitTx(txHash);
console.log("@@@ Mint root tx hash =", txHash);

async function mint(validatorMint: Script): Promise<TxHash> {
  const contractAddress = lucid.utils.validatorToAddress(validatorMint);
  const policyId = lucid.utils.mintingPolicyToId(validatorMint);

  const assets: Record<string, bigint> = { [`${policyId}${hash("")}`]: 1n };

  const redeemer: GlobalMemoryValidatorMint["key"] = "";
  const datum: GlobalMemoryValidatorSpend["datum"] = {
    name: "",
    bitmap: "",
  };

  const tx = await lucid
    .newTx()
    .attachMintingPolicy(validatorMint)
    .mintAssets(assets, Data.to(redeemer, GlobalMemoryValidatorMint.key))
    .payToAddressWithData(
      contractAddress,
      {
        inline: Data.to(datum, GlobalMemoryValidatorSpend.datum),
      },
      assets
    )
    .complete();

  const signedTx = await tx.sign().complete();
  return signedTx.submit();
}
