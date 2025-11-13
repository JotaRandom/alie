# Scripts de Instalación LMAE

Scripts de instalación automatizada para Linux Mint Arch Edition.

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
bash lmae.sh
```

Detecta si estás en:

- **Live CD**: Inicia instalación base
- **Chroot**: Configura el sistema
- **Sistema instalado sin escritorio**: Instala entorno de escritorio
- **Sistema con escritorio**: Instala YAY y paquetes de Mint

El progreso se guarda automáticamente, así que puedes reiniciar entre pasos sin perder el rastro.

### Modo Manual

Elige manualmente qué script ejecutar:

```bash
bash lmae.sh --manual
```

Útil para:
- Re-ejecutar pasos específicos
- Depuración
- Instalaciones personalizadas

## Estructura de Directorios

```
src/
├── lmae.sh                   # Instalador maestro (punto de entrada)
├── install/                  # Scripts de instalación
│   ├── 001-base-install.sh    # Instalación del sistema base
│   ├── 101-configure-system.sh # Configuración del sistema
│   ├── 201-desktop-install.sh # Entorno de escritorio
│   ├── 211-install-yay.sh     # Helper YAY AUR
│   └── 212-install-packages.sh # Paquetes de Linux Mint
├── lib/                      # Bibliotecas compartidas
│   └── shared-functions.sh   # Funciones comunes
└── docs/                     # Documentación
    ├── CHANGELOG.md          # Historial de cambios
    ├── GUIA-RAPIDA.md        # Referencia rápida
    ├── METRICAS.md           # Métricas del proyecto
    ├── RESUMEN-MODERNIZACION.md # Resumen de modernización
    └── shared/               # Docs de biblioteca
        └── SHARED-FUNCTIONS.md # Documentación de funciones
```

## Scripts Disponibles

| # | Script | Ejecutar como | Cuándo |
|---|--------|---------------|--------|
| 0 | `lmae.sh` | root/usuario | En cualquier momento (detecta automáticamente) |
| 1 | `install/001-base-install.sh` | root | Desde medio de instalación |
| 2 | `install/101-configure-system.sh` | root | Dentro de arch-chroot |
| 3 | `install/201-desktop-install.sh` | root | Después del primer reinicio |
| 4 | `install/211-install-yay.sh` | usuario | Después de reiniciar con escritorio |
| 5 | `install/212-install-packages.sh` | usuario | Después de instalar yay |

## Proceso Completo

### Con Instalador Automático (Recomendado)

```bash
# En cada etapa, simplemente ejecuta:
bash lmae.sh
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
bash install/201-desktop-install.sh
reboot

# 5. Después del reinicio (como usuario)
bash install/211-install-yay.sh
bash install/212-install-packages.sh
reboot
```

## Características

### Sistema de Progreso
- El instalador guarda automáticamente tu progreso en `.lmae-progress`
- Puedes reiniciar en cualquier momento y continuar desde donde lo dejaste
- Usa `bash lmae --manual` para borrar el progreso si necesitas empezar de nuevo

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
