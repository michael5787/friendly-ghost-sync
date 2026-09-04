ALTER TABLE public.resources ADD COLUMN IF NOT EXISTS class_id uuid REFERENCES public.classes(id) ON DELETE SET NULL;
CREATE INDEX IF NOT EXISTS resources_class_idx ON public.resources (class_id);

ALTER TABLE public.submissions
  ADD COLUMN IF NOT EXISTS grade numeric(5,2),
  ADD COLUMN IF NOT EXISTS graded_at timestamptz;

DROP POLICY IF EXISTS "Teachers grade their submissions" ON public.submissions;
CREATE POLICY "Teachers grade their submissions" ON public.submissions FOR UPDATE TO authenticated USING (auth.uid() = teacher_id OR public.has_role(auth.uid(), 'super_admin'::public.app_role)) WITH CHECK (auth.uid() = teacher_id OR public.has_role(auth.uid(), 'super_admin'::public.app_role));

DO $$ BEGIN CREATE TYPE public.agenda_kind AS ENUM ('homework', 'evaluation'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;

CREATE TABLE IF NOT EXISTS public.agenda_events (
  id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  teacher_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  class_id uuid NOT NULL REFERENCES public.classes(id) ON DELETE CASCADE,
  kind public.agenda_kind NOT NULL DEFAULT 'homework',
  title text NOT NULL,
  description text,
  event_date date NOT NULL,
  resource_id uuid REFERENCES public.resources(id) ON DELETE SET NULL,
  link_url text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS agenda_events_class_date_idx ON public.agenda_events (class_id, event_date);
CREATE INDEX IF NOT EXISTS agenda_events_teacher_date_idx ON public.agenda_events (teacher_id, event_date);

GRANT SELECT, INSERT, UPDATE, DELETE ON public.agenda_events TO authenticated;
GRANT ALL ON public.agenda_events TO service_role;

ALTER TABLE public.agenda_events ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Teachers insert agenda for their classes" ON public.agenda_events;
CREATE POLICY "Teachers insert agenda for their classes"
ON public.agenda_events FOR INSERT TO authenticated
WITH CHECK (
  (auth.uid() = teacher_id AND EXISTS (
    SELECT 1 FROM public.teacher_classes tc
    WHERE tc.teacher_id = auth.uid() AND tc.class_id = agenda_events.class_id
  ))
  OR public.has_role(auth.uid(), 'super_admin'::public.app_role)
);

DROP POLICY IF EXISTS "Read agenda scoped by class" ON public.agenda_events;
CREATE POLICY "Read agenda scoped by class"
ON public.agenda_events FOR SELECT TO authenticated
USING (
  auth.uid() = teacher_id
  OR public.has_role(auth.uid(), 'super_admin'::public.app_role)
  OR EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.class_id = agenda_events.class_id)
  OR EXISTS (SELECT 1 FROM public.teacher_classes tc WHERE tc.teacher_id = auth.uid() AND tc.class_id = agenda_events.class_id)
);

DROP POLICY IF EXISTS "Teachers update own agenda" ON public.agenda_events;
CREATE POLICY "Teachers update own agenda"
ON public.agenda_events FOR UPDATE TO authenticated
USING (auth.uid() = teacher_id OR public.has_role(auth.uid(), 'super_admin'::public.app_role))
WITH CHECK (auth.uid() = teacher_id OR public.has_role(auth.uid(), 'super_admin'::public.app_role));

DROP POLICY IF EXISTS "Teachers delete own agenda" ON public.agenda_events;
CREATE POLICY "Teachers delete own agenda"
ON public.agenda_events FOR DELETE TO authenticated
USING (auth.uid() = teacher_id OR public.has_role(auth.uid(), 'super_admin'::public.app_role));

DROP TRIGGER IF EXISTS update_agenda_events_updated_at ON public.agenda_events;
CREATE TRIGGER update_agenda_events_updated_at
BEFORE UPDATE ON public.agenda_events
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

DROP POLICY IF EXISTS "Users read own profile" ON public.profiles;
CREATE POLICY "Users read own profile" ON public.profiles FOR SELECT TO authenticated USING (auth.uid() = id);

DROP POLICY IF EXISTS "Students read own submissions" ON public.submissions;
CREATE POLICY "Students read own submissions" ON public.submissions FOR SELECT TO authenticated USING (auth.uid() = student_id);

DROP POLICY IF EXISTS "Authenticated read resource files" ON storage.objects;
DROP POLICY IF EXISTS "Read resource files scoped by class" ON storage.objects;
CREATE POLICY "Read resource files scoped by class"
ON storage.objects FOR SELECT TO authenticated
USING (
  bucket_id = 'resources'
  AND EXISTS (
    SELECT 1 FROM public.resources r
    WHERE r.file_path = storage.objects.name
      AND (
        r.class_id IS NULL
        OR r.teacher_id = auth.uid()
        OR public.has_role(auth.uid(), 'super_admin')
        OR EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.class_id = r.class_id)
        OR EXISTS (SELECT 1 FROM public.teacher_classes tc WHERE tc.teacher_id = auth.uid() AND tc.class_id = r.class_id)
      )
  )
);