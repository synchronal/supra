defmodule SupraTest do
  # @related [subject](lib/supra.ex)
  use EctoTemp, repo: Test.Repo
  use Test.DataCase, async: true
  require Ecto.Query
  require EctoTemp.Factory

  doctest Supra

  deftemptable :data_temp do
    column(:value, :string, null: false)
    column(:rel_id, :integer)
  end

  deftemptable :rel_temp do
    column(:name, :string, null: false)
  end

  setup do
    create_temp_tables()
    :ok
  end

  defmodule Rel do
    use Ecto.Schema
    import Ecto.Changeset, only: [cast: 3]

    schema "rel_temp" do
      field(:name, :string)
    end

    def changeset(attrs), do: cast(%__MODULE__{}, Map.new(attrs), ~w[name])

    defmodule Query do
      import Ecto.Query
      def base, do: from(_ in Rel, as: :rels)

      def order_by_name(query \\ base()),
        do: query |> order_by([rels: r], asc: r.name)
    end
  end

  defmodule Data do
    use Ecto.Schema
    import Ecto.Changeset, only: [cast: 3]

    @primary_key false
    schema "data_temp" do
      field(:value, :string)
      belongs_to(:rel, Rel)
    end

    def padded(int),
      do: String.pad_leading(to_string(int), 4, "0")

    def changeset(attrs), do: cast(%__MODULE__{}, Map.new(attrs), ~w[value]a)

    defmodule Query do
      import Ecto.Query
      def base, do: from(_ in Data, as: :data)

      def join_rel(query \\ base()),
        do: query |> join(:inner, [data: d], _ in assoc(d, :rel), as: :rels)

      def order_by_rel(query \\ base()),
        do: query |> join_rel() |> Rel.Query.order_by_name()

      def where_greater_than(query \\ base(), int) do
        value = "value-#{Data.padded(int)}"
        where(query, [data: d], d.value > ^value)
      end
    end
  end

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
      Supra.stream_by(Data.Query.base(), :value, batch_size: 7, repo: Test.Repo)
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

  describe "stream" do
    setup %{max_value: max} do
      for int <- 1..max do
        EctoTemp.Factory.insert(:rel_temp, id: int, name: Moar.Random.string())
        EctoTemp.Factory.insert(:data_temp, rel_id: int, value: "value-#{Data.padded(int)}")
      end

      :ok
    end

    @tag max_value: 10
    test "handles queries with sorts across joins" do
      cursor = & &1.rel.name
      where_next = fn name -> Ecto.Query.dynamic([rels: r], r.name > ^name) end

      results =
        Supra.stream(Data.Query.order_by_rel(),
          batch_size: 3,
          cursor_fun: cursor,
          next_batch_fun: where_next,
          preload: :rel,
          repo: Test.Repo
        )
        |> Enum.to_list()

      assert length(results) == 10
      assert match?(%Rel{}, hd(results).rel)

      assert results == Enum.sort_by(results, & &1.rel.name)
      assert results != Enum.sort_by(results, & &1.value)
      assert results != Enum.sort_by(results, & &1.rel.id)
    end

    @tag max_value: 10
    test "applies a batch transform function" do
      cursor = & &1.name
      where_next = fn name -> Ecto.Query.dynamic([rels: r], r.name > ^name) end
      batch_transform = fn batch -> batch |> Test.Repo.preload(:rel) |> Enum.map(&Map.get(&1, :rel)) end

      results =
        Supra.stream(Data.Query.order_by_rel(),
          batch_size: 3,
          batch_transform: batch_transform,
          cursor_fun: cursor,
          next_batch_fun: where_next,
          repo: Test.Repo
        )
        |> Enum.to_list()

      assert length(results) == 10
      assert match?(%Rel{}, hd(results))
    end
  end
end
