defmodule Supra.Stream do
  @moduledoc false
  require Ecto.Query

  @batch_size 100

  def unfold_next_batch(query, cursor_finder, where_fun, last_field_value, opts) do
    repo = Keyword.get(opts, :repo) || raise(Supra.Error, "missing required option :repo")

    case query_batch(
           repo,
           query,
           where_fun,
           last_field_value,
           Keyword.get(opts, :batch_size, @batch_size),
           Keyword.get(opts, :preload, [])
         ) do
      [] ->
        nil

      batch ->
        last = List.last(batch)
        {batch, cursor_finder.(last)}
    end
  end

  def query_batch(repo, query, where_fun, last_field_value, batch_size, preloads) do
    where_clause = where_fun.(last_field_value)

    query
    |> then(fn query ->
      if last_field_value,
        do: Ecto.Query.where(query, ^where_clause),
        else: query
    end)
    |> Ecto.Query.limit(^batch_size)
    |> repo.all()
    |> repo.preload(preloads)
  end

  def where_next_batch(field, :asc, last_value),
    do: Ecto.Query.dynamic([entity], field(entity, ^field) > ^last_value)

  def where_next_batch(field, :desc, last_value),
    do: Ecto.Query.dynamic([entity], field(entity, ^field) < ^last_value)
end
