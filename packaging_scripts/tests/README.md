# Wazuh Indexer packages upgrade tests

This folder contains a containerized test environment for the post‑install configuration merge script used by Wazuh Indexer packages.

## What’s Included

- `Dockerfile`: Minimal Debian image with test deps (bats, GNU tools).
- `compose.yml`: Docker Compose file to build and run the tests.
- `merge_config.bats`: Bats test suite covering merge behavior.
- `test.sh`: Host runner that builds the image and executes the suite in a container (no local deps required).

## Prerequisites

- Docker (Engine) installed locally.
- Docker Compose v2 (`docker compose`) or v1 (`docker-compose`).

## How To Run

From the `wazuh-indexer/dev-tools/__tests_` directory:

```sh
./test.sh          # run the suite (awk service)
./test.sh -s awk   # only fallback awk/textual
```

Examples:

- Filter tests by name pattern:
  ```sh
  ./test.sh -f 'nested block'
  ```
- Show test timings:
  ```sh
  ./test.sh -t
  ```

The script will:
- Build the required test images.
- Run the Bats suite inside the selected service(s) using `compose.yml`.

## What The Suite Verifies

- Adds only missing defaults into `/etc/wazuh-indexer/opensearch.yml`.
- Does not overwrite user’s existing values.
- Handles upgrade artifacts: `.rpmnew`, `.dpkg-dist`, `.dpkg-new`.
- Ignores commented keys when deciding if a setting exists.
- Supports nested blocks (e.g.,
  ```yaml
  uiSettings:
    overrides:
      "home:useNewHomePage": true
  ```
  ) appending only what’s missing.
- Idempotency: multiple runs do not duplicate keys.
- Lists merge:
  - Flow-style arrays (`key: [a, b]`) and block lists (`key:` with `- item`) are merged by appending only missing values, preserving the destination order.
  - If styles differ between destination and new defaults, the destination style is preserved (flow stays flow; block stays block).

## Notes on Dependencies

- No external YAML tools are required. The script performs a conservative textual merge: it adds missing top-level blocks and, when applicable, injects missing nested lines under existing blocks; it never overwrites existing user values.

## Troubleshooting

- Compose warning about `version` is avoided by using a version‑less Compose file.
- If you use legacy Compose (`docker-compose`), the runner auto‑detects it.

## File Layout

- `./Dockerfile`
- `./compose.yml`
- `./merge_config.bats`
- `./test.sh`