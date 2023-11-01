defmodule SupraTest do
  use Test.DataCase, async: true
  require Ecto.Query
  doctest Supra

  describe "count" do
    test "returns a count of records returned by a query" do
      Test.Schemas.House.changeset(address: "123 Main St") |> Test.Repo.insert!()
      Test.Schemas.House.changeset(address: "234 Main St") |> Test.Repo.insert!()

      assert Supra.count(Test.Schemas.House, repo: Test.Repo) == 2

      Ecto.Query.from(h in Test.Schemas.House, where: h.address == "123 Main St")
      |> Supra.count(repo: Test.Repo)
      |> assert_eq(1)
    end
  end
end
