use std::os::unix::net::{UnixStream, UnixListener};
use std::io::Write;
use std::thread;
use std::fs;
use crate::device;

// TODO: Turn this into a metrics exporter using conventional formats

fn handle_client(mut stream: UnixStream) -> std::io::Result<()> {

    let devices = device::get_tenstorrent_devices()?;

    for dev in &devices {
        let _ = stream.write_all(&format!("tt_asic_id: {}\n", dev.tt_asic_id.as_deref().unwrap_or("unknown")).into_bytes());
        let _ = stream.write_all(&format!("tt_aiclk: {}\n", dev.tt_aiclk.as_deref().unwrap_or("unknown")).into_bytes());
        let _ = stream.write_all(&format!("tt_arcclk: {}\n", dev.tt_arcclk.as_deref().unwrap_or("unknown")).into_bytes());
        let _ = stream.write_all(&format!("tt_axiclk: {}\n", dev.tt_axiclk.as_deref().unwrap_or("unknown")).into_bytes());
        let _ = stream.write_all(&format!("tt_card_type: {}\n", dev.tt_card_type.as_deref().unwrap_or("unknown")).into_bytes());
        let _ = stream.write_all(&format!("tt_fw_bundle_ver: {}\n", dev.tt_fw_bundle_ver.as_deref().unwrap_or("unknown")).into_bytes());
        let _ = stream.write_all(&format!("tt_m3app_fw_ver: {}\n", dev.tt_m3app_fw_ver.as_deref().unwrap_or("unknown")).into_bytes());
        let _ = stream.write_all(&format!("tt_serial: {}\n", dev.tt_serial.as_deref().unwrap_or("unknown")).into_bytes());
        if let Some(counters) = &dev.pcie_perf_counters {
            let _ = stream.write_all(&format!("mst_nonposted_wr_data_word_sent0: {}\n", counters.mst_nonposted_wr_data_word_sent0).into_bytes());
            let _ = stream.write_all(&format!("mst_nonposted_wr_data_word_sent1: {}\n", counters.mst_nonposted_wr_data_word_sent1).into_bytes());
            let _ = stream.write_all(&format!("mst_posted_wr_data_word_sent0: {}\n", counters.mst_posted_wr_data_word_sent0).into_bytes());
            let _ = stream.write_all(&format!("mst_posted_wr_data_word_sent1: {}\n", counters.mst_posted_wr_data_word_sent1).into_bytes());
            let _ = stream.write_all(&format!("mst_rd_data_word_received0: {}\n", counters.mst_rd_data_word_received0).into_bytes());
            let _ = stream.write_all(&format!("mst_rd_data_word_received1: {}\n", counters.mst_rd_data_word_received1).into_bytes());
            let _ = stream.write_all(&format!("slv_nonposted_wr_data_word_received0: {}\n", counters.slv_nonposted_wr_data_word_received0).into_bytes());
            let _ = stream.write_all(&format!("slv_nonposted_wr_data_word_received1: {}\n", counters.slv_nonposted_wr_data_word_received1).into_bytes());
            let _ = stream.write_all(&format!("slv_posted_wr_data_word_received0: {}\n", counters.slv_posted_wr_data_word_received0).into_bytes());
            let _ = stream.write_all(&format!("slv_posted_wr_data_word_received1: {}\n", counters.slv_posted_wr_data_word_received1).into_bytes());
            let _ = stream.write_all(&format!("slv_rd_data_word_sent0: {}\n", counters.slv_rd_data_word_sent0).into_bytes());
            let _ = stream.write_all(&format!("slv_rd_data_word_sent1: {}\n", counters.slv_rd_data_word_sent1).into_bytes());
        }
        if let Some(telemetry) = &dev.telemetry {
            let _ = stream.write_all(&format!("current: {}\n", telemetry.current).into_bytes());
            let _ = stream.write_all(&format!("power: {}\n", telemetry.power).into_bytes());
            let _ = stream.write_all(&format!("asic_temp: {}\n", telemetry.asic_temp).into_bytes());
            let _ = stream.write_all(&format!("vcore: {}\n", telemetry.vcore).into_bytes());
            let _ = stream.write_all(&format!("fan_rpm: {}\n", telemetry.fan_rpm).into_bytes());
        }
    }

    Ok(())
}

pub fn start_unix_listener(socket_path: &str) -> std::io::Result<()> {
    // if socket_path already exists, clean it up
    if fs::metadata(socket_path).is_ok() {
        fs::remove_file(socket_path)?;
    }

    let listener = UnixListener::bind(socket_path)?;
    
    // from UnixListener docs:
    // accept connections and process them, spawning a new thread for each one
    for stream in listener.incoming() {
        match stream {
            Ok(stream) => {
                // Connection succeeded 
                thread::spawn(|| handle_client(stream));
            }
            Err(_) => {
                // Connection failed
                break;
            }
        }
    }
    Ok(())
}