mod device;
mod socket;

fn main() {
   let _ = socket::start_unix_listener("sock");
}

