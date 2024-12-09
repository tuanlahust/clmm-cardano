use aiken/list
use aiken/transaction.{ScriptContext}

validator {
  fn mint(t: Int, _ctx: ScriptContext) -> Bool {
    let lst =
      [1, 2, 3, 4]
    expect Some(_) = list.find(lst, fn(x) { x == t })
    1 > 0
  }
}

validator {
  fn spend(d: Int, r: Int, _ctx: ScriptContext) -> Bool {
    d == r
  }
}
// fn mul(lst: List<Int>) -> Int {
//   when lst is {
//     [] -> 1
//     [x, ..xs] -> {
//       let a = x * ( x - math.pow2(256) / math.pow2(256) )
//       let b = x * x * math.pow2(256)
//       a + b + mul(xs)
//     }
//   }
// }
