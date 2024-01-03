## Kvm-Create-Lcx

###### Creating a virtual machine in Lcx container format using Kvm virtualized servers

![](https://pve.proxmox.com/mediawiki/resources/assets/proxmox_logo.png?ffc80)

<img src="https://pve.proxmox.com/mediawiki/images/thumb/a/a3/Proxmox-VE-Cluster-Summary.png/576px-Proxmox-VE-Cluster-Summary.png"  />

If you don't have enough funds to afford a physical server, you happen to have a VPS.Then you can install PVE on your VPS to create a virtual machine in LCX format.

INSTALLATION REQUIREMENTS :

Core>2<br>
Memory>2G<br>
Storage>20G

1. Check VPS configuration requirements

   ```bash
   bash <(wget -qO- --no-check-certificate https://raw.githubusercontent.com/Grandova/Kvm-Create-Lcx/main/check_core.sh)
   ```

2. Install Proxmox Dashboard, After executing, reboot and execute again

   ```bash
   curl -L https://raw.githubusercontent.com/Grandova/Kvm-Create-Lcx/main/install_pve.sh -o install_pve.sh && chmod +x install_pve.sh && bash install_pve.sh
   ```

3. Build the required environment

   ```bash
   bash <(wget -qO- --no-check-certificate https://raw.githubusercontent.com/Grandova/Kvm-Create-Lcx/main/src/build_backend.sh)
   ```

4. The network card environment required to build a Nat network

   ```bash
   bash <(wget -qO- --no-check-certificate https://raw.githubusercontent.com/Grandova/Kvm-Create-Lcx/main/src/build_nat_network.sh)
   ```
