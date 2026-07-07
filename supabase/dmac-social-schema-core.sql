/* ═══════════════════════════════════════════════════════════════════
   dmac-social-schema-core.sql
   Base profile / score schema used by the club site.
   This is the chunk that ends at the officer delete policy.
   ═══════════════════════════════════════════════════════════════════ */

-- Comment this block out if you want to keep existing test data
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP FUNCTION IF EXISTS public.handle_new_user();
DROP TABLE IF EXISTS public.scores;
DROP TABLE IF EXISTS public.profiles;

-- Profile row, one per logged-in user
CREATE TABLE public.profiles (
  id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  member_id text UNIQUE NOT NULL,
  display_name text NOT NULL,
  role text NOT NULL DEFAULT 'member' CHECK (role IN ('member','officer')),
  created_at timestamptz NOT NULL DEFAULT now()
);

-- Auto-create a profile row whenever someone signs up
CREATE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  INSERT INTO public.profiles (id, member_id, display_name)
  VALUES (
    new.id,
    new.id::text,  -- placeholder; correct by hand in Table Editor once you know their real member_id
    coalesce(new.raw_user_meta_data->>'full_name', new.email)
  );
  RETURN new;
END;
$$;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Scores table — same shape as your old Scores sheet
CREATE TABLE public.scores (
  id bigint GENERATED ALWAYS AS identity PRIMARY KEY,
  badge_id text NOT NULL,
  member_id text NOT NULL REFERENCES public.profiles(member_id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  value numeric NOT NULL,
  issue_number int,
  awarded_on date NOT NULL DEFAULT current_date,
  created_by uuid REFERENCES auth.users(id),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX scores_member_badge_uniq
  ON public.scores (badge_id, member_id)
  WHERE issue_number IS NULL;

-- Enable RLS on both
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.scores ENABLE ROW LEVEL SECURITY;

GRANT SELECT ON public.profiles TO anon, authenticated;
GRANT UPDATE (display_name) ON public.profiles TO authenticated;
GRANT SELECT ON public.scores TO anon, authenticated;
GRANT INSERT, UPDATE, DELETE ON public.scores TO authenticated;

CREATE POLICY "Profiles are publicly readable" ON public.profiles
  FOR SELECT TO anon, authenticated USING (true);

CREATE POLICY "Scores are publicly readable" ON public.scores
  FOR SELECT TO anon, authenticated USING (true);

CREATE POLICY "Users can update own profile" ON public.profiles
  FOR UPDATE TO authenticated
  USING (auth.uid() = id) WITH CHECK (auth.uid() = id);

CREATE POLICY "Officers can insert scores" ON public.scores
  FOR INSERT TO authenticated
  WITH CHECK (EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'officer'));

CREATE POLICY "Officers can update scores" ON public.scores
  FOR UPDATE TO authenticated
  USING (EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'officer'))
  WITH CHECK (EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'officer'));

CREATE POLICY "Officers can delete scores" ON public.scores
  FOR DELETE TO authenticated
  USING (EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'officer'));
