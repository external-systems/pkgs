# CI: org reusable workflows

Every external-systems repo runs the same CI, defined once here in
`.github/workflows/` and called from a short `ci.yml` in each repo.

| Workflow | Runs on | Does |
|---|---|---|
| `flake-check.yml` | PRs, merge queue, pushes to `main` | `nix flake check` with a warm Nix store. Owns the store cache. |
| `pages.yml` | pushes to `main`, after the check | Deploys the site the check job built (`prebuilt: true`), or builds `.#documentation` (MkDocs + reveal.js deck at `/slides/`, from the external-systems/presenting modules) and deploys it to GitHub Pages. |
| `release.yml` | pushes to `main`, after the check | Tags `0.<minor>.<commits>` and publishes a GitHub release with generated notes. |

Only `flake-check` runs on PRs, other branches and the merge queue.
`pages` and `release` run only for pushes to the default branch and only
after `check / flake-check` passed: the caller's `needs: check` gives the
order, and both reusable workflows also refuse any other event or branch
themselves, so a caller that drops its `if:` still can't deploy or tag
from a PR.

## Adopting it in a repo

1. Copy `templates/default/.github/workflows/ci.yml` (new repos from
   `nix flake init -t github:external-systems/pkgs` already have it).
   Delete the `pages` job if the repo has no docs.
2. Delete the repo's old `check.yml` / `pages.yml`.
3. If it deploys docs: Settings → Pages → Source: **GitHub Actions**.
4. If it has private flake inputs: add a token secret, see
   [Private flake inputs](#private-flake-inputs).
5. Require the status check **`check / flake-check`** in the ruleset, see
   [Ruleset](#ruleset).

The status check is named `<caller job id> / <called job id>`. Keep the
caller job id `check` in every repo so one ruleset fits all of them.

Callers pin `@main`. To pin harder, use a release tag of this repo
(`@0.0.42`) or a commit SHA, and let Dependabot's `github-actions`
ecosystem bump it.

## Versioning

`release.yml` tags `<major>.<minor>.<patch>`:

- **major** stays `0`.
- **minor** is the rolling release series, set by `with: {minor: N}` in
  the caller. Bump it by hand to start a new series.
- **patch** is `git rev-list --count HEAD`: the number of commits on
  `main` since the first one. It only grows because the ruleset forbids
  force-pushes. With squash merges it goes up by one per PR; with merge
  commits it also counts the PR's own commits.

An existing tag is left alone, so re-running a job is safe.

## Caching, and making hits likely

The store lives in the GitHub Actions cache (10 GB per repo, least
recently used evicted) through `nix-community/cache-nix-action`.

- **One writer.** Only pushes to `main` (and manual runs) save. A PR can
  read caches from its base branch and `main`, but a cache it saved could
  only be read by that same PR, and it would push `main`'s cache out.
- **Layered keys.** The key is `nix-<os>-<arch>-<hash of locks>-<hash of
  .nix files>`. A miss falls back to the newest cache with the *same
  locks* (identical inputs, only local code changed), then to the newest
  cache of any lock. Before this, any `.nix` edit fell straight to "newest
  of anything".
- **The check hands over the site.** `nix flake check` already builds
  the docs, so on `main` pushes the check job (`pages: true`) runs `nix
  build .#documentation` (a store hit) and uploads the Pages artifact.
  `pages` (`prebuilt: true`) then only deploys: no second runner, store
  restore or evaluation. Without `prebuilt`, `pages` builds it itself
  after `check`, from the cache `check` just saved.
- **Warm evaluation.** `~/.cache/nix` (unpacked flake inputs and the eval
  cache) is cached with the store, so jobs don't re-extract nixpkgs and
  every other input before evaluating.
- **main runs never cancel.** PR runs cancel superseded ones; `main` runs
  queue, so a quick second push can't kill the run that was saving the
  cache.
- **GC and purge.** The store is GC'd to 5 GB (`gc-max-store-size`)
  before saving and older `main` caches are purged, leaving one current
  cache instead of several that evict each other.
- **Across repos (optional).** The Actions cache is per repo, so `home`
  rebuilds what `pkgs` already built. A Cachix cache shared by all repos
  fixes that: create one, add `CACHIX_AUTH_TOKEN` as an org secret and
  pass `with: {cachix-name: <name>}` to `check` and `pages`. `main`
  pushes; PRs only pull.

## Private flake inputs

`nix` fetches `github:` inputs through the GitHub API, which ignores git
credentials and SSH keys, so the workflows give nix a token as
`access-tokens`. They pick, in order:

1. **GitHub App (recommended).** Create an org-owned GitHub App with
   repository permission *Contents: read*, install it on the private repos
   (e.g. `external-systems/secrets`) only, and add `NIX_APP_ID` and
   `NIX_APP_PRIVATE_KEY` as secrets. Pass `with: {private-repos: secrets}`
   to `check` and `pages`. Each run mints a one-hour token scoped to those
   repos; nothing expires or needs rotating.
2. **Fine-grained PAT.** Resource owner `external-systems`, only the
   private repos selected, *Contents: read-only*. Add it as
   `NIX_GITHUB_TOKEN`. It expires (max one year), so it needs rotating.
3. Neither: `github.token`, which is enough for public inputs and lifts
   the anonymous rate limit.

Put the secrets on the **org** (Settings → Secrets and variables →
Actions → New organization secret → *Selected repositories*: only the
repos that need them, e.g. `home`) rather than on each repo. The caller's
`secrets: inherit` passes them through; repos not selected simply don't
get them.

A **deploy key** is an SSH key, so it only works if the input is written
`git+ssh://git@github.com/external-systems/secrets` and the job loads the
key into an ssh-agent. That changes the flake for every user and only
covers one repo per key, so prefer the App.

Fork PRs never receive secrets (`pull_request`, never
`pull_request_target`), so a stranger's PR can't read them.

## Ruleset

The org-standard branch ruleset for `main`, the one pkgs runs. New repos get it as
`templates/default/.github/rulesets/default.json`:

```json
{
  "name": "default",
  "target": "branch",
  "enforcement": "active",
  "conditions": {
    "ref_name": {
      "include": ["~DEFAULT_BRANCH"],
      "exclude": []
    }
  },
  "rules": [
    { "type": "deletion" },
    { "type": "non_fast_forward" },
    { "type": "required_linear_history" },
    { "type": "required_signatures" },
    {
      "type": "pull_request",
      "parameters": {
        "required_approving_review_count": 0,
        "dismiss_stale_reviews_on_push": false,
        "require_code_owner_review": false,
        "require_last_push_approval": false,
        "required_review_thread_resolution": false,
        "allowed_merge_methods": ["squash"]
      }
    },
    {
      "type": "required_status_checks",
      "parameters": {
        "strict_required_status_checks_policy": true,
        "do_not_enforce_on_create": false,
        "required_status_checks": [
          { "context": "check / flake-check", "integration_id": 15368 }
        ]
      }
    }
  ],
  "bypass_actors": [
    { "actor_id": null, "actor_type": "OrganizationAdmin", "bypass_mode": "pull_request" }
  ]
}
```

- `strict_required_status_checks_policy: true` ("Require branches to be
  up to date"): a PR's check must have passed against the current
  `main`, so two PRs that pass alone can't break it together.
- `bypass_mode: pull_request` lets an admin merge a PR past the rules
  but not push straight to `main`.
- `integration_id` 15368 is GitHub Actions, so only Actions can satisfy
  the check.
- A **merge queue** works too: `ci.yml` runs on `merge_group`. If you add
  one, set its merge method to squash, because a merge-commit queue
  conflicts with linear history.
- Apply to one repo with
  `gh api -X POST repos/external-systems/<repo>/rulesets --input .github/rulesets/default.json`
  (or `PUT .../rulesets/<id>` to replace an existing one). Org-wide:
  Org settings → Repository → Rulesets, targeting all repositories.

## Protecting public repos

The repos are public but only you and your bots contribute.

- **Turn off outside PRs.** Settings → General → Features → Pull
  requests: *Collaborators only*. Anyone can still read and comment, but
  only collaborators with write access can open PRs. (You can also
  disable PRs entirely for mirror-like repos.)
- **CI fails closed.** `flake-check.yml` fails, not skips, for PR authors
  who aren't the owner, an org member, a collaborator or in
  `trusted-bots`. A skipped required check would count as passing.
- **Fork PR approval.** Org settings → Actions → General → *Approval for
  running fork pull request workflows*: **Require approval for all
  external contributors**.
- **Read-only token by default.** Same page → Workflow permissions:
  **Read repository contents and packages permissions**. The workflows
  grant `actions: write`, `contents: write` or `pages: write` per job.
- **Only collaborators can merge**, and the ruleset makes every change go
  through a PR with a green `check / flake-check`.
- **Temporary lockdown.** Org settings → Moderation → Interaction limits
  restricts issues, comments and PRs to collaborators for up to six
  months, e.g. during spam.
- `pull_request_target` and `workflow_run` run with secrets on untrusted
  code; never use them in these repos.
