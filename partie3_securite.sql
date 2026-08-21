-- =============================================
-- PARTIE 3 : SECURITE RLS + STORAGE
-- Exécuter en TROISIEME dans Supabase SQL Editor
-- =============================================

ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE jobs ENABLE ROW LEVEL SECURITY;
ALTER TABLE applications ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Profiles visibles par tous" ON profiles FOR SELECT USING (true);
CREATE POLICY "Modifier son propre profil" ON profiles FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Jobs visibles par tous" ON jobs FOR SELECT USING (true);
CREATE POLICY "Recruteur publie ses offres" ON jobs FOR INSERT WITH CHECK (
  recruteur_id IN (SELECT id FROM profiles WHERE user_id = auth.uid() AND role = 'RECRUTEUR')
);
CREATE POLICY "Recruteur modifie ses offres" ON jobs FOR UPDATE USING (
  recruteur_id IN (SELECT id FROM profiles WHERE user_id = auth.uid())
);
DROP POLICY IF EXISTS "Recruteur supprime ses offres" ON jobs;
CREATE POLICY "Recruteur supprime ses offres" ON jobs FOR DELETE USING (
  recruteur_id = auth.uid()
  OR recruteur_id IN (SELECT id FROM profiles WHERE user_id = auth.uid())
  OR auth.role() = 'authenticated'
);

CREATE POLICY "Candidat voit ses candidatures" ON applications FOR SELECT USING (
  candidat_id IN (SELECT id FROM profiles WHERE user_id = auth.uid())
  OR
  job_id IN (SELECT id FROM jobs WHERE recruteur_id IN (SELECT id FROM profiles WHERE user_id = auth.uid()))
);
CREATE POLICY "Candidat postule" ON applications FOR INSERT WITH CHECK (
  candidat_id IN (SELECT id FROM profiles WHERE user_id = auth.uid() AND role = 'CANDIDAT')
);
CREATE POLICY "Recruteur met a jour le statut" ON applications FOR UPDATE USING (
  job_id IN (SELECT id FROM jobs WHERE recruteur_id IN (SELECT id FROM profiles WHERE user_id = auth.uid()))
);

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
