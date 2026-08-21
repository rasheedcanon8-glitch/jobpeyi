-- ============================================
-- JOB PEYI - Table Messagerie & Négociation Realtime
-- Version complète avec is_read pour notifications
-- ============================================

-- Créer la table si elle n'existe pas encore
CREATE TABLE IF NOT EXISTS messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  application_id UUID REFERENCES applications(id) ON DELETE CASCADE,
  sender_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  recipient_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  content TEXT NOT NULL,
  is_read BOOLEAN DEFAULT false,
  proposition_tarif NUMERIC,
  devise TEXT DEFAULT 'HTG',
  statut_tarif TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Si la table existe déjà, ajouter la colonne is_read (sans erreur si déjà présente)
ALTER TABLE messages ADD COLUMN IF NOT EXISTS is_read BOOLEAN DEFAULT false;

-- Index pour la rapidité des requêtes
CREATE INDEX IF NOT EXISTS idx_messages_app       ON messages(application_id);
CREATE INDEX IF NOT EXISTS idx_messages_sender    ON messages(sender_id);
CREATE INDEX IF NOT EXISTS idx_messages_recipient ON messages(recipient_id);
CREATE INDEX IF NOT EXISTS idx_messages_unread    ON messages(recipient_id, is_read) WHERE is_read = false;

-- Activer RLS
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;

-- Politiques RLS
DROP POLICY IF EXISTS "Utilisateurs peuvent voir leurs messages" ON messages;
DROP POLICY IF EXISTS "Utilisateurs peuvent envoyer des messages" ON messages;
DROP POLICY IF EXISTS "Utilisateurs peuvent mettre a jour leurs messages" ON messages;

CREATE POLICY "Utilisateurs peuvent voir leurs messages" ON messages
  FOR SELECT USING (true);

CREATE POLICY "Utilisateurs peuvent envoyer des messages" ON messages
  FOR INSERT WITH CHECK (true);

CREATE POLICY "Utilisateurs peuvent mettre a jour leurs messages" ON messages
  FOR UPDATE USING (true);

-- Activer la réplication Realtime pour la table messages
ALTER PUBLICATION supabase_realtime ADD TABLE messages;
