# ALIE Configuration Files

Este directorio contiene archivos de configuración mínima para diversas herramientas instaladas por ALIE.

## 🔥 Firewall Configurations

### UFW (Uncomplicated Firewall)

**Archivo**: `ufw-basic.sh`

```bash
# Aplicar configuración
sudo bash docs/configs/ufw-basic.sh
```

**Características**:
- Bloquea todo incoming por defecto
- Permite todo outgoing
- Permite SSH (puerto 22)
- Reglas comentadas para HTTP/HTTPS

### Firewalld

**Archivo**: `firewalld-basic.sh`

```bash
# Aplicar configuración
sudo bash docs/configs/firewalld-basic.sh
```

**Características**:
- Zona pública por defecto
- Permite SSH
- Reglas comentadas para servicios comunes

## 🔊 Audio Configuration

### PipeWire

ALIE usa PipeWire como servidor de audio moderno.

**Verificar estado**:
```bash
systemctl --user status pipewire pipewire-pulse wireplumber
```

**Habilitar** (si no está activado):
```bash
systemctl --user enable --now pipewire pipewire-pulse wireplumber
```

**Configuración**:
- Usuario: `~/.config/pipewire/`
- Sistema: `/etc/pipewire/`

### ALSA

**Verificar dispositivos**:
```bash
aplay -l    # Listar dispositivos de reproducción
arecord -l  # Listar dispositivos de grabación
```

**Mixer**:
```bash
alsamixer   # TUI mixer
```

## 📱 MTP/Android Devices

### jmtpfs

**Montar dispositivo**:
```bash
mkdir ~/mnt/android
jmtpfs ~/mnt/android
```

**Desmontar**:
```bash
fusermount -u ~/mnt/android
```

### android-udev

Las reglas udev se instalan automáticamente en:
- `/usr/lib/udev/rules.d/51-android.rules`

**Verificar**:
```bash
lsusb  # Ver dispositivos USB conectados
```

## 🔐 Security Tools

### GPG/GnuPG

**Generar clave**:
```bash
gpg --full-generate-key
```

**Listar claves**:
```bash
gpg --list-keys
```

### Pass (Password Manager)

**Inicializar**:
```bash
pass init tu-email@ejemplo.com
```

**Agregar contraseña**:
```bash
pass insert servicio/nombre
```

## 📦 Archive Tools

### Comandos Básicos

```bash
# 7zip
7z a archivo.7z directorio/
7z x archivo.7z

# Unrar
unrar x archivo.rar

# Zstd (moderno, rápido)
zstd archivo
zstd -d archivo.zst

# LZ4 (ultra rápido)
lz4 archivo
lz4 -d archivo.lz4
```

## 🛠️ System Administration

### TLP (Laptop Power Management)

**Habilitar**:
```bash
sudo systemctl enable --now tlp
```

**Estado**:
```bash
tlp-stat -s
```

### Hardware Monitoring

```bash
# Detectar sensores
sudo sensors-detect

# Ver temperaturas
sensors

# Información del sistema
inxi -Fxz

# Info de hardware
sudo lshw -short
sudo dmidecode | less
```

## 📝 Notas

- Todos los scripts de configuración son **mínimos** y **seguros**
- Revisa y personaliza según tus necesidades
- Los servicios se habilitan manualmente (no automáticamente)
- Consulta la documentación oficial de cada herramienta para opciones avanzadas

## 🔗 Referencias

- [UFW](https://wiki.archlinux.org/title/Uncomplicated_Firewall)
- [Firewalld](https://wiki.archlinux.org/title/Firewalld)
- [PipeWire](https://wiki.archlinux.org/title/PipeWire)
- [ALSA](https://wiki.archlinux.org/title/Advanced_Linux_Sound_Architecture)
- [MTP](https://wiki.archlinux.org/title/MTP)
