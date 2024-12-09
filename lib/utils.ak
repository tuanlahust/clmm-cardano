use aiken/builtin
use aiken/bytearray
use aiken/dict
use aiken/hash
use aiken/list
use aiken/option
use aiken/transaction.{InlineDatum, Input, Output, OutputReference}
use aiken/transaction/credential.{Address, ScriptCredential}
use aiken/transaction/value.{AssetName, PolicyId, Value}
use tick_math
use types.{NameNode, OracleTickDatum, Token}

pub fn i2o(inputs: List<Input>) -> List<Output> {
  when inputs is {
    [] ->
      []
    [x, ..xs] ->
      [x.output, ..i2o(xs)]
  }
}

pub fn atoi(a: ByteArray) -> Int {
  bytearray.foldl(a, 0, fn(byte, acc) { acc * 256 + byte })
}

test test_atoi_1() {
  atoi(#"1111") == 4369
}

test test_atoi_2() {
  atoi(#"") == 0
}

pub fn atosi(a: ByteArray) -> Int {
  let signed = bytearray.take(a, 1)
  let number = bytearray.slice(a, 1, bytearray.length(a) - 1)
  let rs = atoi(number)
  if signed == #"00" {
    rs
  } else {
    0 - rs
  }
}

test test_atosi_1() {
  atosi(#"00fe") == 254
}

test test_atosi_2() {
  atosi(#"01fe") == -254
}

test test_atosi_3() {
  atosi(#"0000") == 0
}

pub fn itoa(num: Int) -> ByteArray {
  if num >= 0 {
    bytearray.concat(#"00", do_itoa(num))
  } else {
    bytearray.concat(#"01", do_itoa(0 - num))
  }
}

fn do_itoa(num: Int) -> ByteArray {
  if num < 256 {
    builtin.cons_bytearray(num, "")
  } else {
    bytearray.concat(do_itoa(num / 256), do_itoa(num % 256))
  }
}

test test_itoa_1() {
  itoa(255) == #"00ff"
}

test test_itoa_2() {
  itoa(256) == #"000100"
}

test test_itoa_3() {
  itoa(257) == #"000101"
}

test test_itoa_4() {
  itoa(80000) == #"00013880"
}

test test_itoa_5() {
  itoa(-80000) == #"01013880"
}

pub fn check_ascending_sequence(sorted_items: List<ByteArray>) -> Bool {
  when sorted_items is {
    [] -> True
    [_] -> True
    [x, y, ..xs] ->
      x == get_parent_name_node(y) && check_ascending_sequence([y, ..xs])
  }
}

test test_check_fusion_ascending_sequence_1() {
  let lst =
    [
      #"01", #"0102", #"010203", #"01020304", #"010203040506",
      #"0102030405060708090a",
    ]
  check_ascending_sequence(lst)
}

test test_check_fusion_ascending_sequence_2() {
  let lst =
    [#"01", #"0102", #"01020304", #"010203040506", #"0102030405060708090a"]
  check_ascending_sequence(lst) == False
}

fn get_length_position_by_name(name: ByteArray) -> Option<Int> {
  when bytearray.length(name) is {
    1 | 2 | 3 | 4 -> Some(1)
    6 -> Some(2)
    10 -> Some(4)
    18 -> Some(8)
    32 -> Some(14)
    _ -> None
  }
}

test test_get_length_position_by_name_1() {
  get_length_position_by_name(#"01020304") == Some(1)
}

test test_get_length_position_by_name_2() {
  get_length_position_by_name(#"0102030405") == None
}

test test_get_length_position_by_name_3() {
  get_length_position_by_name(#"010203040506") == Some(2)
}

test test_get_length_position_by_name_4() {
  get_length_position_by_name(#"0102030405060708090a") == Some(4)
}

test test_get_length_position_by_name_5() {
  get_length_position_by_name(#"") == None
}

pub fn get_parent_name_node(name_node: ByteArray) -> ByteArray {
  expect Some(len_pos) = get_length_position_by_name(name_node)
  bytearray.take(name_node, bytearray.length(name_node) - len_pos)
}

test test_get_parent_name_node_1() {
  get_parent_name_node(#"0102030405060708090a") == #"010203040506"
}

test test_get_parent_name_node_2() {
  get_parent_name_node(#"01") == #""
}

pub fn get_position_name_node(name_node: ByteArray) -> ByteArray {
  let len_name_node = bytearray.length(name_node)
  expect Some(len_pos) = get_length_position_by_name(name_node)
  bytearray.slice(name_node, len_name_node - len_pos, len_name_node - 1)
}

test test_get_position_name_node_1() {
  get_position_name_node(#"0102030405060708090a") == #"0708090a"
}

test test_get_position_name_node_2() {
  get_position_name_node(#"01") == #"01"
}

pub fn index_of(self: ByteArray, bytes: ByteArray) -> Option<(Int, Int)> {
  let offset = bytearray.length(bytes)

  do_index_of(self, bytes, 0, offset, bytearray.length(self))
    |> option.map(fn(ix) { (ix, ix + offset - 1) })
}

fn do_index_of(
  self: ByteArray,
  bytes: ByteArray,
  cursor: Int,
  offset: Int,
  size: Int,
) -> Option<Int> {
  if cursor + offset > size {
    None
  } else {
    if builtin.slice_bytearray(cursor, offset, self) == bytes {
      Some(cursor)
    } else {
      do_index_of(self, bytes, cursor + offset, offset, size)
    }
  }
}

test test_index_of_1() {
  index_of(#"01020304", #"02") == Some((1, 1))
}

test test_index_of_2() {
  index_of(#"01020304", #"0203") == None
}

test test_index_of_3() {
  index_of(#"01020304", #"0304") == Some((2, 3))
}

test test_index_of_4() {
  index_of(#"0102030405", #"0405") == None
}

test test_index_of_5() {
  index_of(#"", #"0405") == None
}

pub fn contains(self: ByteArray, bytes: ByteArray) -> Bool {
  when index_of(self, bytes) is {
    None -> False
    _ -> True
  }
}

test test_contains_1() {
  contains(#"01020304", #"02")
}

test test_contains_2() {
  contains(#"01020304", #"10") == False
}

pub fn exact_nft_datum(
  outputs: List<Output>,
  policy_id: PolicyId,
  key: ByteArray,
) -> Data {
  expect Some(datum) =
    find_nft_datum(outputs, policy_id, convert_key_to_asset(key))
  datum
}

fn find_nft_datum(
  outputs: List<Output>,
  policy_id: PolicyId,
  asset_name: AssetName,
) -> Option<Data> {
  when outputs is {
    [] -> None
    [output, ..xs] ->
      if value.quantity_of(output.value, policy_id, asset_name) > 0 {
        expect InlineDatum(datum) = output.datum
        Some(datum)
      } else {
        find_nft_datum(xs, policy_id, asset_name)
      }
  }
}

pub fn convert_key_to_name(key: ByteArray) -> NameNode {
  hash.blake2b_256(key)
}

pub fn convert_name_to_asset(name_node: NameNode) -> AssetName {
  hash.blake2b_256(name_node)
}

pub fn convert_key_to_asset(key: ByteArray) -> AssetName {
  convert_name_to_asset(convert_key_to_name(key))
}

pub fn hash(key: ByteArray) -> ByteArray {
  hash.blake2b_256(key)
}

pub fn join(items: List<ByteArray>) -> ByteArray {
  do_join(items, #"00")
}

fn do_join(items: List<ByteArray>, delimiter: ByteArray) -> ByteArray {
  when items is {
    [] -> #""
    [x] -> x
    [x, ..xs] ->
      bytearray.concat(bytearray.concat(x, delimiter), do_join(xs, delimiter))
  }
}

test test_join_1() {
  join([#"01", #"02", #"03"]) == #"0100020003"
}

pub fn has_nft_by_key(
  policy_id: PolicyId,
  key: ByteArray,
  outputs: List<Output>,
) -> Bool {
  has_nft(policy_id, convert_key_to_asset(key), outputs)
}

pub fn has_nft(
  policy_id: PolicyId,
  asset_name: AssetName,
  outputs: List<Output>,
) -> Bool {
  when outputs is {
    [] -> False
    [output, ..xs] ->
      if value.quantity_of(output.value, policy_id, asset_name) == 1 {
        True
      } else {
        has_nft(policy_id, asset_name, xs)
      }
  }
}

pub fn get_policy_from_spend(
  inputs: List<Input>,
  output_reference: OutputReference,
) -> PolicyId {
  expect Some(Input { output: Output { address: this_address, .. }, .. }) =
    transaction.find_input(inputs, output_reference)
  expect ScriptCredential(script_hash) = this_address.payment_credential
  script_hash
}

pub fn check_same_address(
  outputs: List<Output>,
  policy_id: PolicyId,
  address: Address,
) -> Bool {
  list.all(
    outputs,
    fn(output) {
      !has_nft_with_policy(output, policy_id) || output.address == address
    },
  )
}

fn has_nft_with_policy(output: Output, policy_id: PolicyId) -> Bool {
  when get_asset_name_from_nft(output, policy_id) is {
    None -> False
    _ -> True
  }
}

pub fn get_asset_name_from_nft(
  output: Output,
  policy_id: PolicyId,
) -> Option<ByteArray> {
  let asset_names = value.tokens(output.value, policy_id)
  if dict.size(asset_names) == 0 {
    None
  } else {
    expect [Pair(asset_name, 1)] = dict.to_pairs(asset_names)
    Some(asset_name)
  }
}

pub fn get_tick_spacing_by_fee(fee: Int) -> Option<Int> {
  when fee is {
    500 -> Some(1)
    // 500 - 10
    3000 -> Some(6)
    // 3000 - 60
    10000 -> Some(20)
    // 10000 - 200
    _ -> None
  }
}

pub fn find_nft_value(
  outputs: List<Output>,
  policy_id: PolicyId,
  asset_name: AssetName,
) -> Option<Value> {
  when outputs is {
    [] -> None
    [output, ..xs] ->
      if value.quantity_of(output.value, policy_id, asset_name) > 0 {
        Some(output.value)
      } else {
        find_nft_value(xs, policy_id, asset_name)
      }
  }
}

pub fn t2t(token: Token) -> ByteArray {
  bytearray.concat(token.policy_id, token.asset_name)
}

test test_t2t_0() {
  t2t(Token(#"01", #"02")) == #"0102"
}

test test_t2t_1() {
  t2t(Token(#"", #"")) == #""
}

pub fn get_oracle_tick(
  oracle_tick_policy_id: PolicyId,
  tick: Int,
  ref_inputs: List<Input>,
) -> OracleTickDatum {
  let tick_offset = tick_math.get_tick_offset(tick)
  expect oracle_tick: OracleTickDatum =
    exact_nft_datum(i2o(ref_inputs), oracle_tick_policy_id, itoa(tick_offset))
  oracle_tick
}
