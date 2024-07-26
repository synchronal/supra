defmodule SupraTest do
  # @related [subject](lib/supra.ex)
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

  describe "first" do
    test "limits the query to one result and returns it" do
      Test.Schemas.House.changeset(address: "123 Main St") |> Test.Repo.insert!()
      Test.Schemas.House.changeset(address: "234 Main St") |> Test.Repo.insert!()

      assert %Test.Schemas.House{address: "234 Main St"} =
               Ecto.Query.from(h in Test.Schemas.House, order_by: {:desc, h.address}) |> Supra.first(repo: Test.Repo)
    end

    test "returns nil when there are no results" do
      assert Test.Schemas.House |> Supra.first(repo: Test.Repo) == nil
    end
  end

  describe "limit" do
    test "applies a limit to a query" do
      Test.Schemas.House.changeset(address: "123 Main St") |> Test.Repo.insert!()
      Test.Schemas.House.changeset(address: "234 Main St") |> Test.Repo.insert!()

      assert Test.Schemas.House |> Supra.limit(1) |> Supra.count(repo: Test.Repo) == 1
    end
  end

  describe "stream_by" do
    use EctoTemp, repo: Test.Repo

    require EctoTemp.Factory

    deftemptable :data_temp do
      column(:value, :string, null: false)
    end

    setup do
      create_temp_tables()
      :ok
    end

    defmodule Data do
      use Ecto.Schema
      import Ecto.Changeset, only: [cast: 3]

      @primary_key false
      schema "data_temp" do
        field(:value, :string)
      end

      def padded(int),
        do: String.pad_leading(to_string(int), 4, "0")

      def changeset(attrs), do: cast(%__MODULE__{}, Map.new(attrs), ~w[value]a)

      defmodule Query do
        import Ecto.Query
        def base, do: from(_ in Data, as: :data)

        def where_greater_than(query \\ base(), int) do
          value = "value-#{Data.padded(int)}"
          where(query, [data: d], d.value > ^value)
        end
      end
    end

    setup %{max_value: max} do
      for int <- 1..max do
        EctoTemp.Factory.insert(:data_temp, value: "value-#{Data.padded(int)}")
      end

      :ok
    end

    @tag max_value: 50
    test "handles datasets less than batch size" do
      Supra.stream_by(Data.Query.base(), :value, repo: Test.Repo)
      |> Enum.count()
      |> assert_eq(50)

      assert [%{value: "value-0001"}] =
               Supra.stream_by(Data.Query.base(), :value, repo: Test.Repo)
               |> Stream.take(1)
               |> Enum.to_list()

      assert [%{value: "value-0050"}] =
               Supra.stream_by(Data.Query.base(), :value, order: :desc, repo: Test.Repo)
               |> Stream.take(1)
               |> Enum.to_list()
    end

    @tag max_value: 345
    test "handles datasets greater than batch size" do
      Supra.stream_by(Data.Query.base(), :value, repo: Test.Repo)
      |> Enum.count()
      |> assert_eq(345)

      assert [%{value: "value-0001"}] =
               Supra.stream_by(Data.Query.base(), :value, repo: Test.Repo)
               |> Stream.take(1)
               |> Enum.to_list()

      assert [%{value: "value-0345"}] =
               Supra.stream_by(Data.Query.base(), :value, order: :desc, repo: Test.Repo)
               |> Stream.take(1)
               |> Enum.to_list()
    end

    @tag max_value: 250
    test "handles queries with existing where clauses" do
      Supra.stream_by(Data.Query.where_greater_than(177), :value, repo: Test.Repo)
      |> Enum.count()
      |> assert_eq(250 - 177)

      assert [%{value: "value-0178"}] =
               Supra.stream_by(Data.Query.where_greater_than(177), :value, repo: Test.Repo)
               |> Stream.take(1)
               |> Enum.to_list()

      assert [%{value: "value-0250"}] =
               Supra.stream_by(Data.Query.where_greater_than(177), :value, order: :desc, repo: Test.Repo)
               |> Stream.take(1)
               |> Enum.to_list()
    end
  end
end
