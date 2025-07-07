use std::os::unix::net::{UnixStream, UnixListener};
use std::io::Write;
use std::thread;
use std::fs;

fn handle_client(mut stream: UnixStream) -> std::io::Result<()> {
    stream.write_all(b"hello world")?;
    // TODO: expose something
    Ok(())
}

pub fn start_unix_listener() -> std::io::Result<()> {
    let socket_path = "sock";

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
                /* connection succeeded */
                thread::spawn(|| handle_client(stream));
            }
            Err(_) => {
                /* connection failed */
                break;
            }
        }
    }
    Ok(())
}