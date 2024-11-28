defmodule LaunchCart.Forms.WasmComponentHandler do
  alias LaunchCart.Forms.WasmComponentHandler.Native

  defstruct instance: nil, store: nil, reference: nil

  def handle_submit(%__MODULE__{instance: instance, store: store}, form_data), do: Native.handle_submit(store, instance, form_data)

  def new(component_bytes, options \\ []) do
    store = Native.new_store(%WasmComponentsEx.WasiOptions{}, %WasmComponentsEx.StoreLimits{})
    component = Native.new_component(store, component_bytes)
    instance = Native.instantiate(store, component)
    {:ok, %__MODULE__{instance: instance, store: store}}
  end

end
