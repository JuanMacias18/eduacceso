/**
 * Tipos del esquema, GENERADOS. No editar a mano.
 *
 * Se regeneran con `npm run db:tipos`, que ejecuta el CLI de Supabase contra la base
 * local. Ahora mismo el esquema está vacío: las tablas llegan con el encargo 02.
 */
export type Json = string | number | boolean | null | { [key: string]: Json | undefined } | Json[]

export type Database = {
  public: {
    Tables: { [_ in never]: never }
    Views: { [_ in never]: never }
    Functions: { [_ in never]: never }
    Enums: { [_ in never]: never }
    CompositeTypes: { [_ in never]: never }
  }
}
