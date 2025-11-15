# Scripts de Instalación ALIE

Scripts de instalación automatizada para Arch Linux con entornos de escritorio y gestores de ventanas personalizables.

## ⚠️ ADVERTENCIA - ESTADO EXPERIMENTAL

**Estos scripts son experimentales y se proporcionan tal cual (AS-IS) sin garantías.**

- **NO** son un reemplazo del instalador oficial de Arch Linux
- **NO** han sido probados exhaustivamente en todos los escenarios posibles
- **Pueden contener errores** que resulten en un sistema no booteable o pérdida de datos
- **Se recomienda encarecidamente** seguir la guía manual del README principal para entender cada paso
- Úsalos bajo tu propio riesgo, especialmente en sistemas de producción o datos importantes
- **Haz copias de seguridad** antes de usar estos scripts

**Para usuarios nuevos:** Se recomienda seguir la guía manual paso a paso para comprender el proceso de instalación.

**Para usuarios experimentados:** Estos scripts pueden ahorrar tiempo en reinstalaciones, pero revisa el código antes de ejecutarlo.

## Inicio Rápido

### Modo Automático (Recomendado)

El instalador detecta automáticamente tu entorno y continúa desde donde lo dejaste:

```bash
bash alie.sh
```

Detecta si estás en:

- **Live CD**: Inicia instalación base
- **Chroot**: Configura el sistema
- **Sistema instalado sin GUI**: Ofrece selección de DE/WM
- **Sistema con escritorio**: Instala herramientas adicionales

El progreso se guarda automáticamente, así que puedes reiniciar entre pasos sin perder el rastro.

### Modo Manual

Elige manualmente qué script ejecutar:

```bash
bash alie.sh --manual
```

Útil para:
- Re-ejecutar pasos específicos
- Depuración
- Instalaciones personalizadas

## Estructura de Directorios

```
├── alie.sh                    # Instalador maestro (punto de entrada)
├── install/                   # Scripts de instalación
│   ├── 001-base-install.sh    # Particionado y formateo de disco
│   ├── 002-shell-editor-select.sh # Selección shell/editor (bash/zsh/fish/nushell + nano/vim) (opcional)
│   ├── 003-system-install.sh  # Instalación base (pacstrap)
│   ├── 101-configure-system.sh # Configuración del sistema (grub, locale)
│   ├── 201-user-setup.sh      # Creación de usuario y privilegios
│   ├── 211-install-aur-helper.sh # Helper AUR (yay/paru)
│   ├── 212-cli-tools.sh       # Selección interactiva de herramientas CLI
│   ├── 213-display-server.sh  # Servidor gráfico (X11/Wayland)
│   ├── 220-desktop-select.sh  # Elegir DE/WM o saltar
│   ├── 221-desktop-environment.sh # Entornos de Escritorio
│   ├── 222-window-manager.sh  # Gestores de Ventanas
│   └── 231-desktop-tools.sh   # Aplicaciones adicionales
├── lib/                       # Bibliotecas compartidas
│   ├── shared-functions.sh    # Funciones comunes
│   └── config-functions.sh    # Funciones de despliegue de configuraciones
├── configs/                   # Archivos de configuración y plantillas
│   ├── README.md              # Documentación de archivos de configuración
│   ├── audio/                 # Configuración de audio (ALSA/PipeWire)
│   ├── display-managers/      # Configs de gestores de pantalla (LightDM/SDDM)
│   ├── editor/                # Configuraciones de editores de texto (nano/vim)
│   ├── firewall/              # Configuraciones de firewall (UFW/Firewalld)
│   ├── network/               # Configuraciones de red (NetworkManager/systemd-resolved)
│   ├── shell/                 # Configuraciones de shell (bash/zsh/fish/nushell/ksh/tcsh)
│   ├── sudo/                  # Configuraciones de privilegios Sudo/Doas
│   └── xorg/                  # Configuraciones de drivers gráficos Xorg
├── README.en.md               # Documentación en inglés
├── README.es.md               # Documentación en español
├── LICENSE                    # Licencia AGPLv3
└── .gitignore
```

## Scripts Disponibles

| # | Script | Ejecutar como | Cuándo |
|---|--------|---------------|--------|
| 0 | `alie.sh` | root/usuario | En cualquier momento (detecta automáticamente) |
| 1 | `001-base-install.sh` | root | Desde medio de instalación |
| 2 | `002-shell-editor-select.sh` | root | Selección shell/editor (bash/zsh/fish/nushell + nano/vim) (opcional) |
| 3 | `003-system-install.sh` | root | Desde medio de instalación |
| 4 | `101-configure-system.sh` | root | Dentro de arch-chroot |
| 5 | `201-user-setup.sh` | root | Creación de usuario y configuración de privilegios |
| 6 | `211-install-aur-helper.sh` | usuario | Instalación de helper AUR (yay/paru) |
| 7 | `212-cli-tools.sh` | usuario | Selección interactiva de herramientas CLI |
| 8 | `213-display-server.sh` | root | Selección X11/Wayland |
| 9 | `220-desktop-select.sh` | root | Elegir DE/WM o saltar |
| 10 | `221-desktop-environment.sh` | root | Entornos de Escritorio |
| 11 | `222-window-manager.sh` | root | Gestores de Ventanas |
| 12 | `231-desktop-tools.sh` | root | Aplicaciones adicionales |

## Proceso Completo

### Con Instalador Automático (Recomendado)

```bash
# En cada etapa, simplemente ejecuta:
bash alie.sh
```

El script automáticamente:
- ✅ Detecta el entorno actual
- ✅ Verifica el progreso previo
- ✅ Ejecuta el siguiente paso apropiado
- ✅ Guarda el progreso para continuar después de reiniciar

### Con Scripts Individuales (Manual)

```bash
# 1. Desde medio de instalación
bash install/001-base-install.sh

# 2. En chroot
arch-chroot /mnt
bash install/101-configure-system.sh
exit

# 3. Desmontar y reiniciar
umount -R /mnt
sync
reboot

# 4. Después del reinicio (como root)
bash install/201-user-setup.sh
reboot

# 5. Después del reinicio (como usuario)
bash install/211-install-aur-helper.sh
bash install/212-cli-tools.sh
reboot
```

## Características

### Sistema de Progreso
- El instalador guarda automáticamente tu progreso en `.alie-progress`
- Puedes reiniciar en cualquier momento y continuar desde donde lo dejaste
- Usa `bash alie.sh --manual` para borrar el progreso si necesitas empezar de nuevo

### Funciones Compartidas
- Todas las funciones comunes están en `lib/shared-functions.sh`
- UI consistente con colores y mensajes claros
- Manejo robusto de errores
- Reintentos automáticos para operaciones de red
- Validaciones de seguridad (permisos root/usuario)

### Detección Inteligente
- Auto-detecta CPU (Intel/AMD) para microcode correcto
- Detecta modo de arranque (UEFI/BIOS)
- Verifica conexión a internet antes de instalar
- Valida entorno (Live USB, chroot, sistema instalado)
- **Soporte múltiple de shells** - Elige entre Bash, Zsh, Fish o Nushell con configuración completa

### Opciones de Shell
ALIE soporta múltiples entornos de shell con configuración completa:

#### Shells Disponibles
- **Bash** - Shell Bourne Again de GNU (predeterminado)
- **Zsh** - Shell Bourne extendido con características avanzadas
- **Fish** - Shell interactivo amigable con autosugerencias
- **Nushell** - Shell moderno escrito en Rust con soporte para datos estructurados

#### Características de Configuración de Shell
- **Detección Automática**: Los scripts detectan y configuran tu shell elegido
- **Configuración Completa**: Incluye aliases, configuración de PATH y editores
- **Soporte de Fallback**: Configuración inline si los archivos de configuración no están disponibles
- **Características Especiales de Nushell**: Manejo de datos estructurados, prompt personalizado, integración con Starship

## Personalización

Edita los scripts antes de ejecutarlos para:

- Cambiar el país de reflector
- Modificar la lista de paquetes
- Ajustar configuraciones específicas

## Notas Importantes

- **Siempre revisa los scripts antes de ejecutarlos**
- Los scripts se detienen ante errores (`set -e`)
- Algunos requieren entrada del usuario
- Diseñados para ser idempotentes cuando es posible

## Solución de Problemas

Si un script falla:

1. Lee el mensaje de error
2. Corrige el problema manualmente
3. Continúa con el siguiente paso o vuelve a ejecutar

## Contribuciones

Si encuentras errores o mejoras, abre un issue o pull request en el repositorio.
