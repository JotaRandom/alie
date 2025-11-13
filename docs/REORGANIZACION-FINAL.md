# 📁 Reorganización Final de LMAE

## ✅ Cambios Implementados

### 1. Simplificación del Script de Entrada
- ❌ **Eliminado**: `src/lmae` (wrapper redundante)
- ❌ **Eliminado**: `src/00-install-lmae.sh` 
- ✅ **Creado**: `src/lmae.sh` (único punto de entrada)

**Antes**:
```
src/lmae           ← Wrapper que llama a...
src/00-install-lmae.sh  ← Script real
```

**Ahora**:
```
src/lmae.sh        ← Único script de entrada
```

### 2. Reorganización de Documentación
- ✅ Creado `src/docs/` para toda la documentación del proyecto
- ✅ Creado `src/docs/shared/` para docs de biblioteca compartida

**Documentos movidos**:
- `CHANGELOG.md` → `src/docs/CHANGELOG.md`
- `METRICAS.md` → `src/docs/METRICAS.md`
- `GUIA-RAPIDA.md` → `src/docs/GUIA-RAPIDA.md`
- `RESUMEN-MODERNIZACION.md` → `src/docs/RESUMEN-MODERNIZACION.md`
- `src/lib/SHARED-FUNCTIONS.md` → `src/docs/shared/SHARED-FUNCTIONS.md`

### 3. README Principal Simplificado
El README.md en la raíz ahora:
- ✅ Enfoca en las **guías manuales** (README.en.md, README.es.md)
- ⚠️ Menciona scripts experimentales **mínimamente**
- 🔗 Redirige a `src/README.md` para detalles de scripts

## 📂 Estructura Final

```
LMAE/
├── LICENSE
├── README.md                    # Guía principal (enfoque en manual)
├── README.en.md                 # Guía manual en inglés
├── README.es.md                 # Guía manual en español
├── docs/                        # Documentación antigua (mantener)
│   ├── 01-script-improvements.md
│   └── wiki-compliance-fixes.md
└── src/                         # 🧪 Scripts experimentales
    ├── lmae.sh                  # ⭐ Único punto de entrada
    ├── README.md                # Documentación de scripts
    ├── README.en.md             # Docs en inglés
    ├── README.es.md             # Docs en español
    ├── install/                 # Scripts de instalación
    │   ├── 01-base-install.sh
    │   ├── 02-configure-system.sh
    │   ├── 03-desktop-install.sh
    │   ├── 04-install-yay.sh
    │   └── 05-install-packages.sh
    ├── lib/                     # Biblioteca compartida
    │   └── shared-functions.sh
    └── docs/                    # 📚 Documentación del proyecto
        ├── CHANGELOG.md
        ├── GUIA-RAPIDA.md
        ├── METRICAS.md
        ├── RESUMEN-MODERNIZACION.md
        └── shared/              # Docs de biblioteca
            └── SHARED-FUNCTIONS.md
```

## 🎯 Filosofía de la Reorganización

### README Principal (Raíz)
- **Propósito**: Guía de instalación manual (estable, probada)
- **Audiencia**: Todos los usuarios
- **Contenido**: 
  - Enlaces a guías manuales (README.en.md, README.es.md)
  - Mención mínima de scripts experimentales
  - Redirige a `src/` para usuarios avanzados

### src/ (Scripts Experimentales)
- **Propósito**: Automatización experimental
- **Audiencia**: Usuarios avanzados que entienden los riesgos
- **Contenido**:
  - `lmae.sh` - Script maestro
  - `install/` - Scripts de instalación por pasos
  - `lib/` - Funciones compartidas
  - `docs/` - Documentación completa del proyecto

### docs/ (Raíz)
- **Propósito**: Documentación histórica/técnica
- **Contenido**: Mejoras y fixes históricos

### src/docs/
- **Propósito**: Documentación del proyecto de scripts
- **Contenido**: 
  - Changelog, métricas, guías
  - Documentación de funciones compartidas

## 🚀 Uso Actualizado

### Para Usuario Típico
```bash
# Sigue la guía manual en README.en.md o README.es.md
```

### Para Usuario Avanzado (Experimental)
```bash
cd src/
bash lmae.sh              # Modo automático
bash lmae.sh --manual     # Modo manual
```

## 📝 Referencias Actualizadas

Todos los archivos ahora usan las rutas correctas:
- ✅ `bash lmae.sh` (no `bash lmae` ni `bash 00-install-lmae.sh`)
- ✅ `src/docs/` para documentación
- ✅ `src/docs/shared/` para docs de funciones compartidas

## 🔍 Comparación

| Aspecto | Antes | Ahora |
|---------|-------|-------|
| Scripts de entrada | 2 (lmae + 00-install-lmae.sh) | 1 (lmae.sh) |
| Docs en raíz | 4 archivos | 0 archivos |
| Claridad | Confuso | Claro |
| README principal | Enfocado en scripts | Enfocado en manual |
| Experimentación | Prominente | Minimizada |

## ✨ Beneficios

1. **Menos confusión**: Un solo script de entrada (`lmae.sh`)
2. **Mejor organización**: Toda la documentación en `src/docs/`
3. **Raíz limpia**: README enfocado en instalación manual estable
4. **Claridad**: Scripts experimentales claramente etiquetados como tal
5. **Navegabilidad**: Estructura lógica y predecible

## 🎓 Decisiones de Diseño

### ¿Por qué un solo script?
- No necesitamos un wrapper y un script principal
- Simplifica el uso: siempre es `bash lmae.sh`
- Menos archivos = menos confusión

### ¿Por qué src/docs/?
- Mantiene documentación cerca del código que documenta
- Separa docs de scripts de docs del proyecto principal
- Facilita encontrar información relacionada

### ¿Por qué minimizar scripts en README principal?
- Los scripts son **experimentales** y no deberían ser el foco principal
- La guía manual es más estable y probada
- Usuarios nuevos deberían seguir el manual
- Usuarios avanzados encontrarán los scripts fácilmente en `src/`

---

**Fecha**: 2025-11-12  
**Estado**: ✅ Completado  
**Próximos pasos**: Ninguno - estructura final lista para uso
