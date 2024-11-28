defmodule LaunchCartWeb.WasmHandlerLive.FormComponent do
  use LaunchCartWeb, :live_component

  import LaunchCartWeb.CoreComponents

  alias LaunchCart.Forms

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        <%= @title %>
        <:subtitle>Use this form to manage wasm_handler records in your database.</:subtitle>
      </.header>

      <.simple_form
        for={@form}
        id="wasm_handler-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <.input type="hidden" field={@form[:form_id]} value={@form_id} />
        <.input type="text" field={@form[:description]} label="Description" />
        <.live_file_input upload={@uploads.wasm}/>

        <:actions>
          <.button phx-disable-with="Saving...">Save Wasm handler</.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def update(%{wasm_handler: wasm_handler, form_id: form_id} = assigns, socket) do
    changeset = Forms.change_wasm_handler(wasm_handler)

    {:ok,
     socket
     |> assign(:form_id, form_id)
     |> assign(assigns)
     |> assign_form(changeset)
     |> allow_upload(:wasm, accept: ~w(.wasm), max_file_size: 100_000_000)}
  end

  @impl true
  def handle_event("validate", %{"wasm_handler" => wasm_handler_params}, socket) do
    changeset =
      socket.assigns.wasm_handler
      |> Forms.change_wasm_handler(wasm_handler_params)
      |> Map.put(:action, :validate)
      |> IO.inspect(label: "changeset in validate")

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("save", %{"wasm_handler" => wasm_handler_params}, socket) do
    [file_path] =
      consume_uploaded_entries(socket, :wasm, fn %{path: path} = file, entry ->
        IO.inspect([file, entry], label: "consuming uploads")
        dest = Path.join("priv/static/uploads", Path.basename(path))
        File.cp!(path, dest)
        {:ok, dest}
      end)

    save_wasm_handler(socket, socket.assigns.action, Map.put(wasm_handler_params, "wasm", file_path))
  end

  defp save_wasm_handler(socket, :edit, wasm_handler_params) do
    case Forms.update_wasm_handler(socket.assigns.wasm_handler, wasm_handler_params) do
      {:ok, wasm_handler} ->
        notify_parent({:saved, wasm_handler})

        {:noreply,
         socket
         |> put_flash(:info, "Wasm handler updated successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        IO.inspect(changeset)
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp save_wasm_handler(socket, :new, wasm_handler_params) do
    case Forms.create_wasm_handler(wasm_handler_params) do
      {:ok, wasm_handler} ->
        notify_parent({:saved, wasm_handler})

        {:noreply,
         socket
         |> put_flash(:info, "Wasm handler created successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        IO.inspect(changeset)

        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, :form, to_form(changeset))
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
