import { Blockfrost, Data, Lucid, UTxO } from "lucid-cardano";
import {
  GlobalMemoryValidatorSpend,
  OracleTickValidatorMint,
  OracleTickValidatorSpend,
  PoolValidatorMint,
  PoolValidatorSpend,
  PositionValidatorSpend,
  TickValidatorSpend,
} from "../plutus.ts";
import { hash, sitoa } from "./utils.ts";
import alice from "../accounts/alice.json" with { type: "json" };

export const policyId0 =
  "430e5fcba4c98babc94b7b3474481669d4c68e1543240b735aa26f02";
export const assetName0 = "414243";
export const policyId1 =
  "430e5fcba4c98babc94b7b3474481669d4c68e1543240b735aa26f02";
export const assetName1 = "444546";
export const token0 = { policyId: policyId0, assetName: assetName0 };
export const token1 = { policyId: policyId1, assetName: assetName1 };

export const fee = 3000n;
export const tickSpacing = 6n;

export const minTick: bigint = 2300n; //Price = 10 => tick = 2303.74
export const maxTick: bigint = 2400n;

export const tickId = 2310n; // 2310n - 2370n

export function getPoolId(): string {
  return hash(
    policyId0 +
      assetName0 +
      "00" +
      policyId1 +
      assetName1 +
      "00" +
      sitoa(BigInt(fee))
  );
}

export const lucid = await Lucid.new(
  new Blockfrost(
    "https://cardano-preprod.blockfrost.io/api/v0",
    "preprod11lyjeIE3zO12zCYyyNJ5zzLptMsbMwu"
  ),
  "Preprod"
);

lucid.selectWalletFromSeed(alice.seed);

export const globalMemoryValidator = new GlobalMemoryValidatorSpend();
export const globalMemoryPolicyId = lucid.utils.mintingPolicyToId(
  globalMemoryValidator
);

export const tickValidator = new TickValidatorSpend(
  globalMemoryPolicyId,
  getPoolId()
);
export const tickPolicyId = lucid.utils.mintingPolicyToId(tickValidator);

export const positionValidator = new PositionValidatorSpend(
  globalMemoryPolicyId,
  getPoolId()
);
export const positionPolicyId =
  lucid.utils.mintingPolicyToId(positionValidator);

export const oracleTickValidator = new OracleTickValidatorMint(
  globalMemoryPolicyId
);
export const oracleTickPolicyId =
  lucid.utils.mintingPolicyToId(oracleTickValidator);

export const poolValidator = new PoolValidatorMint(
  globalMemoryPolicyId,
  tickPolicyId,
  positionPolicyId,
  oracleTickPolicyId,
  getPoolId()
);
export const poolPolicyId = lucid.utils.mintingPolicyToId(poolValidator);

export async function getPoolUTxO(poolId: string): Promise<UTxO> {
  return await getUTxO(poolPolicyId, poolId);
}

export async function getPoolDatum(
  poolId: string
): Promise<PoolValidatorSpend["poolDatum"]> {
  const utxo = await getPoolUTxO(poolId);
  return Data.from<PoolValidatorSpend["poolDatum"]>(
    utxo.datum!,
    PoolValidatorSpend["poolDatum"]
  );
}

export async function getOracleTickUTxO(tick: bigint): Promise<UTxO> {
  const localKey = sitoa((tick / 100n) * 100n);
  return await getUTxO(oracleTickPolicyId, localKey);
}

export async function getOracleTickDatum(
  tick: bigint
): Promise<OracleTickValidatorSpend["_oracleTick"]> {
  const utxo = await getOracleTickUTxO(tick);
  return Data.from<OracleTickValidatorSpend["_oracleTick"]>(
    utxo.datum!,
    OracleTickValidatorSpend["_oracleTick"]
  );
}

export async function getTickUTxO(
  poolPolicyId: string,
  tick: bigint
): Promise<UTxO> {
  const localKey = poolPolicyId + "00" + sitoa(tick);
  return await getUTxO(tickPolicyId, localKey);
}

export async function getTickDatum(
  poolPolicyId: string,
  tick: bigint
): Promise<TickValidatorSpend["_tickDatum"]> {
  const utxo = await getTickUTxO(poolPolicyId, tick);
  return Data.from<TickValidatorSpend["_tickDatum"]>(
    utxo.datum!,
    TickValidatorSpend["_tickDatum"]
  );
}

export async function getPositionUTxO(
  poolPolicyId: string,
  owner: string,
  tickLower: bigint,
  tickUpper: bigint
): Promise<UTxO> {
  const localKey =
    poolPolicyId +
    "00" +
    owner +
    "00" +
    sitoa(tickLower) +
    "00" +
    sitoa(tickUpper);
  return await getUTxO(positionPolicyId, localKey);
}

export async function getPositionDatum(
  poolPolicyId: string,
  owner: string,
  tickLower: bigint,
  tickUpper: bigint
): Promise<PositionValidatorSpend["_positionDatum"]> {
  const utxo = await getPositionUTxO(poolPolicyId, owner, tickLower, tickUpper);
  return Data.from<PositionValidatorSpend["_positionDatum"]>(
    utxo.datum!,
    PositionValidatorSpend["_positionDatum"]
  );
}

async function getUTxO(policyId: string, localKey: string): Promise<UTxO> {
  return await lucid.utxoByUnit(`${policyId}${hash(hash(localKey))}`);
}
