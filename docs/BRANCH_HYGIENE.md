# Branch Hygiene

## Policy

- Local worktrees should sit on the repository default branch unless active work is underway.
- Temporary rescue branches use `codex/preserve-dirty-tree-YYYYMMDD` and must be clean before switching away.
- Feature work uses `codex/<short-purpose>` and should be merged by pull request, then deleted remotely.
- Long-lived non-default branches are allowed only when they are the repository's real default or an explicitly documented release line.

## Completed Cleanup

On 2026-05-10, clean `codex/preserve-dirty-tree-20260508` worktrees were switched back to their configured defaults and fast-forwarded where remote access succeeded.

Some repositories intentionally remain on non-main defaults:

| Repository | Current branch | Reason |
| --- | --- | --- |
| `beta-pcihvac.seolith.com` | `feature/angular-ssr-migration` | Remote default points there. |
| `drive-organizer` | `feature/android-app-implementation` | Remote default points there. |
| `SEOlith` | `users/krk/20241224_UsersRepository` | Remote default points there. |
| `SEOlithAI` | `users/gs/20250715-reactjs_loginpage_work` | Remote default points there. |
| `seolith-zoom` | `master` | Repository default is `master`. |

## Local Excludes

Local-only generated folders were preserved on disk and hidden with `.git/info/exclude` where appropriate. These are intentionally not committed because they are machine-local cleanup rules.
