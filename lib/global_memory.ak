use aiken/bytearray
use aiken/dict.{Dict}
use aiken/transaction.{InlineDatum, Input, Output}
use aiken/transaction/value.{AssetName, PolicyId, Value}
use types.{DataNode, NameNode}
use utils

pub fn check_bitmap_mint_leaf(
  key: ByteArray,
  mint_inputs: Dict<NameNode, DataNode>,
  mint_outputs: Dict<NameNode, DataNode>,
) -> Bool {
  let name_node = utils.convert_key_to_name(key)
  check_bitmap_mint_internal(name_node, mint_inputs, mint_outputs)
}

pub fn check_bitmap_mint_internal(
  name_node: NameNode,
  mint_inputs: Dict<NameNode, DataNode>,
  mint_outputs: Dict<NameNode, DataNode>,
) -> Bool {
  let parent = utils.get_parent_name_node(name_node)
  let input_bitmap =
    when dict.get(mint_inputs, parent) is {
      None -> #""
      Some(x) -> x.bitmap
    }
  expect Some(output) = dict.get(mint_outputs, parent)
  let position = utils.get_position_name_node(name_node)
  bytearray.concat(input_bitmap, position) == output.bitmap
}

pub fn map_input_by_policy(
  inputs: List<Input>,
  policy_id: PolicyId,
) -> Dict<NameNode, DataNode> {
  map_output_by_policy(utils.i2o(inputs), policy_id)
}

pub fn map_output_by_policy(
  outputs: List<Output>,
  policy_id: PolicyId,
) -> Dict<NameNode, DataNode> {
  when outputs is {
    [] -> dict.new()
    [output, ..xs] ->
      when utils.get_asset_name_from_nft(output, policy_id) is {
        None -> map_output_by_policy(xs, policy_id)
        Some(asset_name) -> {
          expect InlineDatum(output_datum) = output.datum
          expect data_node: DataNode = output_datum
          let name_node = get_and_check_name_node(asset_name, data_node)
          dict.insert(map_output_by_policy(xs, policy_id), name_node, data_node)
        }
      }
  }
}

fn get_and_check_name_node(
  asset_name: AssetName,
  data_node: DataNode,
) -> NameNode {
  expect utils.convert_name_to_asset(data_node.name) == asset_name
  data_node.name
}

pub fn check_mint_nft_global(
  mint_value: Value,
  global_policy_id: PolicyId,
  key: ByteArray,
  inputs: List<Input>,
  outputs: List<Output>,
) -> Bool {
  and {
    do_check_quantity_mint_nft_global(mint_value, global_policy_id, key),
    do_check_bitmap_mint_nft_global(global_policy_id, key, inputs, outputs),
  }
}

fn do_check_quantity_mint_nft_global(
  mint_value: Value,
  global_policy_id: PolicyId,
  key: ByteArray,
) -> Bool {
  let name_node = utils.convert_key_to_name(key)
  let parent_name_node = utils.get_parent_name_node(name_node)
  let asset_name = utils.convert_name_to_asset(parent_name_node)
  value.quantity_of(mint_value, global_policy_id, asset_name) == 1
}

fn do_check_bitmap_mint_nft_global(
  global_policy_id: PolicyId,
  key: ByteArray,
  inputs: List<Input>,
  outputs: List<Output>,
) -> Bool {
  let mint_inputs = map_input_by_policy(inputs, global_policy_id)
  let mint_outputs = map_output_by_policy(outputs, global_policy_id)
  check_bitmap_mint_leaf(key, mint_inputs, mint_outputs)
}
