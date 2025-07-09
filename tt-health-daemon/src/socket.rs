use std::os::unix::net::{UnixStream, UnixListener};
use std::io::Write;
use std::thread;
use std::fs;
use crate::device;

fn handle_client(mut stream: UnixStream) -> std::io::Result<()> {

    let devices = device::get_tenstorrent_devices()?;

    for dev in &devices {
        let _ = stream.write_all(&format!("tt-asic-id: {}\n", dev.tt_asic_id.as_deref().unwrap_or("unknown")).into_bytes());
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