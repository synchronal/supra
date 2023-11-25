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

  @doc "Applies `limit` to `queryable`"
  @spec limit(Ecto.Queryable.t(), non_neg_integer()) :: Ecto.Queryable.t()
  def limit(queryable, count) when is_integer(count) and count >= 0,
    do: queryable |> Ecto.Query.limit(^count)
end
