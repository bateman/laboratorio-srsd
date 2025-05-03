# Laboratorio VPN con Strongswan e Docker

Questo repository contiene i file necessari per configurare un ambiente di laboratorio per la creazione di una VPN utilizzando Strongswan e IKEv2 attraverso container Docker.

## Descrizione

Questo laboratorio permette di esplorare la configurazione di una connessione VPN sicura utilizzando il protocollo IPsec con IKEv2. Vengono utilizzati due container Docker per simulare:
- Un server VPN (strongSwan)
- Un client VPN che si connette al server

L'implementazione utilizza certificati digitali per l'autenticazione del server e credenziali EAP-MSCHAPv2 per l'autenticazione del client.

## Struttura del Repository

```
vpn
├── client
│   ├── Dockerfile
│   │   ├── ipsec.conf
│   │   └── ipsec.secrets
│   ├── docker-compose.yml
│   ├── scripts
│   │   └── start.sh
│   └── setup-clean.sh
└── server
    ├── Dockerfile
    ├── config
    │   ├── ipsec.conf
    │   ├── ipsec.secrets
    ├── docker-compose.yml
    └── scripts
        └── start.sh
```

## Architettura di Rete

```
┌────────────────┐                           ┌────────────────┐
│                │                           │                │
│    Client VPN  │       Tunnel IPsec        │   Server VPN   │
│                │<=========================>│                │
│  172.20.0.3    │                           │  172.20.0.2    │
│                │                           │                │
└────────────────┘                           └────────────────┘
       │                                            │
       │                                            │
       │                                            │
       └───────────────┐              ┌─────────────┘
                       │              │
                       ▼              ▼
                 ┌────────────────────────────┐
                 │                            │
                 │     Rete Docker interna    │
                 │       172.20.0.0/24        │
                 │                            │
                 └────────────────────────────┘
```

## Prerequisiti

- Docker Engine
- Docker Compose


## Note Didattiche

Seguite le slide del `Capitolo 9 -- sicurezza livello rete` per istruzioni su configurazione ed esecuzione.
