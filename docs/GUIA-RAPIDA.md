# 🚀 ALIE - Guía de Referencia Rápida

## Inicio Rápido - 3 Comandos

```bash
# En Live USB
bash alie.sh

# Después de arch-chroot
bash alie.sh

# Después de cada reinicio
bash alie.sh
```

¡Eso es todo! El instalador hace el resto automáticamente.

---

## Tabla de Comandos

| Situación | Comando | Descripción |
|-----------|---------|-------------|
| **Instalación normal** | `bash alie.sh` | Modo automático (recomendado) |
| **Elegir script manual** | `bash alie.sh --manual` | Muestra menú de selección |
| **Borrar progreso** | `bash alie.sh --manual` → opción 6 | Reinicia desde cero |

---

## Flujo de Instalación Completo

### 1️⃣ Boot desde USB de Arch Linux
```bash
# El sistema arranca en Live USB
```

### 2️⃣ Primera Ejecución (Live USB)
```bash
bash alie.sh
```
**Lo que hace**:
- ✅ Detecta que estás en Live USB
- ✅ Configura red (WiFi o Ethernet)
- ✅ Particiona disco automáticamente
- ✅ Instala sistema base con `pacstrap`
- ✅ Instala microcode (Intel/AMD)
- ✅ Guarda progreso: `01-base-installed`

**Siguiente paso**: `arch-chroot /mnt`

### 3️⃣ Segunda Ejecución (Chroot)
```bash
arch-chroot /mnt
bash alie.sh
```
**Lo que hace**:
- ✅ Detecta que estás en chroot
- ✅ Configura timezone, locale, hostname
- ✅ Instala y configura GRUB
- ✅ Crea usuario root password
- ✅ Guarda progreso: `02-system-configured`

**Siguiente paso**: `exit`, `umount -R /mnt`, `reboot`

### 4️⃣ Tercera Ejecución (Primer boot, como root)
```bash
# Login como root
bash alie.sh
```
**Lo que hace**:
- ✅ Detecta sistema sin escritorio
- ✅ Crea usuario regular
- ✅ Instala Cinnamon Desktop
- ✅ Instala LightDM
- ✅ Configura sudo para wheel group
- ✅ Guarda progreso: `03-desktop-installed`

**Siguiente paso**: `reboot`

### 5️⃣ Cuarta Ejecución (Con desktop, como usuario)
```bash
# Login como tu usuario (NO root)
bash alie.sh
```
**Lo que hace**:
- ✅ Detecta sistema con escritorio
- ✅ Instala YAY AUR helper
- ✅ Guarda progreso: `04-yay-installed`

### 6️⃣ Quinta Ejecución (Instalar paquetes)
```bash
bash alie.sh
```
**Lo que hace**:
- ✅ Detecta YAY instalado
- ✅ Instala todos los paquetes de Linux Mint:
  - Fonts (Noto, Ubuntu)
  - Themes (Mint themes, icons)
  - Apps (Firefox, Thunderbird, LibreOffice)
  - Multimedia (Rhythmbox, Celluloid)
  - Tools (Timeshift, Nemo, etc.)
- ✅ Guarda progreso: `05-packages-installed`

### 7️⃣ ¡Instalación Completa! 🎉
```bash
reboot
# Disfruta tu Linux Mint Arch Edition
```

---

## Modo Manual - Casos de Uso

### Re-ejecutar un script específico
```bash
bash alie.sh --manual
# Elige el número del script que quieres ejecutar
```

### Borrar progreso y empezar de nuevo
```bash
bash alie.sh --manual
# → Opción 6: Clear progress and exit
```

### Saltar un paso (avanzado)
```bash
# Ejemplo: Ya instalaste el desktop manualmente
bash alie.sh --manual
# → Elige script 4 (YAY) para continuar desde ahí
```

---

## Estructura de Archivos

```
src/
├── alie.sh                 # Instalador maestro (ejecuta esto)
├── install/                # Scripts de instalación (auto-ejecutados)
├── lib/                    # Funciones compartidas (auto-cargadas)
└── docs/                   # Documentación
```

**Solo necesitas ejecutar**: `bash alie.sh`

---

## Detección Automática de Entorno

El script detecta automáticamente dónde estás:

| Entorno | El script detecta | Ejecuta |
|---------|-------------------|---------|
| **Live USB** | `/etc/hostname` contiene "archiso" | 01-base-install.sh |
| **Chroot** | `/mnt` existe y está montado | 02-configure-system.sh |
| **Sin Desktop** | No existe `/usr/bin/cinnamon` | 03-desktop-install.sh |
| **Con Desktop** | Existe `/usr/bin/cinnamon` | 04 o 05 según progreso |

---

## Requisitos de Permisos

| Script | Requiere |
|--------|----------|
| 01 - Base Install | **root** |
| 02 - Configure System | **root** (en chroot) |
| 03 - Desktop Install | **root** |
| 04 - YAY Install | **usuario regular** (NO root) |
| 05 - Packages Install | **usuario regular** (NO root) |

**El script valida automáticamente** y te avisa si ejecutas con permisos incorrectos.

---

## Progreso Guardado

El sistema guarda tu progreso en: `.ALIE-progress`

**Marcadores**:
- `01-base-installed` - Sistema base OK
- `02-system-configured` - GRUB + locale OK
- `03-desktop-installed` - Cinnamon OK
- `04-yay-installed` - YAY OK
- `05-packages-installed` - Todo instalado ✅

**Para ver tu progreso actual**: Ejecuta `bash alie.sh` y verás un mensaje.

---

## Solución de Problemas

### El script dice "wrong environment"
```bash
# Ejecuta en modo manual para ver opciones
bash alie.sh --manual
```

### El script falla y quiero reintentar
```bash
# Simplemente vuelve a ejecutar
bash alie.sh
# El progreso se mantiene, solo re-ejecuta el paso fallido
```

### Quiero empezar desde cero
```bash
bash alie.sh --manual
# → Opción 6: Clear progress
# Luego vuelve a empezar
bash alie.sh
```

### No tengo internet en Live USB
```bash
# El script 01 incluye asistente de red WiFi
bash alie.sh
# → Sigue las instrucciones para conectar WiFi
```

---

## Personalización Antes de Instalar

### Cambiar país de mirrors
```bash
# Edita install/01-base-install.sh
nano install/01-base-install.sh
# Busca: REFLECTOR_COUNTRY="United States"
# Cambia a tu país
```

### Cambiar hostname
```bash
# Edita install/02-configure-system.sh
nano install/02-configure-system.sh
# El script te preguntará el hostname durante ejecución
```

### Cambiar lista de paquetes
```bash
# Edita install/05-install-packages.sh
nano install/05-install-packages.sh
# Modifica las secciones de yay -S
```

---

## Cheatsheet de Comandos de Arch

| Tarea | Comando |
|-------|---------|
| Actualizar sistema | `sudo pacman -Syu` |
| Instalar paquete | `sudo pacman -S nombre-paquete` |
| Buscar paquete | `pacman -Ss búsqueda` |
| Instalar desde AUR | `yay -S nombre-paquete` |
| Limpiar caché | `sudo pacman -Sc` |
| Ver archivos de paquete | `pacman -Ql nombre-paquete` |

---

## Verificación Post-Instalación

### Verificar servicios activos
```bash
systemctl status NetworkManager
systemctl status lightdm
systemctl status bluetooth
systemctl status cups  # si instalaste impresoras
```

### Verificar paquetes instalados
```bash
pacman -Q | wc -l  # Cuenta paquetes instalados
yay -Q | wc -l     # Incluye AUR
```

### Configurar Timeshift
```bash
sudo timeshift-gtk
# Configura backups automáticos
```

---

## Archivos Importantes

| Archivo | Propósito |
|---------|-----------|
| `~/.ALIE-progress` | Progreso de instalación |
| `~/.ALIE-install-info` | Info guardada (CPU, timezone, etc.) |
| `/etc/fstab` | Montajes automáticos |
| `/etc/locale.gen` | Configuración de idiomas |
| `/etc/hostname` | Nombre del equipo |

---

## ¿Necesitas Ayuda?

1. **Lee la documentación completa**: `src/README.es.md`
2. **Revisa el changelog**: `CHANGELOG.md`
3. **Consulta las funciones**: `src/lib/SHARED-FUNCTIONS.md`
4. **Modo manual para debugging**: `bash alie.sh --manual`

---

## Resumen Ultra-Rápido

```
1. Boot USB → bash alie.sh
2. arch-chroot /mnt → bash alie.sh → exit → reboot
3. Login root → bash alie.sh → reboot
4. Login usuario → bash alie.sh
5. bash alie.sh (instala paquetes)
6. ✅ Listo!
```

---

**Pro tip**: Guarda este archivo en tu USB de instalación para tener la guía siempre a mano 😉


