# Requisitos antes de operar EV2 Clandestino

Este repositorio contiene la base de software y despliegue aislado. No es seguro abrir ventas reales hasta completar y probar estos puntos.

1. Importar y validar catálogo, recetas, precios unificados B2/B3, zonas y capacidades reales.
2. Crear cuentas de personal, asignaciones por turno y permisos mínimos.
3. Configurar al menos una pasarela web, terminal presencial y sus webhooks firmados. Nunca registrar un pago únicamente con datos enviados desde el navegador.
4. Configurar fuente diaria de USD/MXN, guardar fuente, fecha y valor original, y aplicar `floor()` exclusivamente al precio operativo.
5. Configurar correo/SMS, políticas de contraseña, recuperación y consentimiento de privacidad.
6. Implementar OAuth con aplicaciones Meta propias; Instagram no ofrece un inicio de sesión genérico equivalente a correo y requiere validar el flujo permitido por Meta antes de prometerlo a clientes.
7. Diseñar el mapa 3D con el plano autorizado y cargar zonas; validar que no haya solapamientos ni reservas dobles.
8. Probar en staging los flujos de reserva, QR único, contingencia, denegación por INE, reasignación, pedido, pago, barra, entrega, Flirty, rechazo y propinas.
9. Configurar copias de seguridad diarias, restauración probada, HTTPS, monitoreo y retención de auditoría.
10. Revisar obligaciones legales locales: alcohol, protección de datos, facturación SAT y condiciones de regalos/Flirty.

## Regla de acceso de contingencia

Recepción busca la reserva por folio, nombre o teléfono, revisa INE y emite un pase temporal único. Debe registrar empleado, motivo y hora. No se debe revelar ni reutilizar el QR original. Si se deniega por minoría de edad o identificación inválida, se registra el motivo y solo el titular reasigna el acceso no usado a otro adulto.
