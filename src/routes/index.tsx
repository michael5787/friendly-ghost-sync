import { useEffect, useState } from "react";
import { createFileRoute, Link, useNavigate } from "@tanstack/react-router";
import { consumeAuthRedirect, getSpaceClient } from "@/lib/spaces";
import { translateError } from "@/components/SpaceAuth";
import { MainNav } from "@/components/MainNav";
import { PasswordField } from "@/components/PasswordField";
import { PublicBackdrop } from "@/components/PublicBackdrop";

export const Route = createFileRoute("/")({
  head: () => ({
    meta: [
      { title: "مداوروس — فضاء التلاميذ" },
      {
        name: "description",
        content: "منصة مداوروس: فضاء التلاميذ للدخول المباشر إلى الدروس والواجبات.",
      },
      { property: "og:title", content: "مداوروس — فضاء التلاميذ" },
      {
        property: "og:description",
        content: "سجّل الدخول إلى فضاء التلاميذ على منصة مداوروس.",
      },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary_large_image" },
    ],
  }),
  component: Index,
});

function Index() {
  return (
    <PublicBackdrop>
    <main className="flex min-h-screen flex-col items-center justify-center px-4 pb-10 pt-24">
      <MainNav space="talameed" />

      <div className="w-full max-w-[450px] rounded-[28px] border border-border bg-card/95 px-8 py-10 shadow-lg backdrop-blur-sm sm:px-11">
        <div className="mb-6 flex flex-col items-center gap-2">
          <div dir="ltr" className="font-wordmark text-3xl tracking-tight">
            <span className="text-brand-green">m</span>
            <span className="text-brand-green">a</span>
            <span className="text-brand-green">d</span>
            <span className="text-brand-green">a</span>
            <span className="text-brand-red">u</span>
            <span className="text-brand-red">r</span>
            <span className="text-brand-red">o</span>
            <span className="text-brand-red">s</span>
            <span className="ms-2 align-middle text-sm text-muted-foreground">/ talameed</span>
          </div>
          <span className="text-xs tracking-wide text-muted-foreground" dir="ltr">
            talameed.madauros
          </span>
        </div>

        <StudentLogin />
      </div>

      <div className="mt-6 flex items-center gap-4 text-xs text-muted-foreground">
        <Link to="/taleem" className="underline underline-offset-4 hover:text-foreground">
          وصول الأساتذة
        </Link>
        <span className="text-border">|</span>
        <Link to="/admin" className="underline underline-offset-4 hover:text-foreground">
          وصول الإدارة
        </Link>
      </div>
    </main>
    </PublicBackdrop>
  );
}

function StudentLogin() {
  const navigate = useNavigate();
  const client = getSpaceClient("talameed");

  const [mode, setMode] = useState<"login" | "signup" | "forgot">("login");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    consumeAuthRedirect(client).then(() =>
      client.auth.getSession().then(({ data }) => {
        if (data.session) navigate({ to: "/talameed" });
      }),
    );
  }, [client, navigate]);

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    setBusy(true);
    setError(null);
    setMessage(null);

    if (mode === "forgot") {
      const { error: err } = await client.auth.resetPasswordForEmail(email, {
        redirectTo: `${window.location.origin}/reset-password?space=talameed`,
      });
      if (err) setError(translateError(err.message));
      else setMessage("إذا كان هذا البريد مسجّلاً، فقد أرسلنا إليه رابطاً لإعادة تعيين كلمة المرور.");
    } else if (mode === "signup") {
      const { error: err } = await client.auth.signUp({
        email,
        password,
        options: {
          emailRedirectTo: `${window.location.origin}/`,
          data: { space: "talameed" },
        },
      });
      if (err) setError(translateError(err.message));
      else setMessage(" تم إنشاء الحساب. سيتم تأكيده قريباً بعد مصادقة المشرف.");
    } else {
      const { error: err } = await client.auth.signInWithPassword({ email, password });
      if (err) {
        setError(translateError(err.message));
      } else {
        navigate({ to: "/talameed" });
      }
    }

    setBusy(false);
  };

  return (
    <>
      <h2 className="text-center text-2xl font-normal text-foreground">
        {mode === "login" ? "تسجيل الدخول" : mode === "signup" ? "إنشاء حساب" : "نسيت كلمة المرور"}
      </h2>
      <p className="mt-2 text-center text-sm text-muted-foreground">
        {mode === "forgot"
          ? "أدخل بريدك الإلكتروني وسنرسل لك رابطاً لإعادة تعيين كلمة المرور."
          : "سجّل الدخول للوصول إلى دروسك وواجباتك"}
      </p>

      <form onSubmit={submit} className="mt-8 space-y-5">
        <div className="field">
          <input
            id="email"
            type="email"
            required
            dir="ltr"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            placeholder=" "
            className="field-input"
            autoComplete="email"
          />
          <label htmlFor="email" className="field-label">
            البريد الإلكتروني
          </label>
        </div>

        {mode === "forgot" ? null : (
          <PasswordField
            id="password"
            name="password"
            label="كلمة المرور"
            required
            minLength={6}
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            autoComplete={mode === "login" ? "current-password" : "new-password"}
          />
        )}


        {error ? <p className="text-sm text-destructive">{error}</p> : null}
        {message ? <p className="text-sm text-success">{message}</p> : null}

        <div className="flex items-center justify-between pt-2">
          <button
            type="button"
            className="btn-text"
            onClick={() => {
              setMode(mode === "login" ? "signup" : "login");
              setError(null);
              setMessage(null);
            }}
          >
            {mode === "login" ? "إنشاء حساب" : mode === "signup" ? "لدي حساب بالفعل" : "العودة لتسجيل الدخول"}
          </button>
          <button type="submit" disabled={busy} className="btn-primary">
            {busy ? "…" : mode === "login" ? "التالي" : mode === "signup" ? "تسجيل" : "إرسال الرابط"}
          </button>
        </div>
      </form>
    </>
  );
}
