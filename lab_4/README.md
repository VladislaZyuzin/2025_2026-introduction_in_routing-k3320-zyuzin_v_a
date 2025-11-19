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

### Часть 1

#### Настройка маршрутизаторов

На маршрутизаторах, подключенных напрямую к конечным устройствам (например, R01_spb), настроены loopback-интерфейсы, BGP и OSPF для маршрутизации, а также DHCP-серверы для раздачи IP-адресов конечным устройствам. Для поддержки VRF настроены VRF-экспорт/импорт RT и RD, а также привязка интерфейсов и маршрутов. MPLS включен с настройкой LDP на соответствующих интерфейсах. BGP-пиры устанавливаются для обмена маршрутизационной информацией, включая VPNv4. OSPF обеспечивает связность в зоне backbone. Такая конфигурация позволяет маршрутизатору интегрироваться в IP/MPLS сеть и обслуживать трафик от конечных хостов.

Пример настройки `R01_spb`:
```
/system identity
set name=R01.SPB

/ip address
add address=10.20.1.1/30 interface=ether2
add address=192.168.10.1/24 interface=ether3

/ip pool
add name=dhcp-pool ranges=192.168.10.10-192.168.10.100
/ip dhcp-server
add address-pool=dhcp-pool disabled=no interface=ether3 name=dhcp-server
/ip dhcp-server network
add address=192.168.10.0/24 gateway=192.168.10.1

/interface bridge
add name=loopback
/ip address 
add address=10.255.255.1/32 interface=loopback network=10.255.255.1

/routing ospf instance
add name=inst router-id=10.255.255.1
/routing ospf area
add name=backbonev2 area-id=0.0.0.0 instance=inst
/routing ospf network
add area=backbonev2 network=10.20.1.0/30
add area=backbonev2 network=192.168.10.0/24
add area=backbonev2 network=10.255.255.1/32

/mpls ldp
set lsr-id=10.255.255.1
set enabled=yes transport-address=10.255.255.1
/mpls ldp interface
add interface=ether2

/routing bgp instance
set default as=65000 router-id=10.255.255.1
/routing bgp peer
add name=peerHKI remote-address=10.255.255.2 address-families=l2vpn,vpnv4 remote-as=65000 update-source=loopback route-reflect=no 
/routing bgp network
add network=10.255.255.0/24

/interface bridge 
add name=br100
/ip address
add address=10.100.1.1/32 interface=br100
/ip route vrf
add export-route-targets=65000:100 import-route-targets=65000:100 interfaces=br100 route-distinguisher=65000:100 routing-mark=VRF_DEVOPS
/routing bgp instance vrf
add redistribute-connected=yes routing-mark=VRF_DEVOPS
```

Маршрутизаторы, входящие в iBGP RR-кластер (например, R01_hki), выполняют функции Route Reflector и настроены для обеспечения масштабируемости BGP-сессий. На каждом маршрутизаторе создаются loopback-интерфейсы и назначается уникальный Router ID. Конфигурируются OSPF и MPLS с активацией LDP на всех межузловых соединениях. Устанавливаются BGP-сессии с соседними устройствами, с указанием роли Route Reflector для необходимых пиров. Это обеспечивает эффективное распространение маршрутов между всеми узлами сети. Настройки OSPF включают подключение всех сетей маршрутизатора к зоне backbone, обеспечивая полную связность.

Пример настройки `R01_hki`:
```
/system identity
set name=R01.HKI

/ip address
add address=10.20.1.2/30 interface=ether2
add address=10.20.11.1/30 interface=ether3
add address=10.20.12.2/30 interface=ether4

/interface bridge
add name=loopback
/ip address 
add address=10.255.255.2/32 interface=loopback network=10.255.255.2

/routing ospf instance
add name=inst router-id=10.255.255.2
/routing ospf area
add name=backbonev2 area-id=0.0.0.0 instance=inst
/routing ospf network
add area=backbonev2 network=10.20.1.0/30
add area=backbonev2 network=10.20.11.0/30
add area=backbonev2 network=10.20.12.0/30
add area=backbonev2 network=10.255.255.2/32

/mpls ldp
set lsr-id=10.255.255.2
set enabled=yes transport-address=10.255.255.2
/mpls ldp interface
add interface=ether2
add interface=ether3
add interface=ether4

/routing bgp instance
set default as=65000 router-id=10.255.255.2
/routing bgp peer
add name=peerSPB address-families=l2vpn,vpnv4 remote-address=10.255.255.1 remote-as=65000 update-source=loopback route-reflect=no
add name=peerLND address-families=l2vpn,vpnv4 remote-address=10.255.255.4 remote-as=65000 update-source=loopback route-reflect=yes
add name=peerLBN address-families=l2vpn,vpnv4 remote-address=10.255.255.5 remote-as=65000 update-source=loopback route-reflect=yes
/routing bgp network
add network=10.255.255.0/24
```

#### Настройка ПК

На каждом ПК был настроен DHCP-клиент для получения IP-адреса от соответствующего маршрутизатора, а также удалён дефолтный маршрут через сеть управления, чтобы трафик корректно шёл через рабочие интерфейсы сети. Настройки позволили ПК взаимодействовать с другими устройствами в сети.

Пример настройки PC:
```
#!/bin/sh
udhcpc -i eth2
ip route del default via 192.168.50.1 dev eth0
```

#### Пример работы

Для того, чтобы удостовериться в правильности написанных конфигураций - проверим, как роутеры через bgp видят друг друга, для этого - введём команду: 

```rsc
ip route print where bgp
```

После - проверим, как эндпоинты видят друг друга через vfs: 

```rsc
ip route print where routing-mark=VRF_DEVOPS
```
Когда мы увидели, что шлюзы наших ПК отображаются - то их нужно пропинговать: 

```rsc
ping 10.100.1.x routing-table=VRF_DEVOPS src=10.100.1.1 c=3
```

<img width="984" height="565" alt="image" src="https://github.com/user-attachments/assets/bd87da66-733b-463e-b217-9ef17e0819de" />

### Часть 2

#### Настройка маршрутизаторов

На внешних маршрутизаторах (например, R01_spb) была выполнена отвязка VRF от интерфейсов и маршрутов. Для организации VPLS создан мост, в который включён интерфейс, связанный с конечными устройствами. Настроен BGP-VPLS с указанием RT, RD и site-id, чтобы обеспечить туннелирование через MPLS. Добавлен IP-адрес из общей сети на интерфейс VPLS, а также переработаны DHCP-настройки: создан новый пул адресов, ориентированный на VPLS, и включен DHCP-сервер для раздачи адресов клиентам. Это позволяет устройствам в одной сети подключаться через туннели VPLS.

Пример настройки `R01_spb` 
```rsc
/system identity
set name=R01.SPB

/ip address
add address=10.20.1.1/30 interface=ether2
add address=192.168.10.1/24 interface=ether3

/interface bridge
add name=loopback
/ip address 
add address=10.255.255.1/32 interface=loopback network=10.255.255.1

/routing ospf instance
add name=inst router-id=10.255.255.1
/routing ospf area
add name=backbonev2 area-id=0.0.0.0 instance=inst
/routing ospf network
add area=backbonev2 network=10.20.1.0/30
add area=backbonev2 network=192.168.10.0/24
add area=backbonev2 network=10.255.255.1/32

/mpls ldp
set lsr-id=10.255.255.1
set enabled=yes transport-address=10.255.255.1
/mpls ldp interface
add interface=ether2
add interface=ether3

/routing bgp instance
set default as=65000 router-id=10.255.255.1
/routing bgp peer
add name=peerHKI remote-address=10.255.255.2 address-families=l2vpn,vpnv4 remote-as=65000 update-source=loopback route-reflect=no 
/routing bgp network
add network=10.255.255.0/24

/interface bridge
add name=vpn
/interface bridge port
add interface=ether3 bridge=vpn
/interface vpls bgp-vpls
add bridge=vpn export-route-targets=65000:100 import-route-targets=65000:100 name=vpn route-distinguisher=65000:100 site-id=1
/ip address
add address=10.100.1.1/24 interface=vpn

/ip pool
add name=vpn-dhcp-pool ranges=10.100.1.100-10.100.1.254
/ip dhcp-server
add address-pool=vpn-dhcp-pool disabled=no interface=vpn name=dhcp-vpls
/ip dhcp-server network
add address=10.100.1.0/24 gateway=10.100.1.1
```

Маршрутизаторы iBGP-RR (например, R01_hki) были перенастроены для работы с VPLS, что включало удаление старых BGP-сессий и добавление новых с поддержкой l2vpn. Эти изменения обеспечивают распространение VPLS-маршрутов между узлами сети через Route Reflector. Настройка каждого пиринга выполняется с указанием loopback-адресов и соответствующих параметров для организации туннелей MPLS. Такая конфигурация позволяет поддерживать VPLS в масштабируемой BGP-инфраструктуре и обеспечивает связность между узлами.

Пример настройки `R01_hki`
```rsc
/system identity
set name=R01.HKI

/ip address
add address=10.20.1.2/30 interface=ether2
add address=10.20.11.1/30 interface=ether3
add address=10.20.12.2/30 interface=ether4

/interface bridge
add name=loopback
/ip address 
add address=10.255.255.2/32 interface=loopback network=10.255.255.2

/routing ospf instance
add name=inst router-id=10.255.255.2
/routing ospf area
add name=backbonev2 area-id=0.0.0.0 instance=inst
/routing ospf network
add area=backbonev2 network=10.20.1.0/30
add area=backbonev2 network=10.20.11.0/30
add area=backbonev2 network=10.20.12.0/30
add area=backbonev2 network=10.255.255.2/32

/mpls ldp
set lsr-id=10.255.255.2
set enabled=yes transport-address=10.255.255.2
/mpls ldp interface
add interface=ether2
add interface=ether3
add interface=ether4

/routing bgp instance
set default as=65000 router-id=10.255.255.2
/routing bgp peer
add name=peerSPB address-families=l2vpn,vpnv4 remote-address=10.255.255.1 remote-as=65000 update-source=loopback route-reflect=no
add name=peerLND address-families=l2vpn,vpnv4 remote-address=10.255.255.4 remote-as=65000 update-source=loopback route-reflect=yes
add name=peerLBN address-families=l2vpn,vpnv4 remote-address=10.255.255.5 remote-as=65000 update-source=loopback route-reflect=yes
/routing bgp network
add network=10.255.255.0/24
```

#### Пример работы

Раздадим айпишники через dhcp сервер в роутере в СПб 

<img width="850" height="162" alt="image" src="https://github.com/user-attachments/assets/12a272e8-b730-40be-8cf6-46a898393b85" />

Для окончательной проверки работы сети использовалась команда `ping`, отправленная с `PC1` в офисе Санкт-Петербурга до остальных компьютеров в Севилье и Нью-Йорке. Обе проверки продемонстрировали успешное прохождение ICMP-пакетов, что подтверждает работоспособность туннеля и IP-соединения между двумя узлами:

<img width="853" height="1165" alt="image" src="https://github.com/user-attachments/assets/0cddcb39-62de-4955-909b-34880b31107c" />

## Заключение

В ходе работы была создана IP/MPLS сеть связи. На нём были настроены протоколы OSPF, MPLS и iBGP с Route Reflector-кластером.

В 1-й части был настроен L3VPN, используя VRF, в 2-й части был настроен VPLS.

Все устройства были успешно соединены, задачи работы выполнены.

Цель работы была выполнена.
