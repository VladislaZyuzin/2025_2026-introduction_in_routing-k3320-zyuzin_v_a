# Отчет по лабораторной работе №3

## Университет
* **University:** [ITMO University](https://itmo.ru/ru/)
* **Faculty:** [ФПиН](https://fict.itmo.ru)
* **Course:** [Introduction in routing](https://github.com/itmo-ict-faculty/introduction-in-routing)
* **Year:** 2025/2026
* **Group:** K3320
* **Author:** Zyuzin Vladislav Alexandrovich 
* **Lab:** Lab1
* **Date of create:** 10.11.2025
* **Date of finished:** 11.11.2025

## Задание

Вам необходимо сделать IP/MPLS сеть связи для "RogaIKopita Games" в ContainerLab. Необходимо создать все устройства, указанные на схеме и соединения между ними.

* Помимо этого вам необходимо настроить IP адреса на интерфейсах.
* Настроить OSPF и MPLS.
* Настроить EoMPLS.
* Назначить адресацию на контейнеры, связанные между собой EoMPLS.
* Настроить имена устройств, сменить логины и пароли.

<img width="713" height="391" alt="image" src="https://github.com/user-attachments/assets/4f66469f-e785-4add-bac0-ff7116762360" />

## Описание работы

Для выполнения работы была арендована VPS от провайдера HOSTKEY, которая работает на CentOS. На неё были установлены `docker`, `make` и `containerlab`, а также склонирован репозиторий `hellt/vrnetlab` (в папку routeros был загружен файл chr-6.47.9.vmdk). C помощью `make docker-image` был собран соответствуший образ.

### Немного теории

**MPLS (Multy Protocol Label Switching)** - это провайдерская сеть, которая нужна, чтобы трафик между узлами шёл быстрее и гибче по меткам. То есть сервера уже заранее знаю откуда им следует ждать и куда следуюет передавать пакеты данных. 
**OSPF** - прокаченный `RIPv2`, благодаря которому у роутеров есть точная карта маршрутизации, куда следует передавать данные
**EoMPLS / VPLS** - способ протянуть виртуальный эзер поверх MPLS. Он нужен чтобы соединить PC1 и SGI Prism, так, как если бы они были воткнуты в один свич.

### Топология

Топология сети для компании "RogaIKopita Games" организована для связи офисов в разных городах (Санкт-Петербург, Хельсинки, Москва, Лондон, Лиссабон и Нью-Йорк) с использованием маршрутизаторов MikroTik, объединённых через OSPF и MPLS. Основной целью сети является обеспечение возможности передачи данных между двумя конкретными устройствами — сервером `SGI Prism` (Нью-Йорк) и `PC1` (Санкт-Петербург) — для доступа к наработкам в области компьютерной графики. В основе организации сети лежит использование EoMPLS, что позволяет установить туннель второго уровня между этими устройствами, делая их частью одной и той же виртуальной локальной сети (L2VPN) поверх IP/MPLS инфраструктуры.

Сеть состоит из шести маршрутизаторов, каждый из которых закреплён за одним из городов и подключён к остальным через Ethernet-соединения, а также двух компьютеров на базе Linux.

```yaml
name: lab_3

mgmt: 
  network: static
  ipv4-subnet: 192.168.10.0/24

topology:
  kinds: 
    vr-mikrotik_ros: 
      image: vrnetlab/mikrotik_routeros:6.47.9
    linux: 
      image: alpine:latest
  nodes:
    R01.SPb:
      kind: vr-mikrotik_ros
      mgmt-ipv4: 192.168.10.11
      startup-config: configs/spb.rsc
    R01_HKI:
      kind: vr-mikrotik_ros
      mgmt-ipv4: 192.168.10.12
      startup-config: configs/hki.rsc
    R01_MSK:
      kind: vr-mikrotik_ros
      mgmt-ipv4: 192.168.10.13
      startup-config: configs/msk.rsc
    R01_LND:
      kind: vr-mikrotik_ros
      mgmt-ipv4: 192.168.10.14
      startup-config: configs/lnd.rsc
    R01_LBN:
      kind: vr-mikrotik_ros
      mgmt-ipv4: 192.168.10.15
      startup-config: configs/lbn.rsc
    R01_NY:
      kind: vr-mikrotik_ros
      mgmt-ipv4: 192.168.10.16
      startup-config: configs/ny.rsc
    PC1: 
      kind: linux
      binds: 
        - ./configs:/configs/
    SGI_PRISM:
      kind: linux
      binds: 
        - ./configs:/configs/    
  links: 
    - endpoints: ["R01.SPb:eth2", "R01_HKI:eth2"]
    - endpoints: ["R01.SPb:eth3", "R01_MSK:eth2"]
    - endpoints: ["R01.SPb:eth4", "PC1:eth2"] 
    - endpoints: ["R01_HKI:eth3", "R01_LND:eth2"]
    - endpoints: ["R01_HKI:eth4", "R01_LBN:eth2"]
    - endpoints: ["R01_LBN:eth3", "R01_MSK:eth3"]
    - endpoints: ["R01_LBN:eth4", "R01_NY:eth3"]
    - endpoints: ["R01_NY:eth2", "R01_LND:eth3"]
    - endpoints: ["R01_NY:eth4", "SGI_PRISM:eth2"]
```
Ниже можно ознакомиться с графическим представлением этой схемы:

![lab3-topology](https://github.com/user-attachments/assets/3904043b-9aaa-480c-8fe2-c5088b024a48)

### Настройка роутеров, ПК и тачки

Маршрутизаторы компании "RogaIKopita Games" настроены для объединения в единую `IP/MPLS-сеть`. Каждый из них подключён к своему региону, использует протокол OSPF для динамической маршрутизации и `MPLS` для передачи данных. Для организации туннеля второго уровня применяется технология `EoMPLS`, обеспечивающая связь между сервером `SGI Prism` в Нью-Йорке и `ПК` в Санкт-Петербурге. Базовые настройки маршрутизаторов включают конфигурацию интерфейсов, назначение IP-адресов и активацию `LDP (Label Distribution Protocol)` для обмена MPLS-метками.

Маршрутизатор `R01.SPb` выполняет роль узлового устройства офиса в Санкт-Петербурге. На нём включён `OSPF` с заданным router-id и настроен LDP для распространения меток MPLS. Также на маршрутизаторе развернут `DHCP-сервер` для `VPN-клиентов` и создан виртуальный интерфейс `VPLS`, обеспечивающий туннель к удалённому серверу в Нью-Йорке. Интерфейсы `eovpls` и `ether5` объединены в мост vpn.

Пример настройки `R01.SPb`:

```rsc
/interface bridge
add name=loopback  
add name=vpn
/interface vpls
add disabled=no l2mtu=1500 mac-address=02:D5:99:AF:81:85 name=eovpls remote-peer=172.16.6.2 vpls-id=65500:666
/ip pool
add name=dhcp_pool_vpn ranges=10.10.10.3-10.10.10.254
/ip dhcp-server
add address-pool=dhcp_pool_vpn disabled=no interface=vpn name=dhcp_vpn
/routing ospf instance
set [ find default=yes ] router-id=172.16.1.2
/interface bridge port
add bridge=vpn interface=ether5
add bridge=vpn interface=eovpls
/ip address
add address=172.16.1.2/32 interface=loopback network=172.16.1.2
add address=172.16.1.101/30 interface=ether3 network=172.16.1.100
add address=172.16.2.101/30 interface=ether4 network=172.16.2.100
add address=192.168.1.2/24 interface=ether5 network=192.168.1.0
add address=10.10.10.2/24 interface=vpn network=10.10.10.0
/ip dhcp-server network
add address=10.10.10.0/24 gateway=10.10.10.1
/mpls ldp
set enabled=yes lsr-id=172.16.1.2 transport-address=172.16.1.2
/mpls ldp interface
add interface=ether3
add interface=ether4
add interface=ether5
/routing ospf network
add area=backbone network=172.16.1.100/30
add area=backbone network=172.16.2.100/30
add area=backbone network=192.168.1.0/24
add area=backbone network=172.16.1.2/32
/system identity
set name=R01_SPB
```

Маршрутизатор `R01_NY` настроен для подключения к сети офиса в Нью-Йорке и взаимодействия с маршрутизатором `R01.SPb` через VPLS туннель. Включен OSPF с указанием `router-id` для идентификации, настроены интерфейсы `ether3` и `ether4` для связи с другими офисами. Создан `bridge vpn` для объединения VPLS-соединения с локальным сервером `SGI Prism`.

Пример настройки `R01_NY`:

```rsc
/interface bridge
add name=loopback
add name=vpn
/interface vpls
add disabled=no l2mtu=1500 mac-address=02:5C:67:11:1C:D6 name=eovpls remote-peer=172.16.1.2 vpls-id=65500:666
/routing ospf instance
set [ find default=yes ] router-id=172.16.6.2
/interface bridge port
add bridge=vpn interface=ether5
add bridge=vpn interface=eovpls
/ip address
add address=172.16.6.2/32 interface=loopback network=172.16.6.2
add address=172.16.6.102/30 interface=ether3 network=172.16.6.100
add address=172.16.7.102/30 interface=ether4 network=172.16.7.100
add address=192.168.2.1/30 interface=ether5 network=192.168.2.0
add address=10.10.10.1/24 interface=vpn network=10.10.10.0
/mpls ldp
set enabled=yes lsr-id=172.16.6.2 transport-address=172.16.6.2
/mpls ldp interface
add interface=ether3
add interface=ether4
add interface=ether5
/routing ospf network
add area=backbone network=172.16.6.100/30
add area=backbone network=172.16.7.100/30
add area=backbone network=172.16.6.2/32
/system identity
set name=R01_NY
```

Маршрутизаторы `R01_HKI`, `R01_MSK`, `R01_LND`, и `R01_LBN` настроены как промежуточные устройства, поддерживающие обмен данными между узловыми маршрутизаторами. На каждом маршрутизаторе включены OSPF и MPLS для динамической маршрутизации и распространения меток. Настроены интерфейсы с назначенными IP-адресами для маршрутизации трафика между различными офисами и реализации IP/MPLS сети, обеспечивающей стабильное соединение между офисами компании.

Пример настройки `R01_HKI`:

```rsc
/interface bridge
add name=loopback
/routing ospf instance
set [ find default=yes ] router-id=172.16.2.2
/ip address
add address=172.16.2.2/32 interface=loopback network=172.16.2.2
add address=172.16.1.102/30 interface=ether3 network=172.16.1.100
add address=172.16.3.101/30 interface=ether4 network=172.16.3.100
add address=172.16.4.101/30 interface=ether5 network=172.16.4.100
/mpls ldp
set enabled=yes lsr-id=172.16.2.2 transport-address=172.16.2.2
/mpls ldp interface
add interface=ether3
add interface=ether4
add interface=ether5
/routing ospf network
add area=backbone network=172.16.1.100/30
add area=backbone network=172.16.3.100/30
add area=backbone network=172.16.4.100/30
add area=backbone network=172.16.2.2/32
/system identity
set name=R01_HKI
```

Тачка в Нью-Йорке и PC в Питере сетапятся по общему конфигу. В нём предусмотрена раздача IP-адресов dhcp сервером для `eth2`, по которому данные эндпоинты выходят в сеть, так же при выдаче dhcp адреса предусмотрено удаление для эндпоинтов айпи `192.168.10.1`, чтобы никто не получил айпи адрес шлюза.

Скрипт для `pc.sh`

```bash
#!/bin/sh
udhcpc -i eth2
ip route del default via 192.168.10.1 dev eth0
```

<img width="1677" height="1609" alt="image" src="https://github.com/user-attachments/assets/c1f67a02-05ed-49dc-8e10-bf1a74c1b47e" />

<img width="1060" height="634" alt="image" src="https://github.com/user-attachments/assets/1bfa071b-1ad5-40f7-9608-9c994c4e8117" />

<img width="1545" height="826" alt="image" src="https://github.com/user-attachments/assets/46f2eca2-7f4e-4c8b-8196-87137e034674" />

<img width="1333" height="1179" alt="image" src="https://github.com/user-attachments/assets/bab92cdb-77cd-4d4e-b313-9f8a8069d4ca" />

<img width="1243" height="1343" alt="image" src="https://github.com/user-attachments/assets/6a424abb-f03b-4791-b252-262e1228eb36" />

<img width="1143" height="895" alt="image" src="https://github.com/user-attachments/assets/f6086430-cbbf-4bf1-9438-7380536bc9fa" />
