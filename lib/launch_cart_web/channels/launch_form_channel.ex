defmodule LaunchCartWeb.LaunchFormChannel do
  use LiveState.Channel, web_module: LaunchCartWeb

  alias LaunchCart.Forms

  def init("launch_form:" <> form_id, _params, _socket) do
    {:ok, %{form_id: form_id}}
  end

  def handle_event(
        "launch-form-submit",
        form_data,
        %{form_id: form_id}
      ) do
    with form <- Forms.get_form!(form_id),
         {:ok, result, _response} <- Forms.submit_response(form, form_data) do
      {:noreply, Map.merge(result, %{complete: true})}
    end
  end
end
