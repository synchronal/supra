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

  @type stream_opts() :: [stream_opt()]
  @type stream_opt() :: {:repo, module()} | {:order, :asc | :desc} | {:preload, term()}

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
  - `order :: :asc | :desc` default `:asc` - The order in which to iterate over batches.
  - `preload :: term()` optional - An optional set of preloads to apply to each batch before
    emitting members to the stream.
  """
  @spec stream_by(Ecto.Query.t(), atom(), stream_opts()) :: Enum.t()
  def stream_by(query, field, opts),
    do:
      Stream.unfold(nil, &Supra.Stream.get_next_batch(query, field, &1, opts))
      |> Stream.flat_map(& &1)

  defmodule Stream do
    require Ecto.Query

    @batch_size 100

    def get_next_batch(query, field, last_field_value, opts) do
      repo = Keyword.get(opts, :repo) || raise("")

      case query_batch(
             repo,
             Ecto.Query.exclude(query, :order_by),
             field,
             last_field_value,
             Keyword.get(opts, :order, :asc),
             Keyword.get(opts, :preload, [])
           ) do
        [] ->
          nil

        batch ->
          last = List.last(batch)
          {batch, Map.get(last, field)}
      end
    end

    def query_batch(repo, query, field, last_field_value, order, preloads) do
      query
      |> then(fn query ->
        if last_field_value,
          do: next_batch(query, field, order, last_field_value),
          else: query
      end)
      |> Ecto.Query.order_by([{^order, ^field}])
      |> Ecto.Query.limit(^@batch_size)
      |> repo.all()
      |> repo.preload(preloads)
    end

    def next_batch(query, field, :asc, last_value),
      do: Ecto.Query.where(query, [entity], field(entity, ^field) > ^last_value)

    def next_batch(query, field, :desc, last_value),
      do: Ecto.Query.where(query, [entity], field(entity, ^field) < ^last_value)
  end
end
