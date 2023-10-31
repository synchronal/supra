defmodule Supra do
  @moduledoc """
  Documentation for `Supra`.
  """

  @spec count(Ecto.Queryable.t(), repo: Ecto.Repo.t()) :: non_neg_integer()
  def count(queryable, repo: repo),
    do: queryable |> repo.aggregate(:count)
end
