# Change Log

## Unreleased

- Add `:batch_transform` option to `Surpa.stream`.

## v3.0.2

- Even more documentation.

## v3.0.1

- Add warning to stream functions, documenting problems that can occur when streaming
  with query-time preloads.

## v3.0.0

- Test against Elixir 1.18.
- **Breaking change:** Drop support for Elixir 1.15.

## v2.0.0

- Introduce `Supra.Error` for more precise raises.
- Add `Supra.stream` with more control over how stream functions.
- `Supra.stream_by` accepts `:batch_size` option.

## v1.1.0

- Add `Supra.stream_by` for streaming queries outside of transactions.

## v1.0.0

- Verify support for Elixir 1.17.0.
- *Breaking*: Drop support for Elixir older than 1.15.0.

## v0.3.0

- Add `preloadable` type, which can be nil, a struct, or a list of structs and matches the type allowed by
  Ecto.Repo.preload/3.

## v0.2.0

- Supra.first limits a query to one result and returns that result.

## Unreleased

- Initial setup.

