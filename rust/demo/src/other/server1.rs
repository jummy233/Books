use std::io::{Error, Read};
use std::net::{Ipv4Addr, SocketAddrV4, TcpListener};

fn run() -> Result<(), Error> {
    let loopback = Ipv4Addr::new(127, 0, 0, 1);
    let socket = SocketAddrV4::new(loopback, 0);
    let listener = TcpListener::bind(socket)?;
    let port = listener.local_addr()?;

    println!(
        "Listening on {}, access thisport to enable the program.",
        port
    );
    let (mut tcp_stream, addr) = listener.accept()?;
    println!("Connection received {:?} is sending data.", addr);

    let mut input = String::new();

    let _ = tcp_stream.read_to_string(&mut input);
    println!("{:?} says {}", addr, input);
    Ok(())
}

#[cfg(test)]
mod test {
    use super::*;

    #[test]
    fn test1() {
        run();
    }
}
