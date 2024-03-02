defmodule LaunchCart.Repo.Migrations.AddDescriptionToWasmHandlers do
  use Ecto.Migration

  def change do
    alter table(:wasm_handlers) do
      add :description, :string
    end
  end
end
