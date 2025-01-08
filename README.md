# Gateway Traffic Router

This project is designed to route all HTTP and HTTPS traffic from the local machine through a layered proxy setup, leveraging `redsocks` and `xray-core`.
The setup pairs up with an **xray server** configured for **VLESS** proxying with **Reality** camouflage.

## How Traffic is Routed
1. **Local Machine**: All HTTP and HTTPS traffic is redirected with **iptables** to `redsocks`.
2. **Redsocks**: Routes traffic to the local `xray-core` instance using **SOCKS5**.
3. **Xray-Core**: Processes the traffic and forwards it to the remote proxy server using **VLESS** with Reality camouflage.


## Requirements
- **Redsocks**: Must be installed. Path to binary must be set in .env (`https://github.com/XTLS/Xray-core`)
- **Xray-Core**: Must be installed. Path to binary must be set in .env (`https://github.com/darkk/redsocks`)
- **envsubst**: Must be installed.
- **Root Privileges**: The script requires superuser access to access **iptables**.


## Setup and Usage

1. Clone the repository:
```bash
git clone https://github.com/VladIakimenko/redsocks-xray-client
cd gateway
```

2. Copy the .env.example file and configure it:

```bash
cp .env.example .env
```


3. Start the service:

```bash
sudo ./start.sh
```

    This will:
        Generate configuration files for redsocks and xray-core using .env variables.
        Configure iptables to redirect traffic through redsocks.
        Start both redsocks and xray-core.

    Logs:
        Redsocks: logs/redsocks.log
        Xray-Core: logs/xray-core.log


## Notes

- Ensure your xray server is configured to accept VLESS connections with Reality camouflage at the specified IP and port.  
`https://github.com/VladIakimenko/3x-ui`
`https://pikabu.ru/story/nastraivaem_server_i_klient_vps_3xui_xray_s_xtlsrealitycdn_i_warp_podrobnyiy_razbor_i_kak_yeto_vsyo_organizovat_12169158`

- To stop the service and restore the original iptables configuration, press Ctrl+C or terminate the script. The cleanup function will automatically restore settings.
