defmodule Supra.Stream do
  @moduledoc false
  require Ecto.Query

  @batch_size 100

  def unfold_next_batch(query, cursor_finder, where_fun, last_field_value, opts) do
    repo = Keyword.get(opts, :repo) || raise(Supra.Error, "missing required option :repo")
    batch_transform = Keyword.get(opts, :batch_transform)
    preloads = Keyword.get(opts, :preload)

    case query_batch(
           repo,
           query,
           where_fun,
           last_field_value,
           Keyword.get(opts, :batch_size, @batch_size)
         ) do
      [] ->
        nil

      batch ->
        batch =
          batch
          |> then(fn batch ->
            if preloads,
              do: repo.preload(batch, preloads),
              else: batch
          end)
          |> then(fn batch ->
            if batch_transform,
              do: batch_transform.(batch),
              else: batch
          end)

        last = List.last(batch)

        {batch, cursor_finder.(last)}
    end
  end

  def query_batch(repo, query, where_fun, last_field_value, batch_size) do
    where_clause = where_fun.(last_field_value)

    query
    |> then(fn query ->
      if last_field_value,
        do: Ecto.Query.where(query, ^where_clause),
        else: query
    end)
    |> Ecto.Query.limit(^batch_size)
    |> repo.all()
  end

  def where_next_batch(field, :asc, last_value),
    do: Ecto.Query.dynamic([entity], field(entity, ^field) > ^last_value)

  def where_next_batch(field, :desc, last_value),
    do: Ecto.Query.dynamic([entity], field(entity, ^field) < ^last_value)
end
