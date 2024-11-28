#!/bin/bash

echo "*** Update and Upgrade ***"
apt update -y && apt upgrade -y
echo "Update and Upgrade finish ***"

echo "*** Install linux-image-amd64 ***"
sudo apt install linux-image-amd64
echo "Install linux-image-amd64 finish ***"

echo "*** Reinstall initramfs-tools ***"
sudo apt install --reinstall initramfs-tools
echo "Reinstall initramfs-tools finish ***"

echo "*** Install grub2, wimtools, ntfs-3g ***"
apt install grub2 wimtools ntfs-3g -y
echo "Install grub2, wimtools, ntfs-3g finish ***"

echo "*** Get the disk size in GB and convert to MB ***"
disk_size_gb=$(parted /dev/sda --script print | awk '/^Disk \/dev\/sda:/ {print int($3)}')
disk_size_mb=$((disk_size_gb * 1024))
echo "Get the disk size in GB and convert to MB finish ***"

echo "*** Calculate partition size (50% of total size) ***"
part_size_mb=$((disk_size_mb / 2))
echo "Calculate partition size (50% of total size) finish ***"

echo "*** Create GPT partition table ***"
parted /dev/sda --script -- mklabel gpt
echo "Create GPT partition table finish ***"

echo "*** Create two partitions ***"
parted /dev/sda --script -- mkpart primary ntfs 1MB ${part_size_mb}MB
echo "Create first partitions"
parted /dev/sda --script -- mkpart primary ntfs ${part_size_mb}MB 100%
echo "Create second partitions"
echo "Create two partitions finish ***"

echo "*** Inform kernel of partition table changes ***"
partprobe /dev/sda
sleep 60

partprobe /dev/sda
sleep 60

partprobe /dev/sda
sleep 60
echo "Inform kernel of partition table changes"

# echo "*** Verify partitions ***"
# fdisk -l /dev/sda
# echo "Verify partitions finish ***"

# Check if partitions are created and formatted successfully
echo "*** Check if partitions are created and formatted successfully ***"
if lsblk /dev/sda1 && lsblk /dev/sda2; then
    echo "Check if partitions are created and formatted successfully finish ***"
else
    echo "Error: Partitions were not created or formatted successfully"
    read -p "Press any key to exit..." -n1 -s
    exit 1
fi

echo "*** Format the partitions ***"
mkfs.ntfs -f /dev/sda1
echo "Format the partitions sda1"
mkfs.ntfs -f /dev/sda2
echo "Format the partitions sda1"
echo "Format the partitions finish ***"

echo "NTFS partitions created"

echo "*** Install gdisk ***"
sudo apt-get install gdisk
echo "Install gdisk finish ***"

echo "*** Run gdisk commands ***"
echo -e "r\ng\np\nw\nY\n" | gdisk /dev/sda
echo "Run gdisk commands finish ***"

echo "*** Mount /dev/sda1 to /mnt ***"
mount /dev/sda1 /mnt
echo "Mount /dev/sda1 to /mnt finish ***"

echo "*** Prepare directory for the Windows disk ***"
cd ~
mkdir -p windisk
echo "Prepare directory for the Windows disk finish ***"

echo "*** Mount /dev/sda2 to windisk ***"
mount /dev/sda2 windisk
echo "Mount /dev/sda2 to windisk finish ***"

echo "*** Install GRUB ***"
grub-install --root-directory=/mnt /dev/sda
echo "Install GRUB finish ***"

echo "*** Edit GRUB configuration ***"
cd /mnt/boot/grub
cat <<EOF > grub.cfg
menuentry "windows installer" {
	insmod ntfs
	search --no-floppy --set=root --file=/bootmgr
	ntldr /bootmgr
	boot
}
EOF
echo "Edit GRUB configuration finish ***"

echo "*** Prepare winfile directory ***"
cd /root/windisk
mkdir -p winfile
echo "Prepare winfile directory finish ***"

echo "*** Prepare winfile directory ***"
cd /root/windisk || exit 1
mkdir -p winfile
echo "Prepare winfile directory finish ***"

# Verificar se o arquivo Win10.iso já existe
if [ -f "Win10.iso" ]; then
    read -p "Win10.iso já existe. Deseja baixar novamente? (Y/N): " redownload_win
    if [[ "$redownload_win" == "Y" || "$redownload_win" == "y" ]]; then
        rm -f Win10.iso
        download_win_iso=true
    else
        download_win_iso=false
    fi
else
    download_win_iso=true
fi

if [ "$download_win_iso" = true ]; then
    # Perguntar pela URL para baixar o Win10.iso
    read -p "Digite a URL para o Win10.iso (deixe em branco para usar o padrão): " windows_url
    windows_url="${windows_url:-https://archive.org/download/win-10_202411/Win10.iso}"
    wget -O Win10.iso --user-agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36" "$windows_url"
    echo "Download de Win10.iso concluído."
else
    echo "Certifique-se de que o arquivo 'Win10.iso' está na pasta '/root/windisk'."
fi

# Verificar e montar a ISO do Windows
echo "*** Verificando a ISO do Windows ***"
if [ -f "Win10.iso" ]; then
    mkdir -p winfile
    mount -o loop Win10.iso winfile
    rsync -avz --progress winfile/* /mnt
    umount winfile
    echo "Montagem da ISO do Windows concluída."
else
    echo "Arquivo Win10.iso não encontrado!"
    exit 1
fi

# Verificar se o arquivo Virtio.iso já existe
if [ -f "Virtio.iso" ]; then
    read -p "Virtio.iso já existe. Deseja baixar novamente? (Y/N): " redownload_virtio
    if [[ "$redownload_virtio" == "Y" || "$redownload_virtio" == "y" ]]; then
        rm -f Virtio.iso
        download_virtio=true
    else
        download_virtio=false
    fi
else
    download_virtio=true
fi

if [ "$download_virtio" = true ]; then
    # Perguntar pela URL para baixar Virtio.iso
    read -p "Digite a URL para Virtio.iso (deixe em branco para usar o padrão): " virtio_url
    virtio_url="${virtio_url:-https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/archive-virtio/virtio-win-0.1.266-1/virtio-win-0.1.266.iso}"
    wget -O Virtio.iso "$virtio_url"
    echo "Download de Virtio.iso concluído."
fi

# Verificar e montar a ISO dos drivers Virtio
echo "*** Verificando a ISO dos drivers Virtio ***"
if [ -f "Virtio.iso" ]; then
    mkdir -p winfile /mnt/sources/virtio
    mount -o loop Virtio.iso winfile
    rsync -avz --progress winfile/* /mnt/sources/virtio
    umount winfile
    echo "Montagem da ISO dos drivers Virtio concluída."
else
    echo "Arquivo Virtio.iso não encontrado!"
    exit 1
fi

cd /mnt/sources || exit 1

# Criar arquivo cmd.txt
touch cmd.txt
echo 'add virtio /virtio_drivers' >> cmd.txt

# Listar imagens no boot.wim
echo "*** Listando imagens no boot.wim ***"
if [ -f "boot.wim" ]; then
    wimlib-imagex info boot.wim
    echo "Por favor, digite o índice de imagem válido da lista acima:"
    read -r image_index
    echo "*** Atualizando o boot.wim ***"
    wimlib-imagex update boot.wim "$image_index" < cmd.txt
    echo "Atualização do boot.wim concluída."
else
    echo "boot.wim não encontrado!"
    read -p "Pressione qualquer tecla para sair..." -n1 -s
    exit 1
fi

# Perguntar se o usuário deseja reiniciar o sistema
read -p "Deseja reiniciar o sistema agora? (Y/N): " reboot_choice
if [[ "$reboot_choice" == "Y" || "$reboot_choice" == "y" ]]; then
    sudo reboot
else
    echo "Continuando sem reiniciar."
fi
