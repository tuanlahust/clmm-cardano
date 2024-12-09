import { C, Data, fromHex, Lucid, toHex, Tx, UTxO } from "lucid-cardano";
import { GlobalMemoryValidatorSpend } from "../plutus.ts";

const positions = [0, 1, 2, 3, 4, 6, 10, 18, 32];

export async function appendMintGlobalMemory(
  lucid: Lucid,
  txBuilder: Tx,
  key: string
) {
  let leafNameNode = hash(key);
  const validatorMemory = new GlobalMemoryValidatorSpend();
  const globalMemoryPolicyId = lucid.utils.mintingPolicyToId(validatorMemory);
  const contractAddressMemory = lucid.utils.validatorToAddress(validatorMemory);

  const maxUtxo = await getMaxUtxo(
    lucid,
    globalMemoryPolicyId,
    leafNameNode,
    0,
    positions.length - 1
  );

  const datum = Data.from<GlobalMemoryValidatorSpend["datum"]>(
    maxUtxo?.maxUtxo.datum!,
    GlobalMemoryValidatorSpend["datum"]
  );
  const currentDatum = datum.bitmap;
  console.log("@@@ Current root datum bitmap =", currentDatum);

  const assets: Record<string, bigint> = {};

  txBuilder
    .attachSpendingValidator(validatorMemory)
    .attachMintingPolicy(validatorMemory);
  for (let index = 1; index < positions.length; index++) {
    const nameNode = leafNameNode.substring(0, positions[index] * 2);
    if (nameNode <= maxUtxo?.maxName!) {
      continue;
    }

    if (index < positions.length - 1) {
      assets[`${globalMemoryPolicyId}${hash(nameNode)}`] = 1n;
    }

    const position = nameNode.substring(positions[index - 1] * 2);
    const parentNameNode = leafNameNode.substring(0, positions[index - 1] * 2);

    if (parentNameNode === maxUtxo?.maxName) {
      const redeemer: GlobalMemoryValidatorSpend["key"] = {
        wrapper: key,
      };
      const dt: GlobalMemoryValidatorSpend["datum"] = {
        name: parentNameNode,
        bitmap: currentDatum + position,
      };

      txBuilder
        .collectFrom(
          [maxUtxo?.maxUtxo],
          Data.to(redeemer, GlobalMemoryValidatorSpend.key)
        )
        .payToAddressWithData(
          contractAddressMemory,
          {
            inline: Data.to(dt, GlobalMemoryValidatorSpend.datum),
          },
          { [`${globalMemoryPolicyId}${hash(parentNameNode)}`]: 1n }
        );
    } else {
      const dt: GlobalMemoryValidatorSpend["datum"] = {
        name: parentNameNode,
        bitmap: position,
      };
      txBuilder.payToAddressWithData(
        contractAddressMemory,
        {
          inline: Data.to(dt, GlobalMemoryValidatorSpend.datum),
        },
        { [`${globalMemoryPolicyId}${hash(parentNameNode)}`]: 1n }
      );
    }
  }
  txBuilder.mintAssets(assets, Data.to(key));
}

async function getMaxUtxo(
  lucid: Lucid,
  policyId: string,
  leafNameNode: string,
  min: number,
  max: number
): Promise<{ maxUtxo: UTxO; maxName: string } | undefined> {
  if (min > max) {
    return undefined;
  }

  const pivot = Math.floor((min + max) / 2);
  const parentNameNode = leafNameNode.substring(0, 2 * positions[pivot]);
  // console.log(
  //   `@@@ BST find min = ${min}, max = ${max}, pivot = ${pivot}, parentNameNode = ${parentNameNode}`
  // );

  const utxo = await getUTxO(lucid, policyId, parentNameNode);
  if (utxo) {
    // console.log(`@@@ BST find utxo name node "${parentNameNode}"`);
    const future = await getMaxUtxo(
      lucid,
      policyId,
      leafNameNode,
      pivot + 1,
      max
    );
    if (future) {
      return future;
    } else {
      return utxo;
    }
  } else {
    // console.log(`@@@ BST not found utxo name node "${parentNameNode}"`);
    return getMaxUtxo(lucid, policyId, leafNameNode, min, pivot - 1);
  }
}

async function getUTxO(
  lucid: Lucid,
  policyId: string,
  nameNode: string
): Promise<{ maxUtxo: UTxO; maxName: string } | undefined> {
  try {
    const utxo = await lucid.utxoByUnit(`${policyId}${hash(nameNode)}`);
    return { maxUtxo: utxo, maxName: nameNode };
  } catch (e) {
    return undefined;
  }
}

export function hash(text: string): string {
  const { hash_blake2b256 } = C;
  return toHex(hash_blake2b256(fromHex(text)));
}

export function getSqrtRatioAtTick(tick: bigint): bigint {
  return BigInt(Math.floor(2 ** 64 * Math.pow(1.001, Number(tick) / 2)));
}

export function getSqrtRatioAtTickStep(tick: bigint): bigint {
  const minTick = (tick / 100n) * 100n;
  const maxTick = minTick + 100n;
  const minSqrtPriceX64 = getSqrtRatioAtTick(minTick);
  const maxSqrtPriceX64 = getSqrtRatioAtTick(maxTick);
  const step = (maxSqrtPriceX64 - minSqrtPriceX64) / 100n;
  return minSqrtPriceX64 + (tick - minTick) * step;
}

export function getTickAtSqrtRatio(sqrtPriceX96: bigint):bigint {
  return 0n
}

export function itoa(n: bigint): string {
  let hexString = n.toString(16);
  if (hexString.length % 2 !== 0) {
    hexString = "0" + hexString;
  }
  return hexString;
}

export function sitoa(n: bigint): string {
  if (n >= 0) {
    return "00" + itoa(n);
  } else {
    return "01" + itoa(0n - n);
  }
}
