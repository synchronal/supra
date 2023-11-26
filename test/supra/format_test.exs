defmodule Supra.FormatTest do
  # @related [subject](lib/supra/format.ex)
  use Test.DataCase, async: true
  require Ecto.Query

  @green "\e[32m"
  @normal "\e[22m"
  @reset "\e[0m"
  @underline "\e[4m"
  @underline_off "\e[24m"
  @white "\e[37m"
  @yellow "\e[33m"

  describe "format" do
    test "formats a query" do
      address = "123 Main St"

      Ecto.Query.from(h in Test.Schemas.House, where: h.address == ^address)
      |> Supra.format(:underline, repo: Test.Repo)
      |> assert_eq(
        ~s|SELECT h0."id", h0."address" FROM "houses" AS h0 WHERE (h0."address" = | <>
          @underline <>
          ~s|"123 Main St"| <>
          @underline_off <>
          ")" <>
          @reset
      )
    end

    test "colorizes parameters" do
      address = "123 Main St"
      min_id = 0

      Ecto.Query.from(h in Test.Schemas.House, as: :houses)
      |> Ecto.Query.where([houses: h], h.address == ^address)
      |> Ecto.Query.where([houses: h], h.id > ^min_id)
      |> Supra.format(:color, repo: Test.Repo)
      |> assert_eq(
        @normal <>
          @white <>
          ~s|SELECT h0."id", h0."address" FROM "houses" AS h0 WHERE (h0."address" = | <>
          @green <>
          ~s|"123 Main St"| <>
          @normal <>
          @white <>
          ~s|) AND (h0."id" > | <>
          @yellow <>
          "0" <>
          @normal <>
          @white <>
          ")" <> @reset
      )
    end
  end
end
