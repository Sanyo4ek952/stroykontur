import Link from "next/link";

export default function NotFound() {
  return (
    <main className="mx-auto flex min-h-dvh w-full max-w-3xl items-center px-5 py-12 sm:px-8">
      <section aria-labelledby="not-found-title">
        <p className="text-sm font-semibold text-slate-500">Ошибка 404</p>
        <h1
          id="not-found-title"
          className="mt-3 text-3xl font-semibold tracking-tight text-slate-950"
        >
          Страница не найдена
        </h1>
        <p className="mt-4 max-w-md leading-7 text-slate-600">
          Проверьте адрес или вернитесь на начальную страницу приложения.
        </p>
        <Link
          href="/"
          className="mt-7 inline-flex min-h-11 items-center rounded-lg bg-slate-950 px-5 py-2.5 text-sm font-semibold text-white transition-colors hover:bg-slate-800 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-slate-950"
        >
          На главную
        </Link>
      </section>
    </main>
  );
}
