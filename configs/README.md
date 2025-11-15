# ALIE Configuration System

Sistema modular de configuraciones para ALIE. Los archivos de configuración están separados de los scripts de instalación para facilitar su personalización y mantenimiento.

## 📁 Estructura de Directorios

```
configs/
├── audio/              # Configuraciones de audio (ALSA, PipeWire)
├── display-managers/   # Configuraciones de gestores de pantalla (LightDM, SDDM, GDM)
├── editor/             # Configuraciones de editores (vim, nano)
├── firewall/           # Configuraciones de firewall (ufw, firewalld)
├── network/            # Configuraciones de red (NetworkManager, DNS)
├── shell/              # Configuraciones de shell (bash, zsh)
└── sudo/               # Configuraciones de privilegios (sudo, doas)
```

## 🎯 Filosofía del Sistema

### Ventajas de Configuraciones Externas

1. **Modularidad**: Modificar configuraciones sin tocar scripts
2. **Reusabilidad**: Mismo config para diferentes instalaciones
3. **Versionado**: Control de cambios independiente
4. **Testing**: Probar configuraciones antes de deploy
5. **Backup**: Fácil respaldo y restauración

### Tipos de Archivos

- **`.template`**: Requieren sustitución de variables (ej: `{{USERNAME}}`)
- **Sin extensión o `.conf`**: Listos para copiar directamente
- **`.sh`**: Scripts ejecutables para configuración automática

## 📋 Categorías de Configuración

### 1. Sudo/Doas (`configs/sudo/`)

Configuraciones de escalación de privilegios.

#### Archivos Disponibles

| Archivo | Descripción | Variables |
|---------|-------------|-----------|
| `sudoers-user-primary.template` | Configuración sudo como herramienta principal | `{{USERNAME}}` |
| `sudoers-user-backup.template` | Configuración sudo como backup de doas | `{{USERNAME}}` |
| `sudoers-defaults-primary` | Configuración global sudo (principal) | Ninguna |
| `sudoers-defaults-backup` | Configuración global sudo (backup) | Ninguna |
| `doas.conf.template` | Configuración OpenDoas | `{{USERNAME}}` |

#### Uso en Scripts

```bash
# Cargar funciones de configuración
source "$LIB_DIR/config-functions.sh"

# Desplegar configuración con variables
deploy_config "sudo/sudoers-user-primary.template" \
    "/etc/sudoers.d/10-alie-$USERNAME" \
    "USERNAME=$USERNAME"

# Establecer permisos (crítico para sudoers)
chmod 440 "/etc/sudoers.d/10-alie-$USERNAME"

# Validar antes de aplicar
validate_sudoers "/etc/sudoers.d/10-alie-$USERNAME"
```

#### Limitación: Variables Dependientes de Usuario

**IMPORTANTE**: Las configuraciones de sudo/doas **no pueden** ser completamente estáticas porque dependen del nombre de usuario, que se define durante la instalación.

**Solución Implementada**: Sistema de plantillas con `{{USERNAME}}`

### 2. Firewall (`configs/firewall/`)

Configuraciones de cortafuegos para diferentes escenarios.

#### Archivos Disponibles

| Archivo | Descripción | Uso |
|---------|-------------|-----|
| `ufw-basic.sh` | UFW mínimo (SSH only) | Servidores, seguridad máxima |
| `ufw-desktop.sh` | UFW permisivo (desarrollo) | Workstations, desarrollo |
| `firewalld-basic.sh` | Firewalld mínimo | Servidores con zones |
| `firewalld-desktop.sh` | Firewalld desarrollo | Desktop con múltiples zones |

#### Uso en Scripts

```bash
# Opción 1: Ejecutar script de configuración directamente
execute_config_script "firewall/ufw-basic.sh"

# Opción 2: Dar opciones al usuario
print_info "Select firewall configuration:"
echo "1. Basic (SSH only)"
echo "2. Desktop (Development)"
read -p "Choice: " choice

case $choice in
    1) execute_config_script "firewall/ufw-basic.sh" ;;
    2) execute_config_script "firewall/ufw-desktop.sh" ;;
esac
```

#### Diferencias UFW vs Firewalld

- **UFW**: Simple, ideal para desktop/laptop, configuración lineal
- **Firewalld**: Potente, basado en zones, ideal para servidores

**Nota**: Son mutuamente excluyentes - activar solo uno.

### 3. Audio (`configs/audio/`)

Configuraciones de sistema de audio (ALSA + PipeWire).

#### Archivos Disponibles

| Archivo | Destino | Descripción |
|---------|---------|-------------|
| `asound.conf` | `/etc/asound.conf` | Config global ALSA |
| `pipewire.conf` | `/etc/pipewire/pipewire.conf` | Config PipeWire daemon |
| `wireplumber.conf` | `/etc/wireplumber/main.conf.d/50-alie.conf` | Session manager |

#### Uso en Scripts

```bash
# Desplegar configuraciones de audio
deploy_config_direct "audio/asound.conf" "/etc/asound.conf" "644"
deploy_config_direct "audio/pipewire.conf" "/etc/pipewire/pipewire.conf" "644"

# WirePlumber requiere directorio específico
mkdir -p /etc/wireplumber/main.conf.d
deploy_config_direct "audio/wireplumber.conf" \
    "/etc/wireplumber/main.conf.d/50-alie.conf" "644"
```

### 4. Display Managers (`configs/display-managers/`)

Configuraciones para gestores de inicio de sesión gráfico.

#### Archivos Disponibles

| Archivo | Destino | Descripción |
|---------|---------|-------------|
| `lightdm-slick-greeter.conf` | `/etc/lightdm/slick-greeter.conf` | Configuración de Slick Greeter (Cinnamon) |
| `sddm.conf` | `/etc/sddm.conf` | Configuración de SDDM (KDE Plasma) |
| `configure-lightdm-slick.sh` | Script ejecutable | Modifica lightdm.conf para usar Slick Greeter |

#### Uso en Scripts

```bash
# LightDM con Slick Greeter (Cinnamon/Mint)
# Requiere modificación del lightdm.conf principal
backup_config "/etc/lightdm/lightdm.conf"
execute_config_script "display-managers/configure-lightdm-slick.sh"
deploy_config_direct "display-managers/lightdm-slick-greeter.conf" \
    "/etc/lightdm/slick-greeter.conf" "644"

# SDDM (KDE Plasma)
# Configuración opcional - SDDM funciona sin config
deploy_config_direct "display-managers/sddm.conf" \
    "/etc/sddm.conf" "644"

# GDM (GNOME)
# No requiere configuración - usa Wayland por defecto
```

#### Notas Importantes

- **LightDM GTK Greeter** (XFCE4): No requiere configuración, es el greeter por defecto
- **LightDM Slick Greeter** (Cinnamon): REQUIERE modificar lightdm.conf manualmente
- **GDM** (GNOME): No requiere configuración
- **SDDM** (KDE): Configuración opcional para personalizar tema/comportamiento

### 5. Network (`configs/network/`)

Configuraciones de red (NetworkManager, DNS, hosts).

#### Archivos Disponibles

| Archivo | Destino | Variables |
|---------|---------|-----------|
| `hosts.template` | `/etc/hosts` | `{{HOSTNAME}}` |
| `NetworkManager.conf` | `/etc/NetworkManager/NetworkManager.conf` | Ninguna |
| `resolved.conf` | `/etc/systemd/resolved.conf` | Ninguna |

#### Uso en Scripts

```bash
# Hosts con hostname variable
deploy_config "network/hosts.template" \
    "/etc/hosts" \
    "HOSTNAME=$HOSTNAME"

# NetworkManager directo
deploy_config_direct "network/NetworkManager.conf" \
    "/etc/NetworkManager/NetworkManager.conf" "644"
```

## 🔧 Funciones Helper

El archivo `lib/config-functions.sh` provee funciones para manejar configuraciones.

### Funciones Principales

#### `deploy_config`
Despliega template con sustitución de variables.

```bash
deploy_config <template_file> <destination> [variables...]

# Ejemplo
deploy_config "sudo/doas.conf.template" "/etc/doas.conf" "USERNAME=john"
```

#### `deploy_config_direct`
Copia archivo sin modificaciones.

```bash
deploy_config_direct <source_file> <destination> [permissions]

# Ejemplo
deploy_config_direct "audio/asound.conf" "/etc/asound.conf" "644"
```

#### `execute_config_script`
Ejecuta script de configuración.

```bash
execute_config_script <script_file>

# Ejemplo
execute_config_script "firewall/ufw-basic.sh"
```

#### `validate_sudoers` / `validate_doas`
Valida sintaxis antes de aplicar.

```bash
validate_sudoers "/etc/sudoers.d/10-alie-user"
validate_doas "/etc/doas.conf"
```

#### `backup_config`
Crea backup antes de modificar.

```bash
backup_config "/etc/doas.conf"
# Crea: /var/backups/alie-configs/doas.conf.20250114-153045.bak
```

#### `list_configs`
Lista configuraciones disponibles.

```bash
list_configs          # Lista categorías
list_configs sudo     # Lista archivos en categoría
```

## 📝 Guía de Uso para Desarrolladores

### Agregar Nueva Configuración

1. **Crear archivo en `/configs/<categoría>/`**

```bash
# Crear directorio si no existe
mkdir -p configs/nueva-categoria

# Crear archivo de configuración
cat > configs/nueva-categoria/mi-config.conf << 'EOF'
# Mi configuración
parametro = valor
EOF
```

2. **Si requiere variables, usar `.template`**

```bash
cat > configs/nueva-categoria/mi-config.template << 'EOF'
# Usuario: {{USERNAME}}
user = {{USERNAME}}
home = /home/{{USERNAME}}
EOF
```

3. **Actualizar script de instalación**

```bash
# En install/XXX-script.sh
source "$LIB_DIR/config-functions.sh"

deploy_config "nueva-categoria/mi-config.template" \
    "/etc/mi-app/config" \
    "USERNAME=$USERNAME"
```

### Modificar Configuración Existente

1. **Editar archivo en `/configs/`** (NO en el script)
2. **Probar cambios** antes de commit
3. **Documentar** cambios en este README si son significativos

### Variables Soportadas

| Variable | Descripción | Usada en |
|----------|-------------|----------|
| `{{USERNAME}}` | Nombre de usuario creado | sudo, doas, network |
| `{{HOSTNAME}}` | Nombre del host | network/hosts |

Para agregar más variables, modificar `deploy_config()` en `config-functions.sh`.

## 🎨 Ejemplos de Uso Completo

### Ejemplo 1: Deploy Completo de Sudo

```bash
#!/bin/bash
source "$LIB_DIR/shared-functions.sh"
source "$LIB_DIR/config-functions.sh"

USERNAME="john"
PRIV_TOOL="sudo"

# Backup de configuración existente
backup_config "/etc/sudoers.d/10-alie-$USERNAME"

# Desplegar configuración de usuario
deploy_config "sudo/sudoers-user-primary.template" \
    "/etc/sudoers.d/10-alie-$USERNAME" \
    "USERNAME=$USERNAME"

# Establecer permisos críticos
chmod 440 "/etc/sudoers.d/10-alie-$USERNAME"

# Desplegar configuración global
deploy_config_direct "sudo/sudoers-defaults-primary" \
    "/etc/sudoers.d/00-alie-defaults" "440"

# Validar antes de continuar
if validate_sudoers "/etc/sudoers.d/10-alie-$USERNAME"; then
    print_success "Sudo configured successfully"
else
    print_error "Invalid sudoers configuration!"
    exit 1
fi
```

### Ejemplo 2: Deploy Firewall con Selección

```bash
#!/bin/bash
source "$LIB_DIR/shared-functions.sh"
source "$LIB_DIR/config-functions.sh"

print_info "Select firewall type:"
echo "1. UFW (Simple)"
echo "2. Firewalld (Advanced)"
read -p "Choice [1-2]: " fw_choice

print_info "Select profile:"
echo "1. Basic (Server)"
echo "2. Desktop (Development)"
read -p "Choice [1-2]: " profile_choice

# Determinar script a ejecutar
if [ "$fw_choice" = "1" ]; then
    if [ "$profile_choice" = "1" ]; then
        script="firewall/ufw-basic.sh"
    else
        script="firewall/ufw-desktop.sh"
    fi
else
    if [ "$profile_choice" = "1" ]; then
        script="firewall/firewalld-basic.sh"
    else
        script="firewall/firewalld-desktop.sh"
    fi
fi

# Ejecutar configuración
execute_config_script "$script"
```

### Ejemplo 3: Deploy Audio Completo

```bash
#!/bin/bash
source "$LIB_DIR/shared-functions.sh"
source "$LIB_DIR/config-functions.sh"

print_step "Configuring Audio System"

# ALSA global
backup_config "/etc/asound.conf"
deploy_config_direct "audio/asound.conf" "/etc/asound.conf" "644"

# PipeWire
mkdir -p /etc/pipewire
backup_config "/etc/pipewire/pipewire.conf"
deploy_config_direct "audio/pipewire.conf" "/etc/pipewire/pipewire.conf" "644"

# WirePlumber
mkdir -p /etc/wireplumber/main.conf.d
deploy_config_direct "audio/wireplumber.conf" \
    "/etc/wireplumber/main.conf.d/50-alie.conf" "644"

print_success "Audio configuration deployed"
```

## ⚠️ Consideraciones de Seguridad

### Permisos Críticos

| Archivo | Permisos | Propietario | Razón |
|---------|----------|-------------|-------|
| `/etc/sudoers.d/*` | `440` | `root:root` | Seguridad sudo |
| `/etc/doas.conf` | `400` | `root:root` | Requerido por doas |
| Firewall configs | `644` | `root:root` | Lectura pública OK |
| Audio configs | `644` | `root:root` | Lectura pública OK |

### Validación Obligatoria

**NUNCA** desplegar sudo/doas sin validar:

```bash
# MAL ❌
deploy_config "sudo/sudoers-user.template" "/etc/sudoers.d/user"

# BIEN ✅
deploy_config "sudo/sudoers-user.template" "/etc/sudoers.d/user"
chmod 440 "/etc/sudoers.d/user"
validate_sudoers "/etc/sudoers.d/user" || exit 1
```

## 🔍 Testing

### Test Individual

```bash
# Test validación
bash lib/config-functions.sh
source lib/shared-functions.sh
source lib/config-functions.sh
validate_sudoers configs/sudo/sudoers-defaults-primary
```

### Test Deploy (en VM/Container)

```bash
# Test en entorno aislado
SCRIPT_DIR="$(pwd)/install"
LIB_DIR="$(pwd)/lib"

source "$LIB_DIR/shared-functions.sh"
source "$LIB_DIR/config-functions.sh"

# Test deploy
deploy_config_direct "audio/asound.conf" "/tmp/test-asound.conf"
cat /tmp/test-asound.conf
```

## 📊 Migración desde Scripts Antiguos

### Antes (Configuración Inline)

```bash
# En install/201-user-setup.sh
cat > /etc/doas.conf << EOF
permit persist :wheel
permit persist $USERNAME
EOF
chmod 400 /etc/doas.conf
```

### Después (Configuración Modular)

```bash
# En install/201-user-setup.sh
source "$LIB_DIR/config-functions.sh"

deploy_config "sudo/doas.conf.template" \
    "/etc/doas.conf" \
    "USERNAME=$USERNAME"
chmod 400 /etc/doas.conf
validate_doas "/etc/doas.conf"
```

## 🚀 Roadmap

### Implementado ✅
- [x] Sistema de plantillas con variables
- [x] Funciones helper para deploy
- [x] Validación de sudo/doas
- [x] Backup automático
- [x] Configs de firewall, audio, network, sudo

### Pendiente 📋
- [ ] Migrar todos los scripts a usar config externo
- [ ] Git configs
- [ ] Vim/Neovim configs
- [ ] Sistema de "perfiles" (server, desktop, minimal)
- [ ] Wizard interactivo para selección de configs

### Shell Configurations (`configs/shell/`)

Configuraciones optimizadas para diferentes shells disponibles en Arch Linux.

#### Archivos Disponibles

| Archivo | Shell | Destino | Descripción |
|---------|-------|---------|-------------|
| `bashrc` | Bash | `~/.bashrc` | Enhanced Bash config con aliases y colors |
| `zshrc` | Zsh | `~/.zshrc` | Zsh con autocompletion, historia mejorada |
| `config.fish` | Fish | `~/.config/fish/config.fish` | Fish con sintaxis moderna |
| `tcshrc` | Tcsh | `~/.tcshrc` | TENEX C Shell con prompt coloreado |
| `kshrc` | Korn Shell | `~/.kshrc` | Korn Shell con funciones útiles |

#### Características Comunes

Todas las configuraciones incluyen:
- ✅ Prompt coloreado y personalizado
- ✅ Aliases útiles (ls, ll, la, grep con colores)
- ✅ Historial configurado (1000+ comandos)
- ✅ Man pages con colores
- ✅ Aliases de seguridad (rm -i, cp -i, mv -i)
- ✅ Configuración de editor por defecto

#### Uso en Scripts

Las configuraciones se despliegan automáticamente en `install/201-user-setup.sh`:

```bash
# La función configure_shell_environment() maneja el deploy
configure_shell_environment "$username" "$shell_name"

# Soporta: bash, zsh, fish, tcsh, ksh
# Dash no requiere configuración (POSIX shell minimalista)
```

#### Notas por Shell

- **Bash**: Config mejorado opcional, sistema ya tiene uno básico
- **Zsh**: Requiere configuración para aprovechar sus features
- **Fish**: Configuración en directorio separado (~/.config/fish/)
- **Tcsh**: Sintaxis estilo C, variables con `setenv`
- **Ksh**: Compatible con Bash, funciones adicionales (extract, up)
- **Dash**: No requiere config, solo variables de entorno del sistema

## 📚 Referencias

- [ArchWiki - sudo](https://wiki.archlinux.org/title/Sudo)
- [ArchWiki - doas](https://wiki.archlinux.org/title/Doas)
- [ArchWiki - PipeWire](https://wiki.archlinux.org/title/PipeWire)
- [ArchWiki - Firewalld](https://wiki.archlinux.org/title/Firewalld)
- [ArchWiki - UFW](https://wiki.archlinux.org/title/Uncomplicated_Firewall)

---

**Última actualización**: 2025-01-14  
**Versión**: 1.0
