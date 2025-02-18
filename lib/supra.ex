defmodule Supra do
  # @related [test](test/supra_test.exs)
  @moduledoc """
  Documentation for `Supra`.
  """

  require Ecto.Query

  @type change(type) :: Ecto.Changeset.t(type)

  @type preloadable() :: [Ecto.Schema.t()] | Ecto.Schema.t() | nil
  @type preloadable(type) :: [type] | type | nil

  @type result(type) :: {:ok, type} | {:error, Ecto.Changeset.t(type)}
  @type result(ok_t, error_t) :: {:ok, ok_t} | {:error, Ecto.Changeset.t(error_t)}

  @type stream_by_opts() :: [stream_by_opt()]
  @type stream_by_opt() ::
          {:repo, module()} | {:batch_size, pos_integer()} | {:order, :asc | :desc} | {:preload, term()}

  @type stream_opts() :: [stream_opt()]
  @type stream_opt() ::
          {:cursor_fun, (term() -> term())}
          | {:next_batch_fun, (term() -> term())}
          | {:repo, module()}
          | {:batch_size, pos_integer()}
          | {:preload, term()}
  # # #

  @doc "Returns the number of rows in `queryable`"
  @spec count(Ecto.Queryable.t(), repo: Ecto.Repo.t()) :: non_neg_integer()
  def count(queryable, repo: repo),
    do: queryable |> repo.aggregate(:count)

  @doc "Limits `queryable` to one result and returns that result"
  @spec first(Ecto.Queryable.t(), repo: Ecto.Repo.t()) :: Ecto.Schema.t() | nil
  def first(queryable, repo: repo),
    do: queryable |> limit(1) |> repo.one()

  @doc """
  Returns `query` as a string with all parameters formatted in the specified style. Styles are rendered via
  `IO.ANSI` which will only render stylized text if it thinks the output device can show them.

  * `:bright` renders parameters in brighter text, which is the most subtle of all the supported styles and may be hard
    to differentiate.
  * `:color` renders parameters in different colors depending on their data types via `IO.ANSI.syntax_colors/0`.
  * `:inverse` (the default) renders parameters with an inverse background. This is quite visible and also compatible
    when some other code such as a logger is colorizing the query.
  * `:underline` is a bit more subtle than `:inverse` but more visible than `:bright`.
  """
  @spec format(Ecto.Queryable.t(), Supra.Format.style(), repo: Ecto.Repo.t()) :: binary()
  def format(query, style \\ :inverse, repo: repo),
    do: Supra.Format.format(repo.to_sql(:all, query), style) |> to_string()

  @doc "Applies `limit` to `queryable`"
  @spec limit(Ecto.Queryable.t(), non_neg_integer()) :: Ecto.Queryable.t()
  def limit(queryable, count) when is_integer(count) and count >= 0,
    do: queryable |> Ecto.Query.limit(^count)

  @doc """
  Streams an Ecto query without requiring a transaction.
  Must be given the name of a non-nullable field to iterate over in batches.

  ## Options

  - `repo :: module()` required - An `Ecto.Repo` execute queries.
  - `batch_size :: integer()` default `100` - The size of batches to query from the database.
  - `order :: :asc | :desc` default `:asc` - The order in which to iterate over batches.
  - `preload :: term()` optional - An optional set of preloads to apply to each batch before
    emitting members to the stream. This is preferred over query-time preloads, as described below.

  ## Warning

  When streaming a query with query-time preloads, associations may be truncated for the last
  record of each stream batch. The `:preload` option to `Supra.stream/2` and `Supra.stream_by/3`
  operates on the returned values of each batch, and thus does not exhibit this problem.
  """
  @spec stream_by(Ecto.Query.t(), atom(), stream_by_opts()) :: Enum.t()
  def stream_by(query, field, opts) when is_atom(field) do
    direction = Keyword.get(opts, :order, :asc)
    query = query |> Ecto.Query.exclude(:order_by) |> Ecto.Query.order_by([{^direction, ^field}])

    Stream.unfold(
      nil,
      fn last_value ->
        Supra.Stream.unfold_next_batch(
          query,
          &Map.get(&1, field),
          &Supra.Stream.where_next_batch(field, direction, &1),
          last_value,
          opts
        )
      end
    )
    |> Stream.flat_map(& &1)
  end

  @doc """
  Streams an Ecto query without requiring a transaction.

  ## Options

  - `cursor_fun :: fun()` required - An arity-1 function that will be given the last value returned
    from the stream. This function will be evaluated to save the cursor value that will be used
    to find the next batch.
  - `next_batch_fun :: fun()` required - An arity-1 function that will be given the cursor saved
    from the previous batch. This function must return an `t:Ecto.Query.dynamic_expr/0` that may
    used in a where clause to find the next batch.
  - `repo :: module()` required - An `Ecto.Repo` execute queries.
  - `batch_size :: integer()` default `100` - The size of batches to query from the database.
  - `preload :: term()` optional - An optional set of preloads to apply to each batch before
    emitting members to the stream. This is preferred over query-time preloads, as described below.

  ## Warning

  When streaming a query with query-time preloads, associations may be truncated for the last
  record of each stream batch. The `:preload` option to `Supra.stream/2` and `Supra.stream_by/3`
  operates on the returned values of each batch, and thus does not exhibit this problem.
  """
  @spec stream(Ecto.Query.t(), stream_opts()) :: Enum.t()
  def stream(query, opts) do
    cursor = Keyword.get(opts, :cursor_fun) || raise(Supra.Error, "missing required option :cursor_fun")
    where_next = Keyword.get(opts, :next_batch_fun) || raise(Supra.Error, "missing required option :next_batch_fun")

    Stream.unfold(
      nil,
      fn last_value ->
        Supra.Stream.unfold_next_batch(
          query,
          cursor,
          where_next,
          last_value,
          opts
        )
      end
    )
    |> Stream.flat_map(& &1)
  end
end
