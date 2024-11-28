defmodule LaunchCart.Forms do
  @moduledoc """
  The Forms context.
  """

  import Ecto.Query, warn: false
  alias LaunchCart.Forms.WasmComponentHandler
  alias LaunchCart.Repo

  alias LaunchCart.Forms.{Form, FormEmail, FormMailer, FormResponse, WasmHandler}
  alias LaunchCart.Accounts.User
  alias LaunchCart.WebHooks.WebHook

  @doc """
  Returns the list of forms.

  ## Examples

      iex> list_forms()
      [%Form{}, ...]

  """
  def list_forms do
    Repo.all(Form)
  end

  def list_forms(%User{id: user_id}) do
    Repo.all(from form in Form, where: form.user_id == ^user_id)
  end

  @doc """
  Gets a single form.

  Raises `Ecto.NoResultsError` if the Form does not exist.

  ## Examples

      iex> get_form!(123)
      %Form{}

      iex> get_form!(456)
      ** (Ecto.NoResultsError)

  """
  def get_form!(id),
    do: Repo.get!(Form, id) |> Repo.preload([:web_hooks, :form_emails, :wasm_handlers])

  def get_form_responses!(id) do
    Repo.all(from form_response in FormResponse, where: form_response.form_id == ^id)
  end

  @doc """
  Creates a form.

  ## Examples

      iex> create_form(%{field: value})
      {:ok, %Form{}}

      iex> create_form(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_form(attrs \\ %{}) do
    %Form{}
    |> Form.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a form.

  ## Examples

      iex> update_form(form, %{field: new_value})
      {:ok, %Form{}}

      iex> update_form(form, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_form(%Form{} = form, attrs) do
    form
    |> Form.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a form.

  ## Examples

      iex> delete_form(form)
      {:ok, %Form{}}

      iex> delete_form(form)
      {:error, %Ecto.Changeset{}}

  """
  def delete_form(%Form{} = form) do
    Repo.delete(form)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking form changes.

  ## Examples

      iex> change_form(form)
      %Ecto.Changeset{data: %Form{}}

  """
  def change_form(%Form{} = form, attrs \\ %{}) do
    Form.changeset(form, attrs)
  end

  alias LaunchCart.Forms.FormResponse

  @doc """
  Returns the list of form_responses.

  ## Examples

      iex> list_form_responses()
      [%FormResponse{}, ...]

  """
  def list_form_responses do
    Repo.all(FormResponse)
  end

  @doc """
  Gets a single form_response.

  Raises `Ecto.NoResultsError` if the Form response does not exist.

  ## Examples

      iex> get_form_response!(123)
      %FormResponse{}

      iex> get_form_response!(456)
      ** (Ecto.NoResultsError)

  """
  def get_form_response!(id), do: Repo.get!(FormResponse, id)

  @doc """
  Creates a form_response.

  ## Examples

      iex> create_form_response(%{field: value})
      {:ok, %FormResponse{}}

      iex> create_form_response(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_form_response(attrs \\ %{}) do
    %FormResponse{}
    |> FormResponse.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a form_response.

  ## Examples

      iex> update_form_response(form_response, %{field: new_value})
      {:ok, %FormResponse{}}

      iex> update_form_response(form_response, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_form_response(%FormResponse{} = form_response, attrs) do
    form_response
    |> FormResponse.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a form_response.

  ## Examples

      iex> delete_form_response(form_response)
      {:ok, %FormResponse{}}

      iex> delete_form_response(form_response)
      {:error, %Ecto.Changeset{}}

  """
  def delete_form_response(%FormResponse{} = form_response) do
    Repo.delete(form_response)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking form_response changes.

  ## Examples

      iex> change_form_response(form_response)
      %Ecto.Changeset{data: %FormResponse{}}

  """
  def change_form_response(%FormResponse{} = form_response, attrs \\ %{}) do
    FormResponse.changeset(form_response, attrs)
  end

  def submit_response(%Form{web_hooks: %Ecto.Association.NotLoaded{}} = form, response) do
    form |> preload() |> submit_response(response)
  end

  def submit_response(%Form{form_emails: %Ecto.Association.NotLoaded{}} = form, response) do
    form |> preload() |> submit_response(response)
  end

  def submit_response(
        %Form{
          id: form_id,
          web_hooks: web_hooks,
          form_emails: form_emails,
          wasm_handlers: wasm_handlers
        },
        response
      ) do
    with {:ok, form_response} <- create_form_response(%{form_id: form_id, response: response}) do
      send_web_hooks(web_hooks, response)
      send_emails(form_emails, response)
      result = fire_wasm_handlers(wasm_handlers, response)
      {:ok, result, form_response}
    end
  end

  defp send_web_hooks(web_hooks, response) do
    web_hooks |> Enum.map(&send_web_hook(&1, response))
  end

  defp send_web_hook(%WebHook{url: url}, response) do
    HTTPoison.post!(url, Jason.encode!(response), [{"Content-Type", "application/json"}])
  end

  defp send_emails(form_emails, response) do
    form_emails |> Enum.map(&FormMailer.send_response_email(&1, response))
  end

  defp fire_wasm_handlers(wasm_handlers, response) do
    wasm_handlers
    |> Enum.reduce(%{}, &fire_wasm_handler(&1, &2, response))
    |> IO.inspect(label: "reduce result")
  end

  defp fire_wasm_handler(%WasmHandler{wasm: %{file_name: file_name}}, acc, response) do
    component_bytes = File.read!("./priv/static/uploads/#{file_name}")
    {:ok, form_handler} = WasmComponentHandler.new(component_bytes)
    IO.inspect(response, label: "response passed to handler")

    result =
      WasmComponentHandler.handle_submit(
        form_handler,
        response |> Enum.map(fn {k, v} -> {to_string(k), [v]} end) |> Enum.into([])
      )

    %{result: result}
  end

  defp preload(%Form{} = form), do: Repo.preload(form, [:web_hooks, :form_emails])

  @doc """
  Returns the list of form_emails.

  ## Examples

      iex> list_form_emails()
      [%FormEmail{}, ...]

  """
  def list_form_emails do
    Repo.all(FormEmail)
  end

  @doc """
  Gets a single form_email.

  Raises `Ecto.NoResultsError` if the Form email does not exist.

  ## Examples

      iex> get_form_email!(123)
      %FormEmail{}

      iex> get_form_email!(456)
      ** (Ecto.NoResultsError)

  """
  def get_form_email!(id), do: Repo.get!(FormEmail, id)

  @doc """
  Creates a form_email.

  ## Examples

      iex> create_form_email(%{field: value})
      {:ok, %FormEmail{}}

      iex> create_form_email(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_form_email(attrs \\ %{}) do
    %FormEmail{}
    |> FormEmail.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a form_email.

  ## Examples

      iex> update_form_email(form_email, %{field: new_value})
      {:ok, %FormEmail{}}

      iex> update_form_email(form_email, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_form_email(%FormEmail{} = form_email, attrs) do
    form_email
    |> FormEmail.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a form_email.

  ## Examples

      iex> delete_form_email(form_email)
      {:ok, %FormEmail{}}

      iex> delete_form_email(form_email)
      {:error, %Ecto.Changeset{}}

  """
  def delete_form_email(%FormEmail{} = form_email) do
    Repo.delete(form_email)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking form_email changes.

  ## Examples

      iex> change_form_email(form_email)
      %Ecto.Changeset{data: %FormEmail{}}

  """
  def change_form_email(%FormEmail{} = form_email, attrs \\ %{}) do
    FormEmail.changeset(form_email, attrs)
  end

  alias LaunchCart.Forms.WasmHandler

  @doc """
  Returns the list of wasm_handlers.

  ## Examples

      iex> list_wasm_handlers()
      [%WasmHandler{}, ...]

  """
  def list_wasm_handlers(form_id) do
    Repo.all(from w in WasmHandler, where: w.form_id == ^form_id)
  end

  @doc """
  Gets a single wasm_handler.

  Raises `Ecto.NoResultsError` if the Wasm handler does not exist.

  ## Examples

      iex> get_wasm_handler!(123)
      %WasmHandler{}

      iex> get_wasm_handler!(456)
      ** (Ecto.NoResultsError)

  """
  def get_wasm_handler!(id), do: Repo.get!(WasmHandler, id)

  @doc """
  Creates a wasm_handler.

  ## Examples

      iex> create_wasm_handler(%{field: value})
      {:ok, %WasmHandler{}}

      iex> create_wasm_handler(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_wasm_handler(attrs \\ %{}) do
    %WasmHandler{}
    |> WasmHandler.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a wasm_handler.

  ## Examples

      iex> update_wasm_handler(wasm_handler, %{field: new_value})
      {:ok, %WasmHandler{}}

      iex> update_wasm_handler(wasm_handler, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_wasm_handler(%WasmHandler{} = wasm_handler, attrs) do
    wasm_handler
    |> WasmHandler.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a wasm_handler.

  ## Examples

      iex> delete_wasm_handler(wasm_handler)
      {:ok, %WasmHandler{}}

      iex> delete_wasm_handler(wasm_handler)
      {:error, %Ecto.Changeset{}}

  """
  def delete_wasm_handler(%WasmHandler{} = wasm_handler) do
    Repo.delete(wasm_handler)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking wasm_handler changes.

  ## Examples

      iex> change_wasm_handler(wasm_handler)
      %Ecto.Changeset{data: %WasmHandler{}}

  """
  def change_wasm_handler(%WasmHandler{} = wasm_handler, attrs \\ %{}) do
    WasmHandler.changeset(wasm_handler, attrs)
  end
end
