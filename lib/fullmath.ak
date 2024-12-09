// numerator / denominator = quotient
pub fn check_mul_div(numerator: Int, denominator: Int, quotient: Int) -> Bool {
  let remainder = numerator - denominator * quotient
  remainder >= 0 && remainder < denominator
}

test test_check_mul_div_1() {
  check_mul_div(15, 4, 3)
}

test test_check_mul_div_2() {
  check_mul_div(12, 4, 3)
}

test test_check_mul_div_3() {
  check_mul_div(99, 4, 3) == False
}
