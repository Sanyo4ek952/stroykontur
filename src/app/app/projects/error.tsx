"use client";

export default function ProjectsError({
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  return (
    <main className="mx-auto flex min-h-dvh w-full max-w-xl items-center px-4 py-10">
      <section className="w-full rounded-3xl border border-red-200 bg-white p-7 text-center shadow-sm">
        <h1 className="text-xl font-semibold text-slate-950">
          Не удалось загрузить рабочее пространство
        </h1>
        <p className="mt-2 text-sm leading-6 text-slate-600">
          Проверьте соединение и повторите попытку. Технические сведения не
          показываются.
        </p>
        <button
          className="mt-5 min-h-11 rounded-xl bg-slate-950 px-4 text-sm font-semibold text-white"
          onClick={reset}
          type="button"
        >
          Повторить
        </button>
      </section>
    </main>
  );
}
