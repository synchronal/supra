defmodule Test.DataCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      alias Core.Repo

      import Moar.Assertions
      import Moar.Sugar
      import Test.DataCase
    end
  end

  setup tags do
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(Test.Repo, shared: not tags[:async])
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)
    :ok
  end
end
