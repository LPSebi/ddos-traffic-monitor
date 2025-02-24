# DDoS Traffic Monitor & Alert System

![DDoS Monitoring](https://img.shields.io/badge/Status-Production%20Ready-green)
![Docker Support](https://img.shields.io/badge/Docker-Supported-blue)

Real-time network traffic monitoring solution with automated DDoS detection and Discord notifications.

## Key Features

- 🚨 Real-time bandwidth monitoring
- 📈 Traffic threshold alerts
- 📦 PCAP capture of suspicious traffic
- 📊 Automated vnstati graph generation
- 🤖 Discord integration for alerts
- 🐳 Docker container support
- 🔄 Automatic cleanup of old captures

## Prerequisites

### For Native Installation
- **Linux environment**
- Required packages:
  - `jq` - JSON processor for Discord webhooks
  - `curl` - Web requests for notifications
  - `vnstat` + `vnstati` - Traffic monitoring and graphing
  - `tcpdump` - Packet capture
  - `figlet` - ASCII header display

### For Docker Installation
- Docker Engine 20.10+
- Docker Compose 2.0+

## Installation

### Method 1: Docker (Recommended)
```bash
git clone https://github.com/yourrepo/ddos-warning.git
cd ddos-warning
cp .env.example .env
# Edit .env with your values
docker-compose up -d --build
```

### Method 2: Manual Setup
1. Install dependencies:
```bash
# Debian/Ubuntu
sudo apt install -y jq curl vnstat vnstati tcpdump figlet

# RHEL/CentOS
sudo yum install -y jq curl vnstat vnstati tcpdump figlet
```

2. Configure tcpdump permissions:
```bash
sudo setcap cap_net_raw,cap_net_admin=eip /usr/sbin/tcpdump
```

3. Clone and run:
```bash
git clone https://github.com/yourrepo/ddos-warning.git
cd ddos-warning
chmod +x ddoswarningbandwidth.sh
./ddoswarningbandwidth.sh <webhook> <interface> <maxspeed> <countpacket>
```

## Configuration

### Environment Variables
| Variable | Required | Description | Default |
|----------|----------|-------------|---------|
| `WEBHOOK` | Yes | Discord webhook URL | - |
| `INTERFACE` | Yes | Network interface to monitor | - |
| `MAX_SPEED` | Yes | Threshold (Mbit/s) for DDoS detection | - |
| `COUNT_PACKET` | Yes | Packets to capture during alert | - |
| `AVATAR` | No | Custom Discord bot avatar | - |
| `USERNAME` | No | Custom Discord bot username | "DDoS Monitor" |

Example `.env` file:
```env
WEBHOOK=https://discord.com/api/webhooks/...
INTERFACE=eth0
MAX_SPEED=150
COUNT_PACKET=5000
```

## Usage

### Start Monitoring
```bash
# Docker
docker-compose up -d

# Native
./ddoswarningbandwidth.sh <webhook> <interface> <maxspeed> <countpacket>
```

### View Logs
```bash
docker-compose logs -f
```

### Stop Service
```bash
docker-compose down
```

## Security Best Practices

1. Use a dedicated Discord webhook for monitoring
2. Regularly review stored PCAP files in `dumps/`
3. Restrict Docker container capabilities in production:
   ```yaml
   # In docker-compose.yml
   cap_drop:
     - ALL
   cap_add:
     - NET_ADMIN
     - NET_RAW
   ```
4. Run as non-root user when possible
5. Set appropriate directory permissions:
   ```bash
   chmod 700 dumps/
   ```

## Troubleshooting

**Q**: Permission denied for tcpdump
- **Fix**: `sudo setcap cap_net_raw,cap_net_admin=eip /usr/sbin/tcpdump`

**Q**: Interface not found
- Verify interface name with `ip link show`

**Q**: Missing vnstati graphs
- Ensure vnstat service is running: `sudo systemctl start vnstat`

**Q**: Discord alerts not working
- Test webhook with: `curl -X POST -H "Content-Type: application/json" -d '{"content":"test"}' $WEBHOOK`

## License

MIT License - See [LICENSE](LICENSE) file
