defmodule Supra do
  # @related [test](test/supra_test.exs)
  @moduledoc """
  `Supra` is a library of pipe-able functions and types for use with Ecto.

  ## Types

  Supra ships with multiple Elixir types for helping to document code with specs.

  - `t:Supra.change/1` - a type alias for `t:Ecto.Changeset.t/1`.
  - `t:Supra.result/1` - the result of an Ecto insert or update operation, where the
    return value will be either `{:ok, t()}` or `{:error, Ecto.Changeset.t(t())}`.
  - `t:Supra.result/2` - the result of a function that will call ecto, and return either
    `{:ok, t()}` or `{:error, error_t()}`. Useful for functions wrapping Ecto.Multi,
    when the error changeset is different from the success schema.
  - `t:Supra.preloadable/1` - a type for a function that will pass arguments into
    `c:Ecto.Repo.preload/3`, where the value may be a schema, nil, or a list of schemas.

  ``` elixir
  defmodule Core.Context do
    alias Schema.Thing

    @spec create_thing(Enum.t()) :: Supra.result(Thing.t())
    def create_thing(attrs), do: new_thing(attrs) |> Core.Repo.insert()

    @spec new_thing(Enum.t()) :: Supra.change(Thing.t())
    def new_thing(attrs), do: Core.Context.Thing.changeset(attrs) |> Core.Repo.insert()
  end
  ```

  ## Functions

  Supra includes several minimal wrappers for simple Ecto phrases, as well as a
  comprehensive stream builder, allowing records to be streamed outside of a transaction,
  and with arbitrary ordering.

  Schema helpers:

  - `count/2` - a simple wrapper for `c:Ecto.Repo.aggregate/3`.
  - `first/2` - a pipe-able function for limiting query results.

  Query helpers:

  - `format/3` - converts an `Ecto.Query` to SQL.
  - `limit/2` - a simple wrapper for `Ecto.Query.limit/3`.

  Stream helpers:

  - `stream_by/3` - when a simple query should be streamed by a column that may be
    uniquely identified by a single atom.
  - `stream/2` - when a more complex query should be streamed, where a `cursor_fun`
    calls into the last returned value of a batch to find update a cursor, and a
    `next_batch_fun` updates the query with a dynamic where clause to apply the
    cursor to the next batch.
  """

  require Ecto.Query

  @typedoc "An alias for `t:Ecto.Changeset.t/1`"
  @type change(type) :: Ecto.Changeset.t(type)

  @typedoc "An entity that will be passed into `c:Ecto.Repo.preload/3`"
  @type preloadable() :: [Ecto.Schema.t()] | Ecto.Schema.t() | nil
  @typedoc "An entity that will be passed into `c:Ecto.Repo.preload/3`"
  @type preloadable(type) :: [type] | type | nil

  @typedoc "The result of `c:Ecto.Repo.insert/2` or `c:Ecto.Repo.update/2`"
  @type result(type) :: {:ok, type} | {:error, Ecto.Changeset.t(type)}
  @typedoc "The result of `c:Ecto.Repo.insert/2` or `c:Ecto.Repo.update/2`, when the error changeset wraps a different schema"
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
          | {:batch_transform, (term() -> term())}
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
    emitting members to the stream. This is preferred over query-time preloads for `has_many`
    associations, as described below.

  ## Warning

  When streaming a query with query-time preloads for `Ecto.Schema.has_many/3` associations, values may
  be truncated for the last record of each stream batch. The `:preload` option to `Supra.stream/2` and
  `Supra.stream_by/3` operates on the returned values of each batch, and thus does not exhibit this problem.
  """
  @spec stream_by(Ecto.Query.t(), atom(), stream_by_opts()) :: Enum.t()
  def stream_by(query, field, opts) when is_atom(field) do
    direction = Keyword.get(opts, :order, :asc)
    query = query |> Ecto.Query.exclude(:order_by) |> Ecto.Query.order_by([{^direction, ^field}])

    Stream.resource(
      fn -> nil end,
      fn cursor ->
        Supra.Stream.query_next_batch(
          query,
          &Map.get(&1, field),
          &Supra.Stream.where_next_batch(field, direction, &1),
          cursor,
          opts
        )
      end,
      fn _ -> :ok end
    )
  end

  @doc """
  Streams an Ecto query without requiring a transaction.

  ## Options

  - `batch_transform :: fun()` optional - An arity-1 function that receives each batch and transforms
    it. May be used to manually run each batch through a set of preload functions. Note that, when
    specified, the batch transform functions after executing the `:preload` option, but before the
    `:cursor_fun`.
  - `cursor_fun :: fun()` required - An arity-1 function that will be given the last value returned
    from the stream. This function will be evaluated to save the cursor value that will be used
    to find the next batch.
  - `next_batch_fun :: fun()` required - An arity-1 function that will be given the cursor saved
    from the previous batch. This function must return an `t:Ecto.Query.dynamic_expr/0` that may
    used in a where clause to find the next batch.
  - `repo :: module()` required - An `Ecto.Repo` execute queries.
  - `batch_size :: integer()` default `100` - The size of batches to query from the database.
  - `preload :: term()` optional - An optional set of preloads to apply to each batch before
    emitting members to the stream. This is preferred over query-time preloads for `has_many`
    associations, as described below.

  ## Examples

  ``` elixir
  defmodule Core.Context do
    alias Core.Context.Stuff
    alias Core.Context.Thing
    require Ecto.Query

    @spec stream_things_by_email() :: Enum.t()
    def stream_things_by_email do
      Thing.Query.base()
      |> Thing.Query.ordered_by_emails()
      |> Supra.stream(
        batch_size: 150,
        cursor_fun: & &1.email,
        next_batch_fun: fn last_email -> Ecto.Query.dynamic([things: t], t.email > ^last_email) end,
        repo: Core.Repo
      )
    end

    @spec stream_things_and_stuff() :: Enum.t()
    def stream_things_and_stuff do
      Thing.Query.base()
      |> Thing.Query.ordered_by_name()
      |> Supra.stream(
        cursor_fun: & &1.name,
        next_batch_fun: fn last_name -> Ecto.Query.dynamic([things: t], t.name > ^last_name) end,
        preload: [stuff: Stuff.Query.unlost()],
        repo: Core.Repo
      )
    end
  end
  ```

  ## Warning

  When streaming a query with query-time preloads for `Ecto.Schema.has_many/3` associations, values may
  be truncated for the last record of each stream batch. The `:preload` option to `Supra.stream/2` and
  `Supra.stream_by/3` operates on the returned values of each batch, and thus does not exhibit this problem.
  """
  @spec stream(Ecto.Query.t(), stream_opts()) :: Enum.t()
  def stream(query, opts) do
    cursor_fn = Keyword.get(opts, :cursor_fun) || raise(Supra.Error, "missing required option :cursor_fun")
    where_next = Keyword.get(opts, :next_batch_fun) || raise(Supra.Error, "missing required option :next_batch_fun")

    Stream.resource(
      fn -> nil end,
      fn cursor ->
        Supra.Stream.query_next_batch(
          query,
          cursor_fn,
          where_next,
          cursor,
          opts
        )
      end,
      fn _ -> :ok end
    )
  end
end
