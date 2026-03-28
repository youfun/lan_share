# Repository Guidelines

## Project Structure & Module Organization
`lib/` contains the application code. Core modules live under [`lib/lan_share.ex`](/home/box/code/self-tool/lan_share/lib/lan_share.ex) and [`lib/lan_share/`](/home/box/code/self-tool/lan_share/lib/lan_share), including HTTP routing, WebSocket handling, room state, message storage, and Markdown rendering. `test/` mirrors the runtime modules with ExUnit coverage, for example `test/lan_share/router_test.exs` and `test/lan_share/room_test.exs`. `config/config.exs` holds runtime configuration, while `docs/` and `PLAN.md` capture design notes and planning context.

## Build, Test, and Development Commands
Use Mix for all local workflows:

- `mix deps.get`: install dependencies.
- `mix run --no-halt`: start the LAN share server on port `10086`.
- `mix test`: run the full ExUnit suite.
- `mix test test/lan_share/router_test.exs`: run a focused test file while iterating.

Prefer running commands from the repository root.

## Coding Style & Naming Conventions
Follow standard Elixir style: 2-space indentation, `snake_case` for functions and variables, `CamelCase` for modules such as `LanShare.Router`, and one module per file under `lib/lan_share/`. Keep Plug routes explicit and small; push reusable logic into named modules instead of embedding it in route bodies. Use descriptive test names in sentence form, e.g. `test "POST /join redirects to normalized room path" do`.

No formatter config is checked in, so default to `mix format` conventions if you format locally.

## Testing Guidelines
This project uses ExUnit with `async: true` where safe. Add or update tests for every behavior change, especially routing, room normalization, Markdown rendering, and message persistence boundaries. Name test files `*_test.exs` and mirror the module path they cover. Before opening a PR, run `mix test` and confirm new edge cases are covered.

## Commit & Pull Request Guidelines
Recent history uses short Conventional Commit prefixes such as `feat:`. Continue with focused messages like `fix: normalize room codes in join flow`. Keep each commit scoped to one change. PRs should include a short description, linked issue or plan item when applicable, test evidence (`mix test`), and screenshots only if UI behavior changed.
