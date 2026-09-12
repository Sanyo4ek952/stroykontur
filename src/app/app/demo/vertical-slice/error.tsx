"use client";

export default function VerticalSliceError({ reset }: { reset: () => void }) {
  return (
    <main className="mx-auto flex min-h-dvh w-full max-w-xl items-center px-5 py-10">
      <section className="w-full rounded-3xl border border-red-200 bg-white p-6 shadow-sm">
        <p className="text-sm font-semibold text-red-700">
          Демо временно недоступно
        </p>
        <h1 className="mt-2 text-2xl font-semibold text-slate-950">
          Не удалось загрузить данные
        </h1>
        <p className="mt-3 text-sm leading-6 text-slate-600">
          Проверьте локальный Supabase и повторите загрузку. Технические детали
          не выводятся на страницу.
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
