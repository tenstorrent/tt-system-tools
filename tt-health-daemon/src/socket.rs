use std::os::unix::net::{UnixStream, UnixListener};
use std::io::Write;
use std::thread;
use std::fs;
use crate::device;

// TODO: Turn this into a metrics exporter using conventional formats

fn handle_client(mut stream: UnixStream) -> std::io::Result<()> {
    let mut devices = device::get_tenstorrent_devices()?;
    device::update_tenstorrent_devices(&mut devices)?;

    for dev in devices {
        let _ = stream.write_all(&format!("{:?}", dev).into_bytes());
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