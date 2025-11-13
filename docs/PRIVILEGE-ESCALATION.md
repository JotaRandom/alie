# ALIE - Universal Privilege Escalation System

## Overview

ALIE ahora incluye un sistema completo de escalación de privilegios que soporta **4 herramientas** modernas:

1. **sudo** - Tradicional (más común)
2. **doas** - Minimalista y seguro
3. **sudo-rs** - Implementación en Rust de sudo
4. **run0** - Moderna escalación de systemd (sin SUID)

## Features

### ✅ Detección Automática
- Detecta automáticamente qué herramientas están disponibles
- Prioriza herramientas modernas (run0 > doas > sudo-rs > sudo)
- Funciona en cualquier sistema Linux

### ✅ Configuración Universal
- Configura cada herramienta según las mejores prácticas
- Incluye aliases de compatibilidad
- Configuración de respaldo automática

### ✅ Funciones Compartidas
- `get_privilege_tool()` - Detecta herramienta disponible
- `run_privileged()` - Ejecuta comando con privilegios
- `has_privilege_access()` - Verifica acceso a privilegios

## Systemd run0 Support

### Características de run0:
- **Sin SUID**: Más seguro, no requiere binarios SUID
- **Integración systemd**: Funciona nativamente con systemd
- **Moderno**: Incluido en systemd v254+
- **Compatible**: Aliases sudo para compatibilidad

### Configuración Automática:
```bash
# Aliases principales
alias sr='run0'              # Comando corto
alias suedit='run0 $EDITOR'  # Editor con privilegios

# Compatibilidad sudo
alias sudo='run0'            # Compatibilidad total
alias sudoedit='run0 $EDITOR'

# run0 específicos
alias run0-shell='run0 --shell'  # Shell root interactivo
alias run0-user='run0 --user'    # Ejecutar como usuario específico
```

## Implementation Files

### Core Library
- **`lib/shared-functions.sh`**: Funciones universales de privilege escalation
  - Detección automática de herramientas
  - Ejecución unificada de comandos privilegiados
  - Verificación de acceso a privilegios

### Configuration Scripts  
- **`install/201-user-setup.sh`**: Configuración de usuarios y privilegios
  - Menú interactivo para seleccionar herramienta
  - Configuración automática de cada herramienta
  - Función `configure_run0()` para systemd run0

### Testing & Demos
- **`demos/test-privilege-system.sh`**: Script de prueba completo
  - Verifica detección de herramientas
  - Testa acceso a privilegios
  - Reporta configuración del sistema

## Usage Examples

### Manual Configuration
```bash
# Configurar usuario con privilegios
sudo ./install/201-user-setup.sh

# Opciones disponibles:
# 1) sudo     - Traditional privilege escalation
# 2) doas     - Minimal and secure alternative  
# 3) sudo-rs  - Rust implementation of sudo
# 4) run0     - Systemd privilege escalation (modern, no SUID)
```

### Using the System
```bash
# Desde cualquier script ALIE
source "./lib/shared-functions.sh"

# Detectar herramienta disponible
PRIV_TOOL=$(get_privilege_tool)
echo "Using: $PRIV_TOOL"

# Ejecutar comando con privilegios
run_privileged "pacman -S package"

# Verificar acceso
if has_privilege_access; then
    echo "Can run privileged commands"
fi
```

## System Compatibility

### Linux Distributions
- ✅ **Arch Linux** - Todas las herramientas disponibles
- ✅ **systemd-based** - Soporte completo para run0
- ✅ **Traditional** - Soporte sudo/doas universal
- ✅ **Embedded** - Detección automática de capacidades

### Requirements
- **run0**: systemd v254+ (automáticamente detectado)
- **doas**: OpenDoas package (configuración automática)
- **sudo-rs**: Rust sudo implementation (configuración estándar)
- **sudo**: Tradicional (siempre funciona como respaldo)

## Benefits

### Security
- **run0**: Sin binarios SUID, más seguro
- **doas**: Configuración mínima, menos superficie de ataque
- **Universal**: Respaldos automáticos garantizan funcionalidad

### Compatibility
- **Backward**: Funciona con scripts existentes
- **Forward**: Adopta herramientas modernas automáticamente
- **Cross-platform**: Detecta capacidades del sistema

### Maintenance
- **Centralized**: Una sola implementación para todo ALIE
- **Consistent**: Comportamiento uniforme en todos los scripts
- **Documented**: Configuración clara y bien documentada

## Testing

```bash
# Ejecutar pruebas del sistema
./demos/test-privilege-system.sh

# Ejemplo de salida:
# ✓ run0: Available (systemd v255)
# ✓ sudo: Available  
# ✓ Privilege access is available
# ✓ Privileged command execution successful
```

Este sistema hace que ALIE sea completamente moderno y compatible con las últimas herramientas de Linux, manteniendo compatibilidad total con sistemas tradicionales.