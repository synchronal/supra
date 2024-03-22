defmodule Supra.Format do
  # @related [test](test/supra/format_test.exs)

  @moduledoc "Internal module for formatting a sql query"

  @type style() :: :bright | :color | :inverse | :underline
  @styles ~w[bright color inverse underline]a

  @doc "See `Supra.format/3`"
  def format({sql, params}, style) when style in @styles do
    sql
    |> String.split(~r|\$\d+|, include_captures: true, trim: true)
    |> Enum.map(fn
      <<"$", index::binary>> = _param ->
        index = String.to_integer(index) - 1
        param = Enum.at(params, index)
        apply_style(param, style)

      query_part ->
        query_part
    end)
    |> then(&if style == :color, do: [default_syntax_color() | &1], else: &1)
    |> IO.ANSI.format(true)
  end

  defp apply_style(content, :bright), do: apply_style(content, :bright, :normal)
  defp apply_style(content, :inverse), do: apply_style(content, :inverse, :inverse_off)
  defp apply_style(content, :underline), do: apply_style(content, :underline, :no_underline)
  defp apply_style(content, :color) when is_atom(content), do: apply_syntax_color(content, :atom)
  defp apply_style(content, :color) when is_boolean(content), do: apply_syntax_color(content, :boolean)
  defp apply_style(content, :color) when is_nil(content), do: apply_syntax_color(content, nil)
  defp apply_style(content, :color) when is_number(content), do: apply_syntax_color(content, :number)
  defp apply_style(content, :color) when is_binary(content), do: apply_syntax_color(content, :string)
  defp apply_style(content, style, undo_style), do: [style, inspect(content), undo_style]

  defp apply_syntax_color(content, type),
    do: apply_style(content, IO.ANSI.syntax_colors()[type], default_syntax_color())

  defp default_syntax_color, do: [:normal, :white]
end
