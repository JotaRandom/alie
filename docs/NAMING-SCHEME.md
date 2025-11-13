# LMAE Script Naming Scheme

## Nomenclatura Semántica de Scripts

Los scripts de instalación siguen un esquema de numeración de 3 dígitos que indica:

### Formato: `XYZ-nombre-script.sh`

Donde:
- **X (primer dígito)**: Entorno de ejecución
- **Y (segundo dígito)**: Permisos requeridos  
- **Z (tercer dígito)**: Número de paso

---

## Primer Dígito (X): Entorno de Ejecución

| Valor | Entorno | Descripción |
|-------|---------|-------------|
| **0** | Live CD/USB | Se ejecuta desde el medio de instalación de Arch Linux |
| **1** | Chroot | Se ejecuta dentro del entorno chroot (`arch-chroot /mnt`) |
| **2** | Sistema Instalado | Se ejecuta en el sistema ya instalado y reiniciado |

---

## Segundo Dígito (Y): Permisos Requeridos

| Valor | Permisos | Descripción |
|-------|----------|-------------|
| **0** | Solo Root | Debe ejecutarse como superusuario (root/sudo) |
| **1** | Solo Usuario | Debe ejecutarse como usuario regular (NO root) |
| **2** | Ambos | Puede ejecutarse como root o usuario regular |

---

## Tercer Dígito (Z): Número de Paso

Indica el orden de ejecución dentro del mismo entorno y permisos.

- **1**: Primer paso
- **2**: Segundo paso
- **3**: Tercer paso
- etc.

---

## Scripts Actuales

| Script | Numeración | Entorno | Permisos | Paso | Descripción |
|--------|------------|---------|----------|------|-------------|
| `001-base-install.sh` | **0**-**0**-**1** | Live CD | Root | 1 | Instalación del sistema base |
| `101-configure-system.sh` | **1**-**0**-**1** | Chroot | Root | 1 | Configuración del sistema |
| `201-desktop-install.sh` | **2**-**0**-**1** | Instalado | Root | 1 | Instalación del escritorio |
| `211-install-yay.sh` | **2**-**1**-**1** | Instalado | Usuario | 1 | Instalación de YAY |
| `212-install-packages.sh` | **2**-**1**-**2** | Instalado | Usuario | 2 | Instalación de paquetes |

---

## Ventajas del Esquema

### 1. **Claridad Visual**
- Al leer el nombre, inmediatamente sabes dónde y cómo ejecutarlo
- No necesitas consultar documentación para saber los requisitos

### 2. **Prevención de Errores**
- Difícil ejecutar un script en el entorno equivocado
- Los permisos incorrectos son evidentes

### 3. **Escalabilidad**
- Fácil agregar nuevos scripts manteniendo la lógica
- Ejemplo: `202-additional-setup.sh` (Sistema instalado, root, paso 2)

### 4. **Organización**
- Scripts agrupados lógicamente en el filesystem
- Ordenamiento alfabético = ordenamiento lógico

---

## Ejemplos de Uso

### ✓ Correcto

```bash
# En Live USB
sudo bash 001-base-install.sh

# En chroot
bash 101-configure-system.sh  # Ya eres root en chroot

# Después de reiniciar (como root)
sudo bash 201-desktop-install.sh

# Después de reiniciar (como usuario)
bash 211-install-yay.sh
bash 212-install-packages.sh
```

### ✗ Incorrecto

```bash
# ❌ Ejecutar script de chroot en Live CD
sudo bash 101-configure-system.sh  

# ❌ Ejecutar script de usuario como root
sudo bash 211-install-yay.sh

# ❌ Ejecutar script de Live CD en sistema instalado
bash 001-base-install.sh
```

---

## Migración desde Numeración Antigua

| Antigua | Nueva | Cambio |
|---------|-------|--------|
| `01-base-install.sh` | `001-base-install.sh` | 01 → 001 |
| `02-configure-system.sh` | `101-configure-system.sh` | 02 → 101 |
| `03-desktop-install.sh` | `201-desktop-install.sh` | 03 → 201 |
| `04-install-yay.sh` | `211-install-yay.sh` | 04 → 211 |
| `05-install-packages.sh` | `212-install-packages.sh` | 05 → 212 |

---

## Extensibilidad Futura

### Ejemplos de posibles scripts adicionales:

- `002-partition-helper.sh` - Helper de particionado (Live CD, root, paso 2)
- `102-install-bootloader.sh` - Instalador de bootloader alternativo (Chroot, root, paso 2)
- `221-configure-firewall.sh` - Configurar firewall (Instalado, ambos, paso 1)
- `213-install-development.sh` - Paquetes de desarrollo (Instalado, usuario, paso 3)

El esquema permite hasta:
- **10 entornos** diferentes (0-9)
- **10 tipos de permisos** (0-9)
- **10 pasos** por categoría (0-9)

Total: **1000 combinaciones posibles**

---

## Convención de Nombres

Además de la numeración, los nombres de scripts deben:

1. Usar **minúsculas**
2. Usar **guiones** para separar palabras
3. Ser **descriptivos** del propósito
4. Terminar en `.sh`

Ejemplo: `211-install-yay.sh` ✓

No: `211_InstallYAY.sh` ✗

---

## Verificación

Para verificar que estás en el entorno correcto antes de ejecutar un script:

```bash
# Verificar si estás en Live CD
[ -f /etc/arch-release ] && echo "Live USB o Sistema Instalado"

# Verificar si estás en chroot
[ "$(stat -c %d:%i /)" != "$(stat -c %d:%i /proc/1/root/.)" ] && echo "En chroot"

# Verificar si eres root
[ $EUID -eq 0 ] && echo "Ejecutando como root"
```

Todos los scripts incluyen estas verificaciones automáticamente.

---

**Última actualización**: Noviembre 2025
