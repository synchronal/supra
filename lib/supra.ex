defmodule Supra do
  # @related [test](test/supra_test.exs)
  @moduledoc """
  Documentation for `Supra`.
  """

  require Ecto.Query

  @type result(type) :: {:ok, type} | {:error, Ecto.Changeset.t(type)}
  @type result(ok_t, error_t) :: {:ok, ok_t} | {:error, Ecto.Changeset.t(error_t)}

  @spec count(Ecto.Queryable.t(), repo: Ecto.Repo.t()) :: non_neg_integer()
  def count(queryable, repo: repo),
    do: queryable |> repo.aggregate(:count)

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
end
