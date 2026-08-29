export default function HomePage() {
  return (
    <main className="mx-auto flex min-h-dvh w-full max-w-5xl items-center px-5 py-12 sm:px-8 lg:px-12">
      <section aria-labelledby="page-title" className="max-w-2xl">
        <p className="mb-4 text-sm font-semibold tracking-[0.16em] text-slate-600 uppercase">
          PWA для строительства
        </p>
        <h1
          id="page-title"
          className="text-4xl font-semibold tracking-tight text-balance text-slate-950 sm:text-5xl"
        >
          Строительный объект
        </h1>
        <p className="mt-6 max-w-xl text-base leading-7 text-slate-600 sm:text-lg sm:leading-8">
          Основа приложения готова. Рабочие процессы будут добавляться поэтапно
          в следующих задачах.
        </p>
        <div className="mt-8 inline-flex items-center gap-3 rounded-full border border-slate-200 bg-white px-4 py-2 text-sm font-medium text-slate-700 shadow-sm">
          <span
            aria-hidden="true"
            className="size-2.5 rounded-full bg-emerald-500 ring-4 ring-emerald-100"
          />
          Система готова к настройке
        </div>
      </section>
    </main>
  );
}
