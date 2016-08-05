# Fw-manager

fw-manager - manager of iptables configurations.
The main purpose - quickly and safely apply the rules of iptables.


## Requirements

    bash git iptables


## Installing

### Manual install

    git clone https://github.com/kirillsev/fw-manager.git /opt/fw-manager
    cp /opt/fw-manager/fw-manager.conf.sample /opt/fw-manager/fw-manager.conf
    ln -s /opt/fw-manager/fw-manager.sh /usr/bin/fw-manager
    mkdir /var/log/fw-manager


## Configuring

Set the parameters:

    editor /opt/fw-manager/fw-manager.conf


## Usage

Get help information:

    fw-manager help


## License

MIT
