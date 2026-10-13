CREATE TABLE IF NOT EXISTS public.course_files (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  teacher_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  level_id uuid NOT NULL REFERENCES public.levels(id) ON DELETE CASCADE,
  chapter_id uuid,
  title text NOT NULL,
  file_path text NOT NULL,
  file_name text NOT NULL,
  mime_type text,
  size_bytes bigint,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS course_files_level_chapter_idx ON public.course_files (level_id, chapter_id);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.course_files TO authenticated;
GRANT ALL ON public.course_files TO service_role;
ALTER TABLE public.course_files ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Authenticated read course files" ON public.course_files FOR SELECT TO authenticated USING (true);
CREATE POLICY "Teachers insert own course files" ON public.course_files FOR INSERT TO authenticated WITH CHECK (teacher_id = auth.uid());
CREATE POLICY "Teachers update own course files" ON public.course_files FOR UPDATE TO authenticated USING (teacher_id = auth.uid()) WITH CHECK (teacher_id = auth.uid());
CREATE POLICY "Owner or admin delete course files" ON public.course_files FOR DELETE TO authenticated USING (teacher_id = auth.uid() OR public.has_role(auth.uid(), 'super_admin'));
CREATE POLICY "Authenticated read course storage" ON storage.objects FOR SELECT TO authenticated USING (bucket_id = 'course-files');
CREATE POLICY "Teachers upload own course storage" ON storage.objects FOR INSERT TO authenticated WITH CHECK (bucket_id = 'course-files' AND (storage.foldername(name))[1] = auth.uid()::text);
CREATE POLICY "Teachers delete own course storage" ON storage.objects FOR DELETE TO authenticated USING (bucket_id = 'course-files' AND (storage.foldername(name))[1] = auth.uid()::text);