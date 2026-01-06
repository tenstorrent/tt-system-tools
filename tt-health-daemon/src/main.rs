mod device;
mod socket;
mod influx;

use std::env;
use dotenv::dotenv;
use influxdb::Client;

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
   dotenv().ok();
   let influxdb_token = env::var("INFLUXDB_TOKEN").expect("INFLUXDB_TOKEN must be set in .env file");
   let influxdb_url = env::var("INFLUXDB_URL").expect("INFLUXDB_URL must be set in .env file");
   let client = Client::new(influxdb_url, "tt-health").with_token(influxdb_token);

   let mut devices = device::get_tenstorrent_devices()?;
   device::update_tenstorrent_devices(&mut devices)?;
   
   for device in devices {
      let query = influx::create_influxdb_query(device);
      
      match client.query(query).await {
         Ok(_) => println!("Successfully sent device data to InfluxDB"),
         Err(e) => eprintln!("Failed to send data to InfluxDB: {}", e),
      }
   }
   
   Ok(())
}