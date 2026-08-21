-- =============================================
-- PARTIE 1 : TYPES + TABLES + INDEX
-- Exécuter en PREMIER dans Supabase SQL Editor
-- =============================================

CREATE TYPE user_role AS ENUM ('CANDIDAT', 'RECRUTEUR');
CREATE TYPE type_contrat AS ENUM ('CDD', 'PRESTATION', 'FREELANCE', 'JOURNALIER');
CREATE TYPE type_presence AS ENUM ('PRESENTIEL', 'HYBRIDE', 'REMOTE');
CREATE TYPE devise_type AS ENUM ('HTG', 'USD');
CREATE TYPE job_statut AS ENUM ('ACTIF', 'FERME', 'ARCHIVE');
CREATE TYPE app_statut AS ENUM ('EN_ATTENTE', 'ACCEPTEE', 'REJETEE');

CREATE TABLE profiles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID UNIQUE NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  role user_role NOT NULL,
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
  disponibilite TEXT DEFAULT 'Immediate',
  cv_url TEXT,
  cin_url TEXT,
  nom_entreprise TEXT,
  nif_patente TEXT,
  description TEXT,
  logo_url TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

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

CREATE TABLE applications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  job_id UUID NOT NULL REFERENCES jobs(id) ON DELETE CASCADE,
  candidat_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  motivation TEXT,
  statut app_statut NOT NULL DEFAULT 'EN_ATTENTE',
  applied_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(job_id, candidat_id)
);

CREATE INDEX idx_jobs_statut ON jobs(statut);
CREATE INDEX idx_jobs_departement ON jobs(departement);
CREATE INDEX idx_jobs_type_contrat ON jobs(type_contrat);
CREATE INDEX idx_jobs_recruteur ON jobs(recruteur_id);
CREATE INDEX idx_apps_candidat ON applications(candidat_id);
CREATE INDEX idx_apps_job ON applications(job_id);
CREATE INDEX idx_profiles_role ON profiles(role);
