# LMAE Shared Functions Library

## Descripción

`shared-functions.sh` es una biblioteca de funciones compartidas que centraliza código común usado en todos los scripts de instalación de LMAE. Esto mejora la mantenibilidad y consistencia del proyecto.

## Uso Básico

Al inicio de cada script, incluye:

```bash
#!/bin/bash

# Cargar funciones compartidas
SCRIPT_DIR="$(dirname "$0")"
source "$SCRIPT_DIR/shared-functions.sh"

# Ahora puedes usar todas las funciones
show_lmae_banner
print_step "Mi Script"
```

## Funciones Disponibles

### 🎨 Definiciones de Colores

Variables globales para colorear el output:

```bash
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'  # No Color
```

**Ejemplo:**
```bash
echo -e "${GREEN}Texto en verde${NC}"
echo -e "${RED}Error en rojo${NC}"
```

---

### 📝 Funciones de Impresión

#### `print_info <mensaje>`
Muestra un mensaje informativo en cyan con icono ℹ

**Ejemplo:**
```bash
print_info "Descargando paquetes..."
# Output: ℹ Descargando paquetes...
```

#### `print_success <mensaje>`
Muestra un mensaje de éxito en verde con icono ✓

**Ejemplo:**
```bash
print_success "Instalación completada"
# Output: ✓ Instalación completada
```

#### `print_warning <mensaje>`
Muestra una advertencia en amarillo con icono ⚠

**Ejemplo:**
```bash
print_warning "El archivo ya existe"
# Output: ⚠ El archivo ya existe
```

#### `print_error <mensaje>`
Muestra un error en rojo con icono ✗ (a stderr)

**Ejemplo:**
```bash
print_error "Falló la operación"
# Output: ✗ Falló la operación
```

#### `print_step <título>`
Muestra un encabezado de paso en magenta con separador

**Ejemplo:**
```bash
print_step "STEP 1: Configuración"
# Output:
# ═══════════════════════════════════════════════════════════
#   STEP 1: Configuración
# ═══════════════════════════════════════════════════════════
```

---

### 🔄 Funciones de Utilidad

#### `retry_command <intentos> <comando>`
Reintenta un comando con backoff exponencial

**Parámetros:**
- `intentos`: Número máximo de intentos
- `comando`: Comando a ejecutar (como string)

**Returns:** 0 si tiene éxito, 1 si falla todos los intentos

**Ejemplo:**
```bash
if retry_command 3 "pacman -Sy"; then
    print_success "Base de datos actualizada"
else
    print_error "Falló después de 3 intentos"
    exit 1
fi
```

#### `wait_for_operation <check_command> <timeout> <intervalo>`
Espera hasta que una condición se cumpla o timeout

**Parámetros:**
- `check_command`: Comando que retorna 0 cuando la condición se cumple
- `timeout`: Tiempo máximo de espera en segundos (default: 30)
- `intervalo`: Intervalo de polling en segundos (default: 1)

**Returns:** 0 si la condición se cumple, 1 si timeout

**Ejemplo:**
```bash
if wait_for_operation "mountpoint -q /mnt" 30 1; then
    print_success "/mnt está montado"
else
    print_error "Timeout esperando montaje"
fi
```

---

### ✅ Validación de Entorno

#### `verify_chroot()`
Verifica que el script está corriendo en un entorno chroot

**Returns:** 0 si está en chroot, 1 si no

**Ejemplo:**
```bash
if ! verify_chroot; then
    print_error "Este script debe ejecutarse en chroot"
    exit 1
fi
```

#### `require_root()`
Verifica que el script está corriendo como root

**Returns:** 0 si es root, 1 si no

**Ejemplo:**
```bash
if ! require_root; then
    exit 1
fi
```

#### `require_non_root()`
Verifica que el script NO está corriendo como root

**Returns:** 0 si no es root, 1 si es root

**Ejemplo:**
```bash
if ! require_non_root; then
    exit 1
fi
```

---

### 🎪 Funciones de Banner

#### `show_lmae_banner()`
Muestra el banner principal de LMAE

**Ejemplo:**
```bash
show_lmae_banner
# Muestra el logo ASCII de LMAE
```

#### `show_warning_banner()`
Muestra un banner de advertencia

**Ejemplo:**
```bash
show_warning_banner
# Muestra advertencia de script experimental
```

---

### 💾 Persistencia de Datos

#### `load_install_info [archivo]`
Carga variables desde archivo de configuración

**Parámetros:**
- `archivo`: Ruta al archivo (default: `/root/.lmae-install-info`)

**Returns:** 0 si el archivo existe, 1 si no

**Ejemplo:**
```bash
# Cargar configuración guardada
load_install_info

# Ahora puedes usar las variables cargadas
echo "Boot mode: $BOOT_MODE"
echo "Root partition: $ROOT_PARTITION"
```

#### `save_install_info <archivo> <var1> <var2> ...`
Guarda variables en archivo de configuración

**Parámetros:**
- `archivo`: Ruta donde guardar
- `var1, var2, ...`: Nombres de variables a guardar

**Ejemplo:**
```bash
BOOT_MODE="UEFI"
ROOT_PARTITION="/dev/sda2"
CPU_VENDOR="intel"

save_install_info "/mnt/root/.lmae-install-info" \
    BOOT_MODE \
    ROOT_PARTITION \
    CPU_VENDOR
```

**Archivo generado:**
```bash
BOOT_MODE=UEFI
ROOT_PARTITION=/dev/sda2
CPU_VENDOR=intel
```

---

### 🌐 Funciones de Red

#### `check_internet [host] [timeout]`
Verifica conectividad a internet

**Parámetros:**
- `host`: Host a pingear (default: `archlinux.org`)
- `timeout`: Timeout en segundos (default: `5`)

**Returns:** 0 si hay conexión, 1 si no

**Ejemplo:**
```bash
if check_internet; then
    print_success "Internet disponible"
else
    print_error "Sin conexión a internet"
fi
```

#### `wait_for_internet [intentos]`
Espera hasta que haya conexión a internet

**Parámetros:**
- `intentos`: Número máximo de intentos (default: `10`)

**Returns:** 0 si conecta, 1 si timeout

**Ejemplo:**
```bash
if ! wait_for_internet 5; then
    print_error "No se pudo establecer conexión"
    exit 1
fi
```

---

### 💿 Helpers de Particiones

#### `is_mounted <partición>`
Verifica si una partición está montada

**Returns:** 0 si está montada, 1 si no

**Ejemplo:**
```bash
if is_mounted "/dev/sda2"; then
    print_success "/dev/sda2 está montada"
fi
```

#### `safe_unmount <punto_montaje>`
Desmonta una partición de forma segura (con force si es necesario)

**Returns:** 0 si tiene éxito, 1 si falla

**Ejemplo:**
```bash
if safe_unmount "/mnt"; then
    print_success "/mnt desmontado"
else
    print_error "No se pudo desmontar /mnt"
    exit 1
fi
```

---

### 📦 Helpers de Gestor de Paquetes

#### `install_packages <paquete1> <paquete2> ...`
Instala paquetes con lógica de reintentos

**Ejemplo:**
```bash
if install_packages vim git htop; then
    print_success "Herramientas instaladas"
fi
```

#### `update_package_db()`
Actualiza la base de datos de paquetes con reintentos

**Ejemplo:**
```bash
if ! update_package_db; then
    print_error "No se pudo actualizar la base de datos"
    exit 1
fi
```

---

## Variables de Debug

Establece `DEBUG=1` para ver información adicional:

```bash
export DEBUG=1
source shared-functions.sh

load_install_info  # Mostrará variables cargadas
save_install_info ...  # Mostrará variables guardadas
```

---

## Ejemplo Completo

```bash
#!/bin/bash
set -e

# Cargar funciones compartidas
SCRIPT_DIR="$(dirname "$0")"
source "$SCRIPT_DIR/shared-functions.sh"

# Verificar que se ejecuta como root
if ! require_root; then
    exit 1
fi

# Mostrar banner
show_lmae_banner
show_warning_banner

# Cargar configuración previa
load_install_info

# Verificar internet
if ! wait_for_internet; then
    print_error "Se requiere conexión a internet"
    exit 1
fi

# Instalar paquetes
print_step "STEP 1: Installing Packages"
install_packages base-devel git vim

# Guardar configuración para siguiente script
MY_VAR="valor"
save_install_info "/tmp/config" MY_VAR BOOT_MODE

print_step "✓ Script Completed!"
```

---

## Migración de Scripts Existentes

### Antes:
```bash
RED='\033[0;31m'
GREEN='\033[0;32m'
# ... más colores

print_error() {
    echo -e "${RED}✗ ${NC}$1" >&2
}
# ... más funciones

echo -e "${GREEN}✓${NC} Success"
```

### Después:
```bash
source "$(dirname "$0")/shared-functions.sh"

print_success "Success"
```

---

## Ventajas

✅ **Mantenibilidad**: Cambia una función, afecta todos los scripts  
✅ **Consistencia**: Misma UI en todos los scripts  
✅ **Menos código**: Scripts más cortos y legibles  
✅ **Reutilización**: No duplicar lógica compleja (retry, polling, etc)  
✅ **Testing**: Más fácil probar funciones aisladas  

---

## Notas

- Todas las funciones manejan errores apropiadamente
- Las funciones de red incluyen lógica de reintento
- Los helpers de particiones son safe por defecto
- El archivo puede ejecutarse directamente para ver ayuda: `bash shared-functions.sh`
