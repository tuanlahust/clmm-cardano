use aiken/bytearray
use aiken/dict.{Dict}
use aiken/list
use aiken/transaction.{Input, Mint, Output, ScriptContext, Spend, Transaction}
use aiken/transaction/credential.{Address, ScriptCredential}
use aiken/transaction/value.{AssetName, PolicyId, Value}
use global_memory
use types.{DataNode, NameNode}
use utils

validator {
  fn mint(key: ByteArray, ctx: ScriptContext) -> Bool {
    expect ScriptContext { purpose: Mint(policy_id), transaction } = ctx
    let Transaction { inputs, mint, outputs, .. } = transaction

    let mint_value = value.from_minted_value(mint)
    let assets: Dict<AssetName, Int> = value.tokens(mint_value, policy_id)
    let asset_names = dict.keys(assets)
    let address = credential.from_script(policy_id)
    let mint_outputs = global_memory.map_output_by_policy(outputs, policy_id)
    expect list.all(dict.values(assets), fn(x) { x == 1 })

    if dict.has_key(assets, utils.convert_name_to_asset(#"")) {
      expect key == #""
      expect [_] = dict.to_pairs(assets)
      and {
        56 > 0,
        check_mint_root(mint_outputs),
        utils.check_same_address(outputs, policy_id, address),
      }
    } else {
      let name_nodes = list_mint_name_nodes(asset_names, key)
      let mint_inputs = global_memory.map_input_by_policy(inputs, policy_id)
      and {
        check_mint_path(name_nodes, mint_inputs),
        check_bitmap_mint(name_nodes, mint_inputs, mint_outputs),
        check_reference_mint(mint_value, policy_id, inputs, outputs),
        utils.check_same_address(outputs, policy_id, address),
        global_memory.check_bitmap_mint_leaf(key, mint_inputs, mint_outputs),
      }
    }
  }

  fn spend(datum: DataNode, key: ByteArray, ctx: ScriptContext) -> Bool {
    expect ScriptContext {
      purpose: Spend(output_ref),
      transaction: Transaction { mint, inputs, .. },
    } = ctx
    expect Some(Input { output: Output { address: this_address, .. }, .. }) =
      list.find(inputs, fn(inp) -> Bool { inp.output_reference == output_ref })
    expect ScriptCredential(policy_id) = this_address.payment_credential
    let asset_names: List<AssetName> =
      mint
        |> value.from_minted_value
        |> value.tokens(policy_id)
        |> dict.keys
    check_spend_inner_node(key, datum.name, asset_names)
  }
}

fn check_mint_root(mint_outputs: Dict<NameNode, DataNode>) {
  expect Some(data_node) = dict.get(mint_outputs, #"")
  data_node.bitmap == #""
}

fn check_mint_path(
  name_nodes: List<NameNode>,
  mint_inputs: Dict<NameNode, DataNode>,
) -> Bool {
  expect utils.check_ascending_sequence(name_nodes)
  expect Some(head_name) = list.head(name_nodes)
  let parent_head = utils.get_parent_name_node(head_name)
  let position_head = utils.get_position_name_node(head_name)
  when dict.get(mint_inputs, parent_head) is {
    None -> False
    Some(node) -> !utils.contains(node.bitmap, position_head)
  }
}

test test_check_mint_path_1() {
  let name_nodes =
    [#"01", #"0102", #"010203", #"01020304"]
  let mint_inputs =
    dict.new()
      |> dict.insert(#"", DataNode { name: #"", bitmap: #"" })
  check_mint_path(name_nodes, mint_inputs)
}

fn check_bitmap_mint(
  name_nodes: List<NameNode>,
  mint_inputs: Dict<NameNode, DataNode>,
  mint_outputs: Dict<NameNode, DataNode>,
) -> Bool {
  when name_nodes is {
    [] -> True
    [name_node, ..xs] -> and {
        global_memory.check_bitmap_mint_internal(
          name_node,
          mint_inputs,
          mint_outputs,
        ),
        check_bitmap_mint(xs, mint_inputs, mint_outputs),
      }
  }
}

fn check_spend_inner_node(
  key: ByteArray,
  spend_name_node: NameNode,
  asset_names: List<AssetName>,
) -> Bool {
  let name_nodes = list_mint_name_nodes(asset_names, key)
  expect Some(head_name) = list.head(name_nodes)
  spend_name_node == utils.get_parent_name_node(head_name)
}

test test_check_spend_inner_node_1() {
  let key = #"4d61692031"
  let asset_names =
    [
      #"126c26cbe3b05bfb5a8dd7cb99a78cd435da99cba698478fc076ce7423dc336e",
      #"23627b3a5c67da9d29580b94c3afb1e2f886c62fa772ecde1a80925a95fbc9ef",
      #"5b46579b5058a82d3a4d071d5af8c862889540549f2e0194ec183338f13a4ecf",
      #"63093bcc3cff6dcd93bf9fb9b1f18fa51697b2fa35eea2e6b61bf2582d5794f8",
      #"6d9bd3622c39e2842e9dbf682b3a1018e034dabf0fc2660d105b0288c60a7103",
      #"70f30315a3338607a5a46ae2c4708c82ee5cf092c672c81ae0448e0e7c74ae05",
      #"c3ada8c590c92ccbd24d0c7a0c379d1572d21440d014929b02016f6999c755d7",
    ]
  check_spend_inner_node(key, #"", asset_names)
}

test test_check_spend_inner_node_2() {
  let key = #"4d61692031"
  let asset_names =
    [
      #"126c26cbe3b05bfb5a8dd7cb99a78cd435da99cba698478fc076ce7423dc336e",
      #"5b46579b5058a82d3a4d071d5af8c862889540549f2e0194ec183338f13a4ecf",
      #"63093bcc3cff6dcd93bf9fb9b1f18fa51697b2fa35eea2e6b61bf2582d5794f8",
      #"6d9bd3622c39e2842e9dbf682b3a1018e034dabf0fc2660d105b0288c60a7103",
      #"70f30315a3338607a5a46ae2c4708c82ee5cf092c672c81ae0448e0e7c74ae05",
      #"c3ada8c590c92ccbd24d0c7a0c379d1572d21440d014929b02016f6999c755d7",
    ]
  check_spend_inner_node(key, #"48", asset_names)
}

test test_check_spend_inner_node_3() {
  let key = #"4d61692031"
  let asset_names =
    [
      #"126c26cbe3b05bfb5a8dd7cb99a78cd435da99cba698478fc076ce7423dc336e",
      #"23627b3a5c67da9d29580b94c3afb1e2f886c62fa772ecde1a80925a95fbc9ef",
      #"5b46579b5058a82d3a4d071d5af8c862889540549f2e0194ec183338f13a4ecf",
      #"63093bcc3cff6dcd93bf9fb9b1f18fa51697b2fa35eea2e6b61bf2582d5794f8",
      #"6d9bd3622c39e2842e9dbf682b3a1018e034dabf0fc2660d105b0288c60a7103",
      #"70f30315a3338607a5a46ae2c4708c82ee5cf092c672c81ae0448e0e7c74ae05",
      #"c3ada8c590c92ccbd24d0c7a0c379d1572d21440d014929b02016f6999c755d7",
    ]
  check_spend_inner_node(key, #"", asset_names)
}

pub fn list_mint_name_nodes(
  asset_names: List<AssetName>,
  key: ByteArray,
) -> List<NameNode> {
  let name_nodes = do_list_mint_name_nodes(asset_names, map_asset_by_key(key))
  list.sort(name_nodes, bytearray.compare)
}

fn do_list_mint_name_nodes(
  asset_names: List<AssetName>,
  map_asset_names: Dict<AssetName, NameNode>,
) -> List<NameNode> {
  when asset_names is {
    [] ->
      []
    [asset_name, ..xs] -> {
      expect Some(name_node) = dict.get(map_asset_names, asset_name)
      [name_node, ..do_list_mint_name_nodes(xs, map_asset_names)]
    }
  }
}

fn map_asset_by_key(key: ByteArray) -> Dict<AssetName, NameNode> {
  map_asset_by_name_node(utils.convert_key_to_name(key))
}

fn map_asset_by_name_node(name_node: NameNode) -> Dict<AssetName, NameNode> {
  if name_node == #"" {
    dict.new() |> dict.insert(utils.convert_name_to_asset(name_node), name_node)
  } else {
    let parent_name_node = utils.get_parent_name_node(name_node)
    if bytearray.length(name_node) == 32 {
      map_asset_by_name_node(parent_name_node)
    } else {
      dict.insert(
        map_asset_by_name_node(parent_name_node),
        utils.convert_name_to_asset(name_node),
        name_node,
      )
    }
  }
}

test test_list_mint_name_nodes_1() {
  let key = #"4d61692031"
  let asset_names =
    [
      #"126c26cbe3b05bfb5a8dd7cb99a78cd435da99cba698478fc076ce7423dc336e",
      #"23627b3a5c67da9d29580b94c3afb1e2f886c62fa772ecde1a80925a95fbc9ef",
      #"5b46579b5058a82d3a4d071d5af8c862889540549f2e0194ec183338f13a4ecf",
      #"63093bcc3cff6dcd93bf9fb9b1f18fa51697b2fa35eea2e6b61bf2582d5794f8",
      #"6d9bd3622c39e2842e9dbf682b3a1018e034dabf0fc2660d105b0288c60a7103",
      #"70f30315a3338607a5a46ae2c4708c82ee5cf092c672c81ae0448e0e7c74ae05",
      #"c3ada8c590c92ccbd24d0c7a0c379d1572d21440d014929b02016f6999c755d7",
    ]
  list_mint_name_nodes(asset_names, key) == [
    #"48", #"4850", #"485091", #"4850911b", #"4850911b05f5",
    #"4850911b05f5a88e9676", #"4850911b05f5a88e9676ba6b961948722b19",
  ]
}

fn check_reference_mint(
  mint_value: Value,
  policy_id: PolicyId,
  inputs: List<Input>,
  outputs: List<Output>,
) -> Bool {
  let keys = list_mint_key_exclude_policy(mint_value, policy_id)
  expect Some(head_key) = list.head(keys)
  global_memory.check_mint_nft_global(
    mint_value,
    policy_id,
    head_key,
    inputs,
    outputs,
  )
}

fn list_mint_key_exclude_policy(
  mint_value: Value,
  policy_id: PolicyId,
) -> List<ByteArray> {
  value.flatten_with(
    mint_value,
    fn(p, a, _) -> Option<NameNode> {
      if p == policy_id {
        None
      } else {
        Some(utils.join([p, a]))
      }
    },
  )
}

test test_list_mint_name_exclude_policy_1() {
  let v =
    value.zero()
      |> value.add(#"01", #"01", 1)
      |> value.add(#"02", #"", 1)
      |> value.add(#"01", #"02", 1)
  list_mint_key_exclude_policy(v, #"02") == [#"010001", #"010002"]
}
