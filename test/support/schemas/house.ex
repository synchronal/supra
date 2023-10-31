defmodule Test.Schemas.House do
  use Ecto.Schema
  import Ecto.Changeset

  schema "houses" do
    field(:address, :string)
  end

  @required_attrs ~w[address]a
  @optional_attrs ~w[]a

  def changeset(attrs \\ []),
    do:
      %__MODULE__{}
      |> cast(Map.new(attrs), @required_attrs ++ @optional_attrs)
      |> validate_required(@required_attrs)
end
