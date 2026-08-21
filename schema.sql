-- ============================================
-- JOB PEYI - Schéma Base de Données Supabase
-- Exécuter dans : Supabase → SQL Editor
-- ============================================

-- 1. ENUM / Types personnalisés
CREATE TYPE user_role AS ENUM ('CANDIDAT', 'RECRUTEUR');
CREATE TYPE type_contrat AS ENUM ('CDD', 'PRESTATION', 'FREELANCE', 'JOURNALIER');
CREATE TYPE type_presence AS ENUM ('PRESENTIEL', 'HYBRIDE', 'REMOTE');
CREATE TYPE devise_type AS ENUM ('HTG', 'USD');
CREATE TYPE job_statut AS ENUM ('ACTIF', 'FERME', 'ARCHIVE');
CREATE TYPE app_statut AS ENUM ('EN_ATTENTE', 'ACCEPTEE', 'REJETEE');

-- 2. TABLE PROFILES (liée à Supabase Auth)
CREATE TABLE profiles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID UNIQUE NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  role user_role NOT NULL,
  -- Champs Candidat
  nom TEXT,
  prenom TEXT,
  telephone TEXT,
  whatsapp TEXT,
  departement TEXT,
  ville TEXT,
  cin_nif TEXT,
  titre_pro TEXT,
  competences TEXT,
  bio TEXT,
  disponibilite TEXT DEFAULT 'Immédiate',
  cv_url TEXT,
  cin_url TEXT,
  -- Champs Recruteur
  nom_entreprise TEXT,
  nif_patente TEXT,
  description TEXT,
  logo_url TEXT,
  -- Métadonnées
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- 3. TABLE JOBS (Offres d'emploi)
CREATE TABLE jobs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  recruteur_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  titre TEXT NOT NULL,
  description TEXT NOT NULL,
  type_contrat type_contrat NOT NULL DEFAULT 'CDD',
  type_presence type_presence NOT NULL DEFAULT 'PRESENTIEL',
  salaire_range TEXT,
  devise devise_type NOT NULL DEFAULT 'HTG',
  departement TEXT NOT NULL,
  ville TEXT,
  statut job_statut NOT NULL DEFAULT 'ACTIF',
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- 4. TABLE APPLICATIONS (Candidatures)
CREATE TABLE applications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  job_id UUID NOT NULL REFERENCES jobs(id) ON DELETE CASCADE,
  candidat_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  motivation TEXT,
  statut app_statut NOT NULL DEFAULT 'EN_ATTENTE',
  applied_at TIMESTAMPTZ DEFAULT now(),
  -- Empêcher les doublons
  UNIQUE(job_id, candidat_id)
);

-- 5. INDEXES pour les recherches rapides
CREATE INDEX idx_jobs_statut ON jobs(statut);
CREATE INDEX idx_jobs_departement ON jobs(departement);
CREATE INDEX idx_jobs_type_contrat ON jobs(type_contrat);
CREATE INDEX idx_jobs_recruteur ON jobs(recruteur_id);
CREATE INDEX idx_apps_candidat ON applications(candidat_id);
CREATE INDEX idx_apps_job ON applications(job_id);
CREATE INDEX idx_profiles_role ON profiles(role);

-- 6. FONCTION : Créer un profil automatiquement après inscription Auth
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

-- Trigger qui s'exécute après chaque inscription
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- 7. ROW LEVEL SECURITY (RLS) — Sécurité par rôle

-- Activer RLS sur toutes les tables
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE jobs ENABLE ROW LEVEL SECURITY;
ALTER TABLE applications ENABLE ROW LEVEL SECURITY;

-- PROFILES : Tout le monde peut lire, seul le propriétaire peut modifier
CREATE POLICY "Profiles visibles par tous" ON profiles FOR SELECT USING (true);
CREATE POLICY "Modifier son propre profil" ON profiles FOR UPDATE USING (auth.uid() = user_id);

-- JOBS : Tout le monde peut lire les offres actives, seul le recruteur propriétaire peut modifier
CREATE POLICY "Jobs visibles par tous" ON jobs FOR SELECT USING (true);
CREATE POLICY "Recruteur publie ses offres" ON jobs FOR INSERT WITH CHECK (
  recruteur_id IN (SELECT id FROM profiles WHERE user_id = auth.uid() AND role = 'RECRUTEUR')
);
CREATE POLICY "Recruteur modifie ses offres" ON jobs FOR UPDATE USING (
  recruteur_id IN (SELECT id FROM profiles WHERE user_id = auth.uid())
);
CREATE POLICY "Recruteur supprime ses offres" ON jobs FOR DELETE USING (
  recruteur_id IN (SELECT id FROM profiles WHERE user_id = auth.uid())
);

-- APPLICATIONS : Candidat voit ses candidatures, Recruteur voit celles de ses offres
CREATE POLICY "Candidat voit ses candidatures" ON applications FOR SELECT USING (
  candidat_id IN (SELECT id FROM profiles WHERE user_id = auth.uid())
  OR
  job_id IN (SELECT id FROM jobs WHERE recruteur_id IN (SELECT id FROM profiles WHERE user_id = auth.uid()))
);
CREATE POLICY "Candidat postule" ON applications FOR INSERT WITH CHECK (
  candidat_id IN (SELECT id FROM profiles WHERE user_id = auth.uid() AND role = 'CANDIDAT')
);
CREATE POLICY "Recruteur met à jour le statut" ON applications FOR UPDATE USING (
  job_id IN (SELECT id FROM jobs WHERE recruteur_id IN (SELECT id FROM profiles WHERE user_id = auth.uid()))
);

-- 8. STORAGE BUCKETS (à créer dans l'interface Supabase Storage)
-- Bucket: cv-files  (Public: false)
-- Bucket: cin-files (Public: false)

-- Politiques Storage (exécuter après avoir créé les buckets)
-- CV : le propriétaire peut upload, les recruteurs peuvent lire
INSERT INTO storage.buckets (id, name, public) VALUES ('cv-files', 'cv-files', false) ON CONFLICT DO NOTHING;
INSERT INTO storage.buckets (id, name, public) VALUES ('cin-files', 'cin-files', false) ON CONFLICT DO NOTHING;

CREATE POLICY "Upload son CV" ON storage.objects FOR INSERT WITH CHECK (
  bucket_id = 'cv-files' AND auth.uid()::text = (storage.foldername(name))[1]
);
CREATE POLICY "Lire les CV" ON storage.objects FOR SELECT USING (
  bucket_id = 'cv-files' AND auth.role() = 'authenticated'
);
CREATE POLICY "Upload sa CIN" ON storage.objects FOR INSERT WITH CHECK (
  bucket_id = 'cin-files' AND auth.uid()::text = (storage.foldername(name))[1]
);
CREATE POLICY "Lire les CIN" ON storage.objects FOR SELECT USING (
  bucket_id = 'cin-files' AND auth.role() = 'authenticated'
);
