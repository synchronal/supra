defmodule Supra.Stream do
  @moduledoc false
  require Ecto.Query

  @batch_size 100

  def get_next_batch(query, field, last_field_value, opts) do
    repo = Keyword.get(opts, :repo) || raise("")

    case query_batch(
           repo,
           Ecto.Query.exclude(query, :order_by),
           field,
           last_field_value,
           Keyword.get(opts, :batch_size, @batch_size),
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

  def query_batch(repo, query, field, last_field_value, batch_size, order, preloads) do
    query
    |> then(fn query ->
      if last_field_value,
        do: next_batch(query, field, order, last_field_value),
        else: query
    end)
    |> Ecto.Query.order_by([{^order, ^field}])
    |> Ecto.Query.limit(^batch_size)
    |> repo.all()
    |> repo.preload(preloads)
  end

  def next_batch(query, field, :asc, last_value),
    do: Ecto.Query.where(query, [entity], field(entity, ^field) > ^last_value)

  def next_batch(query, field, :desc, last_value),
    do: Ecto.Query.where(query, [entity], field(entity, ^field) < ^last_value)
end
