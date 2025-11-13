# ALIE Changelog

## [Unreleased] - Reorganización y Modernización

### 🎯 Cambios Mayores

#### Estructura de Directorios Reorganizada
- **Antes**: Scripts planos en `src/`
- **Ahora**: Organización modular
  ```
  src/
  ├── ALIE                    # Lanzador wrapper
  ├── 00-install-ALIE.sh      # Instalador maestro
  ├── install/                # Scripts de instalación (01-05)
  └── lib/                    # Bibliotecas compartidas
  ```

#### Sistema de Funciones Compartidas
- Creada biblioteca `lib/shared-functions.sh` (419 líneas)
- Eliminadas **316+ líneas** de código duplicado
- Funciones centralizadas:
  - UI: `print_info`, `print_success`, `print_warning`, `print_error`, `print_step`
  - Utilidades: `retry_command`, `wait_for_operation`
  - Validación: `verify_chroot`, `require_root`, `require_non_root`
  - Red: `check_internet`, `wait_for_internet`
  - Persistencia: `save_install_info`, `load_install_info`
  - Progreso: `save_progress`, `is_step_completed`, `get_installation_step`, `clear_progress`
  - Particiones: `is_mounted`, `safe_unmount`
  - Paquetes: `install_packages`, `update_package_db`
  - Banners: `show_ALIE_banner`, `show_warning_banner`

#### Sistema de Seguimiento de Progreso
- El instalador ahora guarda progreso automáticamente en `.ALIE-progress`
- Marcadores de progreso:
  - `01-base-installed`
  - `02-system-configured`
  - `03-desktop-installed`
  - `04-yay-installed`
  - `05-packages-installed`
- Permite continuar la instalación después de reinicios
- No necesitas recordar qué script ejecutar siguiente

#### Modo Manual Agregado
- Nuevo flag `--manual` o `-m` en script 00
- Permite elegir manualmente qué script ejecutar
- Muestra todos los pasos disponibles con descripciones
- Valida permisos antes de ejecutar
- Útil para depuración y personalizaciones

### ✨ Mejoras por Script

#### 00-install-ALIE.sh (Script Maestro)
- ✅ Detección automática de entorno (livecd, chroot, installed-base, installed-desktop)
- ✅ Sistema de seguimiento de progreso
- ✅ Modo automático (continúa desde donde dejó)
- ✅ Modo manual (elige cualquier paso)
- ✅ Menú interactivo mejorado
- ✅ Validaciones de seguridad

#### 01-base-install.sh
- ✅ Usa funciones compartidas (-157 líneas, 14% reducción)
- ✅ UI mejorada con colores y pasos claros
- ✅ Asistente de red interactivo
- ✅ Detección automática CPU para microcode
- ✅ Eliminada duplicación de código
- ✅ Guarda progreso automáticamente
- ✅ Requiere permisos root

#### 02-configure-system.sh
- ✅ Usa funciones compartidas (-159 líneas, 32% reducción)
- ✅ UI mejorada con print_* functions
- ✅ Verificación automática de chroot
- ✅ Eliminada duplicación de CPU/microcode
- ✅ Guarda progreso automáticamente
- ✅ Requiere permisos root

#### 03-desktop-install.sh
- ✅ Integrado con funciones compartidas
- ✅ UI modernizada con colores
- ✅ Uso de `install_packages` helper
- ✅ Validación mejorada de nombres de usuario
- ✅ Guarda progreso automáticamente
- ✅ Requiere permisos root

#### 04-install-yay.sh
- ✅ Integrado con funciones compartidas
- ✅ UI mejorada con print_* functions
- ✅ Mejor manejo de directorio existente
- ✅ Guarda progreso automáticamente
- ✅ Requiere usuario regular (NOT root)

#### 05-install-packages.sh
- ✅ Integrado con funciones compartidas
- ✅ UI modernizada con pasos claros
- ✅ Verificación de YAY antes de continuar
- ✅ Instalación por categorías con feedback
- ✅ Guarda progreso automáticamente
- ✅ Requiere usuario regular (NOT root)

### 🔒 Mejoras de Seguridad

- **Validación de permisos**: Scripts validan automáticamente si requieren root o usuario
- **Trap handlers**: Todos los scripts tienen manejo de errores con cleanup
- **Set -e**: Todos los scripts paran ante errores
- **Verificación de chroot**: Script 02 verifica que está en chroot correctamente

### 📚 Documentación

- ✅ Creado `lib/SHARED-FUNCTIONS.md` - Documentación completa de funciones compartidas
- ✅ Actualizado `src/README.md` con nueva estructura
- ✅ Actualizado `src/README.es.md` con guía de uso
- ✅ Creado `CHANGELOG.md` (este archivo)

### 🛠️ Herramientas Nuevas

- **Script wrapper `ALIE`**: Lanzador simple que llama a 00-install-ALIE.sh
- **Modo manual**: `bash ALIE --manual` para elegir scripts manualmente

### 📊 Estadísticas

- **Líneas de código duplicado eliminadas**: 316+
- **Reducción en 01-base-install.sh**: 14%
- **Reducción en 02-configure-system.sh**: 32%
- **Funciones compartidas**: 419 líneas
- **Total de scripts modernizados**: 6

### 🚀 Uso

#### Modo Automático (Recomendado)
```bash
bash ALIE
# El instalador detecta automáticamente tu entorno y continúa
```

#### Modo Manual
```bash
bash ALIE --manual
# Elige manualmente qué script ejecutar
```

#### Scripts Individuales
```bash
bash install/01-base-install.sh  # Base system
bash install/02-configure-system.sh  # Configuration
bash install/03-desktop-install.sh  # Desktop environment
bash install/04-install-yay.sh  # YAY AUR helper
bash install/05-install-packages.sh  # Mint packages
```

### 🎯 Beneficios

1. **Mantenibilidad**: Código centralizado es más fácil de mantener
2. **Consistencia**: UI uniforme en todos los scripts
3. **Resiliencia**: Sistema de progreso permite continuar después de fallos
4. **Flexibilidad**: Modo manual para casos especiales
5. **Claridad**: Estructura de directorios lógica y organizada
6. **Seguridad**: Validaciones automáticas de permisos

### 🔄 Migración

Si tienes scripts antiguos:
1. Los scripts ahora están en `install/` en lugar de `src/` directamente
2. Usa `bash ALIE` o `bash 00-install-ALIE.sh` como punto de entrada
3. Las funciones compartidas están en `lib/shared-functions.sh`

### 🐛 Correcciones

- Eliminada lógica duplicada de detección de CPU
- Eliminada instalación duplicada de microcode
- Corregida detección de BOOT_MODE duplicada
- Mejorado manejo de errores en todos los scripts

---

## Notas de Desarrollo

### Por qué Shared Functions?
- Antes: Cada script tenía su propia copia de las mismas funciones
- Problema: Cambios requerían editar múltiples archivos
- Solución: Una sola fuente de verdad en `lib/shared-functions.sh`

### Por qué Progress Tracking?
- Antes: Usuario tenía que recordar qué script ejecutar después de reiniciar
- Problema: Fácil perder el rastro, ejecutar scripts incorrectos
- Solución: Sistema automático que recuerda el progreso

### Por qué Reorganización de Directorios?
- Antes: 6 scripts + shared-functions todos en `src/`
- Problema: Difícil distinguir qué es qué
- Solución: 
  - `install/` = Scripts de instalación
  - `lib/` = Bibliotecas/utilidades
  - Raíz `src/` = Solo entry points (00, ALIE)

---

**Nota**: Esta es una reorganización mayor. Los scripts mantienen la misma funcionalidad pero con mejor estructura y mantenibilidad.

