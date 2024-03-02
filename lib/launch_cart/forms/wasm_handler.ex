defmodule LaunchCart.Forms.WasmHandler do
  use Ecto.Schema
  use Waffle.Ecto.Schema

  import Ecto.Changeset

  alias LaunchCart.Forms.Form
  alias LaunchCart.Uploaders.Wasm

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "wasm_handlers" do
    field :wasm, Wasm.Type
    field :description, :string
    belongs_to :form, Form

    timestamps()
  end

  @doc false
  def changeset(wasm_handler, attrs) do
    wasm_handler
    |> cast(attrs, [:form_id, :description])
    |> cast_attachments(attrs, [:wasm], allow_paths: true)
    |> validate_required([:form_id, :description])
  end
end
