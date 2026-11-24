# Administración del correo entrante en canales de Zulip

**Grupo PAS Squad** (Milton Alvarado, Rodolfo Campos, Michael Jimenez)

Este repositorio contiene la propuesta académica para el **Issue #40267** de Zulip, desarrollada para el curso de Procesos de Ingeniería de Software (Universidad CENFOTEC).

## Alcance del Proyecto

El objetivo principal es implementar controles administrativos sobre el ingreso de mensajes por correo electrónico a los canales de Zulip. La mejora permite a los administradores:

- **Política Global (RF1):** Habilitar o suspender el ingreso por correo en toda la organización.
- **Política Local (RF2):** Permitir o suspender el ingreso a nivel de canal individual.
- **Revocación (RF3):** Revocar todas las direcciones de correo anteriores de un canal para inhabilitar integraciones antiguas.
- **Validación de Recepción (RF4):** Comprobar la política efectiva en el servidor (`email_mirror`) antes de publicar un mensaje.
- **Interfaz (RF5):** Mostrar el estado efectivo de la función y confirmar la revocación.

## Arquitectura y Flujo Transaccional

El proyecto modifica el flujo de recepción (SMTP/IMAP) mediante un protocolo transaccional en PostgreSQL, el servidor Django (API) y la interfaz web en TypeScript, incluyendo validaciones de concurrencia entre la recepción de correos y la revocación de tokens.
