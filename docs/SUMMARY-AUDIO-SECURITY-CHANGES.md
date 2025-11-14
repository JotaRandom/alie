# Resumen de Cambios - Audio, Seguridad y Herramientas del Sistema

## 📦 Paquetes Agregados

### Herramientas de Archivo
- **cpio** - Archivador CPIO (formato antiguo pero útil para backups del kernel)
- **pax** - Archivador POSIX estándar

### Seguridad y Firewall
- **firewalld** - Firewall dinámico con soporte para zonas de red
  - Alternativa más avanzada a ufw
  - Soporte para configuración temporal/permanente
  - Integración con NetworkManager

### Soporte de Dispositivos
- **android-udev** - Reglas udev para dispositivos Android
  - Permite reconocimiento automático de dispositivos Android
  - Funciona con gvfs-mtp (ya incluido en desktop)
  - No requiere software adicional de AUR

### Audio
- **alsa-utils** - Utilidades ALSA (alsamixer, aplay, arecord, etc.)
- **alsa-tools** - Herramientas avanzadas ALSA
- **alsa-firmware** - Firmware para dispositivos ALSA
- **sof-firmware** - Sound Open Firmware (necesario para laptops modernas)

## 🔄 Cambios de Sistema

### Audio: PulseAudio → PipeWire

**Antes** (221-desktop-install.sh):
```bash
"pulseaudio"         # Audio system
"pulseaudio-alsa"    # ALSA integration  
"pavucontrol"        # Audio control
```

**Después** (221-desktop-install.sh):
```bash
"pipewire"           # Audio/video server
"pipewire-alsa"      # ALSA integration
"pipewire-pulse"     # PulseAudio compatibility
"pipewire-jack"      # JACK compatibility
"wireplumber"        # Session manager
"pavucontrol"        # Audio control (PulseAudio compatible)
```

**Razones del cambio**:
1. **Moderno**: PipeWire es el futuro del audio en Linux
2. **Compatible**: Reemplaza PulseAudio sin romper aplicaciones
3. **Mejor latencia**: Ideal para producción de audio/video
4. **Soporte JACK**: Aplicaciones profesionales funcionan sin configuración extra
5. **Mantenido**: Red Hat y colaboradores activamente desarrollando

## 📝 Documentación Creada

### 1. docs/CHECK-DEPENDENCIES.md
- Guía para verificar dependencias de paquetes
- Lista de herramientas verificadas sin dependencias gráficas
- Comandos útiles para testing
- Evaluación de dependencias aceptables vs inaceptables

### 2. docs/configs/ufw-basic.sh
- Configuración mínima segura para UFW
- Bloquea incoming, permite outgoing
- Permite SSH por defecto
- Reglas comentadas para servicios comunes

### 3. docs/configs/firewalld-basic.sh
- Configuración mínima segura para Firewalld
- Zona pública por defecto
- Permite SSH
- Reglas comentadas para servicios comunes

### 4. docs/configs/README.md
- Guía completa de configuraciones
- Instrucciones para firewall, audio, MTP, seguridad
- Comandos básicos de herramientas comunes
- Referencias a la wiki de Arch

## ✅ Verificación de Dependencias

### Paquetes Verificados Sin Dependencias Gráficas

**Totalmente limpios**:
- cpio (solo glibc)
- pax (solo glibc)
- android-udev (systemd, udev)
- alsa-utils (alsa-lib, ncurses)
- alsa-firmware (sin dependencias)
- sof-firmware (sin dependencias)

**Aceptables**:
- firewalld (tiene hicolor-icon-theme pero es solo archivos)
- alsa-tools (usa fltk, pero es ligero y necesario para GUI tools)

### Estrategia de Instalación

```bash
# Instalar sin dependencias opcionales GUI
sudo pacman -S --needed firewalld

# NO instalar estas dependencias opcionales:
# - gtk3 (firewall-config GUI)
# - libnotify (notificaciones de escritorio)
# - python-pyqt6 (applet gráfico)
```

## 🔧 Total de Paquetes por Categoría

### 212-cli-tools.sh

| Categoría | Antes | Después | Agregados |
|-----------|-------|---------|-----------|
| Archive Tools | 8 | 10 | +2 (cpio, pax) |
| Security Tools | 11 | 12 | +1 (firewalld) |
| Media Tools | 9 | 13 | +4 (alsa-*) |
| Admin Tools | 12 | 13 | +1 (android-udev) |
| **TOTAL CLI** | **80+** | **88+** | **+8** |

### 221-desktop-install.sh

| Sistema | Paquetes |
|---------|----------|
| Audio (antes) | 3 (PulseAudio) |
| Audio (ahora) | 6 (PipeWire) |

## 📊 Comparación Final: ALIE vs AUI

### Herramientas Únicas de ALIE

- **60+ herramientas de desarrollo** (GCC completo, LLVM, Rust, Go, Python avanzado)
- **40+ herramientas CLI modernas** (bat, ripgrep, fd, exa, dust, duf, btop++)
- **PipeWire** en lugar de PulseAudio
- **Selección individual** de paquetes
- **Sin dependencias GUI** innecesarias en CLI tools

### Herramientas Agregadas de AUI

- firewalld (alternativa avanzada a ufw)
- alsa-utils, alsa-tools, alsa-firmware, sof-firmware (soporte completo de audio)
- android-udev (soporte MTP para Android)
- cpio, pax (archivadores estándar POSIX)

### Herramientas de AUI NO Agregadas

- **gparted, grsync, gufw** - Son GUI, no CLI
- **mtpfs** - Descontinuado, reemplazado por android-udev + gvfs-mtp
- **hosts-update (AUR)** - Requiere verificar si sigue mantenido

## 🎯 Próximos Pasos

### Opcional - Considerar Agregar

1. **jmtpfs** (AUR) - Si se confirma que sigue mantenido
   - Alternativa a gvfs-mtp
   - Más control sobre montaje MTP

2. **hosts-update** (AUR) - Si está activamente mantenido
   - Bloqueo de ads a nivel de sistema
   - Actualización automática de listas

### Testing Recomendado

```bash
# 1. Verificar PipeWire funciona correctamente
systemctl --user status pipewire pipewire-pulse wireplumber

# 2. Test de firewalld
sudo firewall-cmd --list-all

# 3. Test de ALSA
aplay -l
alsamixer

# 4. Test de MTP (con dispositivo Android conectado)
lsusb
gio mount -li | grep mtp
```

## 📌 Notas Importantes

1. **PipeWire** es retrocompatible con PulseAudio
2. **firewalld** y **ufw** NO deben usarse simultáneamente
3. **android-udev** funciona con **gvfs-mtp** (ya incluido en desktop)
4. **Todos los paquetes** verificados para NO arrastrar X11/Wayland innecesariamente
5. **Configuraciones mínimas** provistas en docs/configs/

## ✨ Mejoras de Calidad

- Documentación exhaustiva de dependencias
- Scripts de configuración listos para usar
- Guías de verificación y testing
- Compatibilidad verificada con arquitectura sin GUI
