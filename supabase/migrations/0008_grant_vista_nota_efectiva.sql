-- Encargo 02 · Migración 0008 — El GRANT que le faltaba a v_nota_efectiva
--
-- Corrige un descuido de 0005. NO se edita 0005: ya está commiteada y en origin (regla 7).
--
-- La vista se creó con `security_invoker = true`, que es lo que hace que respete la RLS de
-- las tablas que consulta, pero nadie le concedió SELECT. El resultado es una vista correcta
-- y a la vez inservible: cualquier consulta desde la aplicación muere con
--
--     permission denied for view v_nota_efectiva
--
-- Es el mismo defecto que apareció con las tablas en 0003, y por la misma razón: los
-- privilegios se dieron enumerando objetos a mano. Aquí no basta con arreglarlo — la prueba
-- 0003_politicas_forma.test.sql pasa a comprobar también las vistas, para que la próxima no
-- llegue tan lejos.

grant select on v_nota_efectiva to authenticated;
