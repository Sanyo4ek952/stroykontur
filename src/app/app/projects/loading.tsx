export default function ProjectsLoading() {
  return (
    <main
      aria-label="Загрузка проектов"
      className="mx-auto min-h-dvh w-full max-w-6xl animate-pulse px-4 py-8 sm:px-8"
    >
      <div className="h-8 w-48 rounded bg-slate-200" />
      <div className="mt-8 grid gap-4 md:grid-cols-2">
        <div className="h-48 rounded-3xl bg-slate-200" />
        <div className="h-48 rounded-3xl bg-slate-200" />
      </div>
    </main>
  );
}
