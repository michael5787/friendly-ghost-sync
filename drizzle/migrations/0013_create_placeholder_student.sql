CREATE OR REPLACE FUNCTION public.create_placeholder_student(_first_name text, _last_name text, _class_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, extensions
AS $$
DECLARE
  _uid uuid := auth.uid();
  _is_admin boolean;
  _level uuid;
  _new_id uuid := gen_random_uuid();
  _email text;
  _full text;
BEGIN
  IF _uid IS NULL THEN RAISE EXCEPTION 'غير مسجّل الدخول.'; END IF;
  _first_name := btrim(coalesce(_first_name, ''));
  _last_name := btrim(coalesce(_last_name, ''));
  IF _first_name = '' OR _last_name = '' OR length(_first_name) > 60 OR length(_last_name) > 60 THEN
    RAISE EXCEPTION 'الاسم واللقب مطلوبان.';
  END IF;
  _is_admin := public.has_role(_uid, 'super_admin');
  IF NOT _is_admin AND NOT EXISTS (
    SELECT 1 FROM public.profiles WHERE id = _uid AND space = 'taleem' AND status = 'approved'
  ) THEN RAISE EXCEPTION 'حسابك ليس حساب أستاذ مُفعّل.'; END IF;
  IF NOT _is_admin AND NOT EXISTS (
    SELECT 1 FROM public.teacher_classes WHERE teacher_id = _uid AND class_id = _class_id
  ) THEN RAISE EXCEPTION 'أنت غير مُسنَد إلى هذا القسم.'; END IF;
  SELECT level_id INTO _level FROM public.classes WHERE id = _class_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'القسم غير موجود.'; END IF;

  _email := 'eleve-' || encode(gen_random_bytes(6), 'hex') || '@eleves.local';
  _full := _last_name || ' ' || _first_name;

  INSERT INTO auth.users (instance_id, id, aud, role, email, encrypted_password,
    raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
    confirmation_token, recovery_token, email_change_token_new, email_change)
  VALUES ('00000000-0000-0000-0000-000000000000', _new_id, 'authenticated', 'authenticated', _email,
    crypt(encode(gen_random_bytes(24), 'hex'), gen_salt('bf')),
    '{"provider":"email","providers":["email"]}'::jsonb,
    jsonb_build_object('space', 'talameed', 'full_name', _full, 'created_by_teacher', _uid),
    now(), now(), '', '', '', '');

  UPDATE public.profiles
     SET full_name = _full, class_id = _class_id, level_id = _level, status = 'pending'
   WHERE id = _new_id;

  RETURN jsonb_build_object('id', _new_id, 'email', _email, 'fullName', _full);
END;
$$;
REVOKE ALL ON FUNCTION public.create_placeholder_student(text, text, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.create_placeholder_student(text, text, uuid) TO authenticated;

CREATE OR REPLACE FUNCTION public.can_manage_placeholder_student(_student_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles p
    WHERE p.id = _student_id
      AND p.space = 'talameed'
      AND lower(p.email) LIKE '%@eleves.local'
      AND (
        public.has_role(auth.uid(), 'super_admin')
        OR EXISTS (
          SELECT 1 FROM public.teacher_classes tc
          JOIN public.profiles me ON me.id = tc.teacher_id
          WHERE tc.teacher_id = auth.uid() AND tc.class_id = p.class_id
            AND me.space = 'taleem' AND me.status = 'approved'
        )
      )
  )
$$;

CREATE OR REPLACE FUNCTION public.rename_placeholder_student(_student_id uuid, _first_name text, _last_name text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE _full text;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'غير مسجّل الدخول.'; END IF;
  _first_name := btrim(coalesce(_first_name, ''));
  _last_name := btrim(coalesce(_last_name, ''));
  IF _first_name = '' OR _last_name = '' OR length(_first_name) > 60 OR length(_last_name) > 60 THEN
    RAISE EXCEPTION 'الاسم واللقب مطلوبان.';
  END IF;
  IF NOT public.can_manage_placeholder_student(_student_id) THEN
    RAISE EXCEPTION 'لا يمكنك تعديل هذا التلميذ.';
  END IF;
  _full := _last_name || ' ' || _first_name;
  UPDATE public.profiles SET full_name = _full WHERE id = _student_id;
  UPDATE auth.users SET raw_user_meta_data = coalesce(raw_user_meta_data, '{}'::jsonb) || jsonb_build_object('full_name', _full)
   WHERE id = _student_id;
  RETURN jsonb_build_object('id', _student_id, 'fullName', _full);
END;
$$;

CREATE OR REPLACE FUNCTION public.delete_placeholder_student(_student_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'غير مسجّل الدخول.'; END IF;
  IF NOT public.can_manage_placeholder_student(_student_id) THEN
    RAISE EXCEPTION 'لا يمكنك حذف هذا التلميذ.';
  END IF;
  DELETE FROM auth.users WHERE id = _student_id;
END;
$$;

REVOKE ALL ON FUNCTION public.can_manage_placeholder_student(uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.rename_placeholder_student(uuid, text, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.delete_placeholder_student(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.can_manage_placeholder_student(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.rename_placeholder_student(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.delete_placeholder_student(uuid) TO authenticated;