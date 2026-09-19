import Link from "next/link";

export default function HomePage() {
  const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL;
  let isLocalDemo = false;
  try {
    isLocalDemo = ["127.0.0.1", "localhost", "[::1]", "::1"].includes(
      new URL(supabaseUrl ?? "").hostname,
    );
  } catch {
    isLocalDemo = false;
  }

  return (
    <main className="mx-auto w-full max-w-5xl px-5 py-12 sm:px-8 lg:px-12">
      <section aria-labelledby="page-title" className="max-w-2xl py-10">
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
        <div className="mt-8 flex flex-wrap items-center gap-4">
          <div className="inline-flex items-center gap-3 rounded-full border border-slate-200 bg-white px-4 py-2 text-sm font-medium text-slate-700 shadow-sm">
            <span
              aria-hidden="true"
              className="size-2.5 rounded-full bg-emerald-500 ring-4 ring-emerald-100"
            />
            Система готова к настройке
          </div>
          <Link
            className="inline-flex min-h-11 items-center rounded-xl bg-slate-950 px-5 text-sm font-semibold text-white transition hover:bg-slate-800"
            href="/login"
          >
            Войти
          </Link>
          {isLocalDemo ? (
            <Link
              className="inline-flex min-h-11 items-center text-sm font-semibold text-amber-900 underline decoration-amber-400 underline-offset-4"
              href="#local-demo-scenario"
            >
              Краткий сценарий
            </Link>
          ) : null}
        </div>
      </section>

      {isLocalDemo ? (
        <section
          aria-labelledby="local-demo-title"
          className="mt-4 rounded-3xl border-2 border-amber-300 bg-amber-50 p-6 shadow-sm sm:p-8"
          id="local-demo-scenario"
        >
          <p className="inline-flex rounded-full bg-amber-200 px-3 py-1 text-xs font-bold tracking-[0.12em] text-amber-950 uppercase">
            Локальное демо
          </p>
          <h2
            className="mt-4 text-2xl font-semibold tracking-tight text-slate-950"
            id="local-demo-title"
          >
            Краткий сценарий двух организаций
          </h2>
          <ol className="mt-4 list-decimal space-y-2 pl-5 text-sm leading-6 text-slate-700">
            <li>
              Войдите как директор по строительству генподрядчика и откройте
              работы проекта.
            </li>
            <li>
              Выйдите, затем войдите как мастер субподрядчика и откройте дневные
              отчёты зоны A.
            </li>
            <li>
              Сравните доступные данные и управляющие действия для двух ролей.
            </li>
          </ol>
          <div
            className="mt-5 rounded-2xl border border-amber-300 bg-white/80 p-4 text-sm leading-6 text-amber-950"
            role="note"
          >
            <strong>Только локально.</strong> Демо использует test credentials и
            local Supabase. localhost сам по себе недоступен удалённым
            участникам и другим устройствам. Не публикуйте порты, bind на
            публичный интерфейс, туннель или репозиторные test credentials без
            отдельного security/hosting решения. PWA не означает offline sync:
            без локальных сервисов автономная работа не поддерживается.
          </div>
          <Link
            className="mt-5 inline-flex min-h-11 items-center rounded-xl border border-amber-400 bg-white px-4 text-sm font-semibold text-amber-950 hover:bg-amber-100"
            href="/login"
          >
            Перейти ко входу
          </Link>
        </section>
      ) : null}
    </main>
  );
}
