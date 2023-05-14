defmodule LaunchCartWeb.PageController do
  use LaunchCartWeb, :controller
  alias LaunchCartWeb.Endpoint

  alias LaunchCart.Carts
  alias LaunchCart.Stores

  def index(conn, _params) do
    render(conn, "index.html")
  end

  def api_docs(conn, _params) do
    render(conn, "api_docs.html")
  end

  def usage_docs(conn, _params) do
    render(conn, "usage_docs.html")
  end

  def launch_bot(conn, _params) do
    url = "#{String.replace(Endpoint.url(), "http:", "ws:")}/socket"
    render(conn, "launch_bot.html", url: url)
  end

  def fake_store(conn, %{"store_id" => store_id}) do
    store = Stores.get_store!(store_id)
    url = "#{String.replace(Endpoint.url(), "http:", "ws:")}/socket"
    render(conn, "fake_store.html", products: Carts.list_products(), url: url, store: store)
  end

  def fake_form(conn, %{"form_id" => form_id}) do
    url = "#{String.replace(Endpoint.url(), "http:", "ws:")}/socket"
    render(conn, "fake_form.html", url: url, form_id: form_id)
  end

  def fake_form_recaptcha(conn, %{"form_id" => form_id}) do
    url = "#{String.replace(Endpoint.url(), "http:", "ws:")}/socket"
    render(conn, "fake_form_recaptcha.html", url: url, form_id: form_id)
  end

end
