defmodule SupraTest do
  use Test.DataCase, async: true
  doctest Supra

  describe "count" do
    test "returns a count of records returned by a query" do
      Test.Schemas.House.changeset(address: "123 Main St") |> Test.Repo.insert!()
      Test.Schemas.House.changeset(address: "234 Main St") |> Test.Repo.insert!()

      assert Supra.count(Test.Schemas.House, repo: Test.Repo) == 2
    end
  end
end
