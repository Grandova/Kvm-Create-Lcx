#!/bin/bash


# 打印信息
_red() { echo -e "\033[31m\033[01m$@\033[0m"; }
_green() { echo -e "\033[32m\033[01m$@\033[0m"; }
_yellow() { echo -e "\033[33m\033[01m$@\033[0m"; }
_blue() { echo -e "\033[36m\033[01m$@\033[0m"; }
reading(){ read -rp "$(_green "$1")" "$2"; }
export DEBIAN_FRONTEND=noninteractive
utf8_locale=$(locale -a 2>/dev/null | grep -i -m 1 -E "UTF-8|utf8")
if [[ -z "$utf8_locale" ]]; then
  echo "No UTF-8 locale found"
else
  export LC_ALL="$utf8_locale"
  export LANG="$utf8_locale"
  export LANGUAGE="$utf8_locale"
  echo "Locale set to $utf8_locale"
fi

rm -rf /root/build_backend_pve.txt

# 查询信息
if ! command -v lshw > /dev/null 2>&1; then
      apt-get install -y lshw
fi
# 提取物理网卡名字
interface_1=$(lshw -C network | awk '/logical name:/{print $3}' | head -1)
interface_2=$(lshw -C network | awk '/logical name:/{print $3}' | sed -n '2p')
if [ -z "$interface_1" ]; then
  interface="eth0"
fi
if ! grep -q "$interface_1" "/etc/network/interfaces"; then
    if [ -f "/etc/network/interfaces.d/50-cloud-init" ];then
        if ! grep -q "$interface_1" "/etc/network/interfaces.d/50-cloud-init" && grep -q "$interface_2" "/etc/network/interfaces.d/50-cloud-init"; then
            interface=${interface_2}
        else
            interface=${interface_1}
        fi
    else
        if grep -q "$interface_2" "/etc/network/interfaces"; then
            interface=${interface_2}
        else
            interface=${interface_1}
        fi
    fi
else
    interface=${interface_1}
fi
# 提取IPV4地址
ipv4_address=$(ip addr show | awk '/inet .*global/ && !/inet6/ {print $2}')
# 提取IPV4网关
gateway=$(ip route | awk '/default/ {print $3}')
# 获取IPV6子网前缀
SUBNET_PREFIX=$(ip -6 addr show | grep -E 'inet6.*global' | awk '{print $2}' | awk -F'/' '{print $1}' | head -n 1 | rev | cut -d ':' -f 2- | rev):0
# 提取IPV6地址
ipv6_address=$(ip addr show | awk '/inet6.*scope global/ { print $2 }' | head -n 1)
# 检查是否存在 IPV6 
if [ -z "$SUBNET_PREFIX" ] || [ "$SUBNET_PREFIX" = ":0" ]; then
    _red "No IPV6 subnet, no automatic mapping"
    _red "无 IPV6 子网，不进行自动映射"
else
    _blue "The IPV6 subnet prefix of the host is $SUBNET_PREFIX"
    _blue "母鸡的IPV6子网前缀为 $SUBNET_PREFIX"
fi
if [ -z "$ipv6_address" ]; then
    _red "No IPV6 address on the parent machine, no automatic mapping"
    _red "母机无 IPV6 地址，不进行自动映射"
else
    _blue "The IPV6 address of the host is $ipv6_address"
    _blue "母鸡的IPV6地址为 $ipv6_address"
fi

# 录入网关
if [ -f /etc/network/interfaces ]; then
    cp /etc/network/interfaces /etc/network/interfaces.bak
fi
# 修正部分网络设置重复的错误
if [[ -f "/etc/network/interfaces.d/50-cloud-init" && -f "/etc/network/interfaces" ]]; then
    if grep -q "auto lo" "/etc/network/interfaces.d/50-cloud-init" && grep -q "iface lo inet loopback" "/etc/network/interfaces.d/50-cloud-init" && grep -q "auto lo" "/etc/network/interfaces" && grep -q "iface lo inet loopback" "/etc/network/interfaces"; then
        # 从 /etc/network/interfaces.d/50-cloud-init 中删除重复的行
        chattr -i /etc/network/interfaces.d/50-cloud-init
        sed -i '/auto lo/d' "/etc/network/interfaces.d/50-cloud-init"
        sed -i '/iface lo inet loopback/d' "/etc/network/interfaces.d/50-cloud-init"
        chattr +i /etc/network/interfaces.d/50-cloud-init
    fi
fi
if [ -f "/etc/network/interfaces.new" ];then
    chattr -i /etc/network/interfaces.new
    rm -rf /etc/network/interfaces.new
fi
interfaces_file="/etc/network/interfaces"
chattr -i "$interfaces_file"
if ! grep -q "auto lo" "$interfaces_file"; then
#     echo "auto lo" >> "$interfaces_file"
    _blue "Can not find 'auto lo' in ${interfaces_file}"
    exit 1
fi
if ! grep -q "iface lo inet loopback" "$interfaces_file"; then
#     echo "iface lo inet loopback" >> "$interfaces_file"
    _blue "Can not find 'iface lo inet loopback' in ${interfaces_file}"
    exit 1
fi
if grep -q "vmbr0" "$interfaces_file"; then
    _blue "vmbr0 already exists in ${interfaces_file}"
    _blue "vmbr0 已存在在 ${interfaces_file}"
else
if [ -z "$SUBNET_PREFIX" ] || [ "$SUBNET_PREFIX" = ":0" ] || [ -z "$ipv6_address" ]; then
cat << EOF | sudo tee -a "$interfaces_file"
auto vmbr0
iface vmbr0 inet static
    address $ipv4_address
    gateway $gateway
    bridge_ports $interface
    bridge_stp off
    bridge_fd 0
EOF
elif [ -f "/root/iface_auto.txt" ]; then
cat << EOF | sudo tee -a "$interfaces_file"
auto vmbr0
iface vmbr0 inet static
    address $ipv4_address
    gateway $gateway
    bridge_ports $interface
    bridge_stp off
    bridge_fd 0

iface vmbr0 inet6 auto
    bridge_ports $interface
EOF
else
cat << EOF | sudo tee -a "$interfaces_file"
auto vmbr0
iface vmbr0 inet static
    address $ipv4_address
    gateway $gateway
    bridge_ports $interface
    bridge_stp off
    bridge_fd 0

iface vmbr0 inet6 static
        address ${ipv6_address}
        gateway ${SUBNET_PREFIX}
EOF
fi
fi
if grep -q "vmbr1" "$interfaces_file"; then
    _blue "vmbr1 already exists in ${interfaces_file}"
    _blue "vmbr1 已存在在 ${interfaces_file}"
elif [ -f "/root/iface_auto.txt" ]; then
cat << EOF | sudo tee -a "$interfaces_file"
auto vmbr1
iface vmbr1 inet static
    address 172.16.1.1
    netmask 255.255.255.0
    bridge_ports none
    bridge_stp off
    bridge_fd 0
    post-up echo 1 > /proc/sys/net/ipv4/ip_forward
    post-up echo 1 > /proc/sys/net/ipv4/conf/vmbr1/proxy_arp
    post-up iptables -t nat -A POSTROUTING -s '172.16.1.0/24' -o vmbr0 -j MASQUERADE
    post-down iptables -t nat -D POSTROUTING -s '172.16.1.0/24' -o vmbr0 -j MASQUERADE

pre-up echo 2 > /proc/sys/net/ipv6/conf/vmbr0/accept_ra
EOF
else
cat << EOF | sudo tee -a "$interfaces_file"
auto vmbr1
iface vmbr1 inet static
    address 172.16.1.1
    netmask 255.255.255.0
    bridge_ports none
    bridge_stp off
    bridge_fd 0
    post-up echo 1 > /proc/sys/net/ipv4/ip_forward
    post-up echo 1 > /proc/sys/net/ipv4/conf/vmbr1/proxy_arp
    post-up iptables -t nat -A POSTROUTING -s '172.16.1.0/24' -o vmbr0 -j MASQUERADE
    post-down iptables -t nat -D POSTROUTING -s '172.16.1.0/24' -o vmbr0 -j MASQUERADE
EOF
fi
chattr +i "$interfaces_file"
rm -rf /root/iface_auto.txt

# 加载iptables并设置回源且允许NAT端口转发
apt-get install -y iptables iptables-persistent
iptables -t nat -A POSTROUTING -j MASQUERADE
sysctl net.ipv4.ip_forward=1
sysctl_path=$(which sysctl)
if grep -q "^net.ipv4.ip_forward=1" /etc/sysctl.conf; then
  if grep -q "^#net.ipv4.ip_forward=1" /etc/sysctl.conf; then
    sed -i 's/^#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf
  fi
else
    echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
fi
${sysctl_path} -p

# 重启配置
service networking restart
systemctl restart networking.service
sleep 3
ifreload -ad
# 已加载网络，删除对应缓存文件
if [ -f "/etc/network/interfaces.new" ];then
    chattr -i /etc/network/interfaces.new
    rm -rf /etc/network/interfaces.new
fi
systemctl start check-dns.service
# _green "Although the gateway has been set automatically, I am not sure if it has been applied successfully, please check in Datacenter-->pve-->System-->Network in PVE"
# _green "If vmbr0 and vmbr1 are displayed properly and the Apply Configuration button is grayed out, there is no need to reboot"
# _green "If the above scenario is different, click on the Apply Configuration button, wait a few minutes and reboot the system to ensure that the gateway has been successfully applied"
_green "you can test open a virtual machine or container to see if the actual network has been applied successfully"
# _green "虽然已自动设置网关，但不确定是否已成功应用，请查看PVE中的 Datacenter-->pve-->System-->Network"
# _green "如果 vmbr0 和 vmbr1 已正常显示且 Apply Configuration 这个按钮是灰色的，则不用执行 reboot 重启系统"
# _green "上述情形如果有不同的，请点击 Apply Configuration 这个按钮，等待几分钟后重启系统，确保网关已成功应用"
_green "你可以测试开一个虚拟机或者容器看看就知道是不是实际网络已应用成功了"
