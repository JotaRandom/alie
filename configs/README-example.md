# Archivos de ejemplo y versiones "como debería verse"

Este directorio contiene copias planas y ejemplos de las configuraciones gestionadas por los scripts de `configs/`.

- Los archivos con sufijo `.plain` son copias byte-a-byte del contenido que debe pegarse en el sistema si quieres aplicar la configuración manualmente.
- Los archivos con sufijo `.example` explican el efecto de los scripts `.sh` y, cuando aplica, incluyen el contenido final resultante que el script dejaría en el sistema.

Propósito:
- Facilitar revisiones rápidas sin ejecutar scripts.
- Permitir copiar/pegar la configuración en `/etc` u otros destinos de forma segura.

Precauciones:
- Los scripts pueden crear backups y comprobar `EUID`; revisar el `.example` antes de aplicar.
- Para cambios que afectan a servicios (firewall, display manager), probar en VM antes de producción.