# Отчет по лабораторной работе №4

## Университет
University: [ITMO University](https://itmo.ru/ru/)<br />
Faculty: [FICT](https://fict.itmo.ru)<br />
Course: [Introduction in routing](https://github.com/itmo-ict-faculty/introduction-in-routing)<br />
Year: 2025/2026<br />
Group: K3320<br />
Author: Zyuzin Vladislav Alexandrovich<br />
Lab: Lab4<br />
Date of create: 18.11.2025<br />
Date of finished: 19.11.2025<br />

## Задание

Вам необходимо сделать IP/MPLS сеть связи для "RogaIKopita Games" в ContainerLab. Необходимо создать все устройства указанные на схеме, и соединения между ними.

Первая часть:

* Настроить iBGP RR Cluster;
* Настроить VRF на 3 роутерах;
* Настроить RD и RT на 3 роутерах;
* Настроить IP адреса в VRF;
* Проверить связность между VRF;
* Настроить имена устройств, сменить логины и пароли.

Вторая часть:

* Разобрать VRF на 3 роутерах (или отвязать их от интерфейсов);
* Настроить VPLS на 3 роутерах;
* Настроить IP адресацию на PC1,2,3 в одной сети;
* Проверить связность.

![Схема из задания](images/ip_mpls_ibgp.png)

## Описание работы

Для выполнения работы была арендована виртуальная машина в hostkey.ru. На неё были установлены `docker`, `make` и `containerlab`, а также склонирован репозиторий `hellt/vrnetlab` (в папку routeros был загружен файл chr-6.47.9.vmdk). C помощью `make docker-image` был собран соответствуший образ.

### Топология 

В рамках лабораторной работы реализована топология сети для компании "RogaIKopita Games" с использованием платформы ContainerLab. В сети используются маршрутизаторы Mikrotik RouterOS (`R01_spb`, `R01_hki`, `R01_lbn`, `R01_lnd`, `R01_svl`, `R01_ny`) и конечные устройства на базе Linux (`PC1`, `PC2`, `PC3`). Устройства соединены в соответствии с заданной схемой, обеспечивая связность между офисами компании и подключение хостов для проверки настроек. Для управления сетью используется подсеть `192.168.50.0/24`, с назначением уникальных IP-адресов для каждого маршрутизатора. Топология поддерживает реализацию IP/MPLS с VRF на первом этапе и VPLS на втором, что обеспечивает выполнение всех требований задания.

```yaml
name: lab4-part1
mgmt:
  network: custom_mgmt
  ipv4-subnet: 172.16.16.0/24

topology:
  kinds:
    vr-ros:
      image: vrnetlab/mikrotik_routeros:6.47.9

  nodes:
    R01.SPB:
      kind: vr-ros
      mgmt-ipv4: 172.16.16.101
      startup-config: config/part1/r01-spb.rsc
    R01.HKI:
      kind: vr-ros
      mgmt-ipv4: 172.16.16.102
      startup-config: config/part1/r01-hki.rsc
    R01.SVL:
      kind: vr-ros
      mgmt-ipv4: 172.16.16.103
      startup-config: config/part1/r01-svl.rsc
    R01.LND:
      kind: vr-ros
      mgmt-ipv4: 172.16.16.104
      startup-config: config/part1/r01-lnd.rsc
    R01.LBN:
      kind: vr-ros
      mgmt-ipv4: 172.16.16.105
      startup-config: config/part1/r01-lbn.rsc
    R01.NY:
      kind: vr-ros
      mgmt-ipv4: 172.16.16.106
      startup-config: config/part1/r01-ny.rsc
    PC1:
      kind: linux
      image: alpine:latest
      mgmt-ipv4: 172.16.16.2
      binds:
        - ./config:/config
    PC2:
      kind: linux
      image: alpine:latest
      mgmt-ipv4: 172.16.16.3
      binds:
        - ./config:/config
    PC3:
      kind: linux
      image: alpine:latest
      mgmt-ipv4: 172.16.16.4
      binds:
        - ./config:/config


  links:
    - endpoints: ["R01.SPB:eth1","R01.HKI:eth1"]
    - endpoints: ["R01.NY:eth1","R01.LND:eth1"]
    - endpoints: ["R01.SVL:eth1","R01.LBN:eth1"]
    - endpoints: ["R01.HKI:eth2","R01.LND:eth3"]
    - endpoints: ["R01.HKI:eth3","R01.LBN:eth2"]
    - endpoints: ["R01.LND:eth2","R01.LBN:eth3"]
    - endpoints: ["R01.SPB:eth2","PC1:eth1"]
    - endpoints: ["R01.NY:eth2","PC2:eth1"]
    - endpoints: ["R01.SVL:eth2","PC3:eth1"]
```

Ниже можно ознакомиться с графическим представлением этой схемы:

<img width="1101" height="690" alt="graph-1" src="https://github.com/user-attachments/assets/fb58e28b-234f-4588-9d65-19a16aad4628" />

