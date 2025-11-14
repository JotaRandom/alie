# Verificación de Dependencias en ALIE

## Objetivo

Asegurar que los paquetes CLI no arrastren dependencias de X11 o Wayland innecesariamente.

## Herramientas para Verificar

### 1. Ver dependencias de un paquete

```bash
# Ver dependencias directas
pacman -Si <paquete> | grep "Depends On"

# Ver árbol completo de dependencias
pactree <paquete>

# Ver solo dependencias opcionales
pacman -Si <paquete> | grep "Optional Deps"
```

### 2. Verificar si arrastra X11/Wayland

```bash
# Buscar dependencias de X11
pactree <paquete> | grep -E "libx11|xorg|xcb"

# Buscar dependencias de Wayland
pactree <paquete> | grep -E "wayland|wlroots"

# Buscar dependencias gráficas en general
pactree <paquete> | grep -E "gtk|qt|cairo|pango"
```

## Paquetes Verificados (Sin Dependencias Gráficas)

### ✅ Herramientas Agregadas Recientemente

#### firewalld
```bash
$ pacman -Si firewalld | grep "Depends On"
Depends On      : glib2  hicolor-icon-theme  nftables  python-capng  
                  python-dbus  python-gobject
```
**Evaluación**: 
- ❌ `hicolor-icon-theme` - tema de iconos (menor, solo archivos)
- Dependencias opcionales: `gtk3` (GUI), `libnotify` (notificaciones)
- **Decisión**: Aceptable para CLI si no instalamos dependencias opcionales

#### jmtpfs (AUR)
```bash
$ paru -Si jmtpfs
Depends On      : fuse  libmtp
```
**Evaluación**: ✅ Sin dependencias gráficas

#### android-udev
```bash
$ pacman -Si android-udev
Depends On      : systemd  udev
```
**Evaluación**: ✅ Sin dependencias gráficas

#### alsa-utils
```bash
$ pacman -Si alsa-utils
Depends On      : alsa-lib  pciutils  ncurses  psmisc
```
**Evaluación**: ✅ Sin dependencias gráficas

#### alsa-tools
```bash
$ pacman -Si alsa-tools
Depends On      : fltk  alsa-lib
```
**Evaluación**: 
- ⚠️  `fltk` - toolkit gráfico ligero (FLTK es más pequeño que GTK/Qt)
- **Decisión**: Aceptable, FLTK es mínimo y algunas herramientas ALSA necesitan GUI

#### alsa-firmware
```bash
$ pacman -Si alsa-firmware
Depends On      : None
```
**Evaluación**: ✅ Solo archivos de firmware

#### sof-firmware
```bash
$ pacman -Si sof-firmware
Depends On      : None
```
**Evaluación**: ✅ Solo archivos de firmware

#### cpio
```bash
$ pacman -Si cpio
Depends On      : glibc
```
**Evaluación**: ✅ Sin dependencias gráficas

#### pax
```bash
$ pacman -Si pax
Depends On      : glibc
```
**Evaluación**: ✅ Sin dependencias gráficas

## Casos Especiales

### gparted (Partition Editor)
```bash
$ pacman -Si gparted
Depends On      : gtk3  parted  util-linux  ...
```
**Evaluación**: ❌ GUI completo (GTK3)
**Nota**: Incluido en Admin Tools porque es una herramienta administrativa esencial
**Alternativas CLI**: `fdisk`, `parted`, `cgdisk`

### keepassxc (Password Manager)
```bash
$ pacman -Si keepassxc
Depends On      : qt6-base  libxtst  ...
```
**Evaluación**: ❌ GUI completo (Qt6)
**Nota**: Password manager con GUI necesaria para usabilidad
**Alternativa CLI**: `pass` (también incluido)

## Comandos Útiles para Testing

### Verificar todo el sistema
```bash
# Listar paquetes que dependen de X11
pacman -Qq | while read pkg; do
    if pacman -Qi "$pkg" 2>/dev/null | grep -q "libx11"; then
        echo "$pkg depende de X11"
    fi
done
```

### Simular instalación sin ejecutarla
```bash
# Ver qué se instalaría (dry-run)
sudo pacman -S --print <paquete>
```

## Recomendaciones

### Niveles de Dependencias Aceptables

1. **✅ Perfecto**: Sin dependencias gráficas
   - Herramientas CLI puras
   - Daemons del sistema
   - Firmware y drivers

2. **⚠️  Aceptable**: Dependencias gráficas mínimas opcionales
   - Iconos (hicolor-icon-theme)
   - Toolkits ligeros (fltk)
   - Librerías de bajo nivel sin servidor gráfico

3. **❌ Evitar**: Requiere servidor gráfico completo
   - GTK3/4, Qt5/6
   - Wayland/Xorg como dependencia directa

### Estrategia de Instalación

Para herramientas con dependencias opcionales gráficas:

```bash
# Instalar SIN dependencias opcionales
sudo pacman -S --asdeps <paquete>

# O explícitamente evitar opcionales
sudo pacman -S --needed <paquete>
```

## Notas Especiales

### PipeWire vs PulseAudio

ALIE usa **PipeWire** (no PulseAudio) porque:
- Más moderno y eficiente
- Compatible con PulseAudio (via pipewire-pulse)
- Menor latencia
- Mejor soporte para profesionales de audio

### MTP Support

Preferimos **android-udev** + **jmtpfs** sobre **mtpfs** porque:
- jmtpfs está más actualizado
- mtpfs no está en repos oficiales (descontinuado)
- android-udev proporciona reglas udev necesarias
