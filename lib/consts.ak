pub fn get_tick_size() -> Int {
  100
}

pub fn get_max_tick() -> Int {
  0 - get_min_tick()
}

// log(2^128)/log(1.001) = -88767
pub fn get_min_tick() -> Int {
  -88700
}
