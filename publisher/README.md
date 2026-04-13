# Publisher

Batch-pushes every harness that contains a `spec.yaml` to the SpecHub registry.

## Requirements

- [`spechub`](https://spechub.io) CLI available in `PATH`
- Authenticated session (`spechub login` or `SPECHUB_API_KEY` env var)

## Usage

```bash
# Push all specs (org, name, and version come from each spec.yaml)
./publisher/publish.sh

# Preview what would be pushed without making any network calls
./publisher/publish.sh --dry-run

# Push only specs whose directory name contains "logging"
./publisher/publish.sh --filter logging
```

Each spec's `spec.yaml` must declare `metadata.org`, `metadata.name`, and `metadata.version`:

```yaml
apiVersion: spechub.io/v2
kind: Spec
metadata:
  name: api-logging
  org: acme
  version: 1.2.0
```

### Flags

| Flag | Required | Description |
|------|----------|-------------|
| `--dry-run` | no | Run `spechub validate` only; no network calls |
| `--filter <name>` | no | Only process specs whose folder name contains `<name>` |

## Discovery

The script walks one level deep from the `harnesses/` root and collects every directory that contains a `spec.yaml`. The `publisher/` folder and `.spechub/` directories are excluded automatically.

## Logs

Every run writes two files inside `publisher/logs/`:

| File | Contents |
|------|----------|
| `publish_YYYYMMDD_HHMMSS.log` | Full run log (all specs) |
| `<spec-name>_YYYYMMDD_HHMMSS.log` | Raw spechub output per spec |

Logs accumulate; clean old ones manually when needed.

## Exit codes

| Code | Meaning |
|------|---------|
| `0` | All specs pushed successfully |
| `1` | One or more specs failed |
