-- =============================================
-- PARTIE 2 : TRIGGER AUTO-CREATION PROFIL
-- Exécuter en DEUXIEME dans Supabase SQL Editor
-- =============================================

CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO profiles (user_id, role, nom, prenom, telephone, whatsapp, departement, ville, cin_nif, titre_pro, competences, bio, nom_entreprise, nif_patente, description)
  VALUES (
    NEW.id,
    COALESCE((NEW.raw_user_meta_data->>'role')::user_role, 'CANDIDAT'),
    NEW.raw_user_meta_data->>'nom',
    NEW.raw_user_meta_data->>'prenom',
    NEW.raw_user_meta_data->>'telephone',
    NEW.raw_user_meta_data->>'whatsapp',
    NEW.raw_user_meta_data->>'departement',
    NEW.raw_user_meta_data->>'ville',
    NEW.raw_user_meta_data->>'cin_nif',
    NEW.raw_user_meta_data->>'titre_pro',
    NEW.raw_user_meta_data->>'competences',
    NEW.raw_user_meta_data->>'bio',
    NEW.raw_user_meta_data->>'nom_entreprise',
    NEW.raw_user_meta_data->>'nif_patente',
    NEW.raw_user_meta_data->>'description'
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();
