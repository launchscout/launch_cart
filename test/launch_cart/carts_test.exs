defmodule LaunchCart.CartTest do
  use LaunchCart.DataCase

  alias LaunchCart.Test.FakeLaunch
  alias LaunchCart.Carts
  alias LaunchCart.Carts.{Cart, CartItem}

  import LaunchCart.Factory

  setup do
    [product, product2] = FakeLaunch.populate_cache()
    stripe_account = insert(:stripe_account, stripe_id: "acc_valid_account")
    store = insert(:store, stripe_account: stripe_account)

    {:ok,
     %{
       product: product,
       product2: product2,
       store: store
     }}
  end

  describe "create_cart" do
    test "with a store", %{store: %{id: store_id}} do
      assert {:ok, cart} = Carts.create_cart(store_id)
    end
  end

  describe "add_item" do
    setup %{store: %{id: store_id}} do
      {:ok, cart} = Carts.create_cart(store_id)
      %{cart: cart}
    end

    test "to empty cart", %{product: product, cart: cart} do
      assert {:ok,
              %Cart{
                items: [
                  %CartItem{
                    quantity: 1,
                    stripe_price_id: stripe_price_id,
                    price: price,
                    product: product_data
                  }
                ]
              }} = Carts.add_item(cart, "price_123")

      assert price == product.amount
      assert product.product.id == product_data["id"]
    end

    test "second product to existing cart", %{product2: product2, cart: cart} do
      assert {:ok, cart} = Carts.add_item(cart, "price_123")

      assert {:ok, %Cart{items: items}} = Carts.add_item(cart, "price_456")
      assert Enum.count(items) == 2
      assert "price_456" in (items |> Enum.map(& &1.stripe_price_id))
    end

    test "the same product increases quantity", %{product: product, cart: cart} do
      assert {:ok, cart} = Carts.add_item(cart, "price_123")

      assert {:ok, %Cart{items: [%CartItem{quantity: 2, stripe_price_id: "price_123"}]}} =
               Carts.add_item(cart, "price_123")
    end

    test "adding unknown product returns an error", %{cart: cart} do
      assert {:error, _} = Carts.add_item(cart, "garbage")
    end

    test "an uncached product", %{cart: cart} do
      assert {:ok, %Cart{items: [%CartItem{quantity: 1, stripe_price_id: "price_789"}]}} =
               Carts.add_item(cart, "price_789")
    end
  end

  test "alter quantity" do
    %Cart{items: [%CartItem{id: item_id}]} = cart = insert(:cart)

    assert {:ok, %Cart{items: [%CartItem{quantity: 2, id: ^item_id}]}} =
             Carts.increase_quantity(cart, item_id)

    assert {:ok, %Cart{items: [%CartItem{quantity: 1, id: ^item_id}]}} =
             Carts.decrease_quantity(cart, item_id)

    assert {:ok, %Cart{items: [%CartItem{quantity: 0, id: ^item_id}]}} =
             Carts.decrease_quantity(cart, item_id)

    assert {:ok, %Cart{items: [%CartItem{quantity: 0, id: ^item_id}]}} =
             Carts.decrease_quantity(cart, item_id)
  end

  describe "checkout" do
    test "checkout creates sesssion for connected account and returns url", %{
      store: %{id: store_id}
    } do
      {:ok, cart} = Carts.create_cart(store_id)

      {:ok, cart} = Carts.add_item(cart, "price_123")
      {:ok, cart} = Carts.add_item(cart, "price_456")
      return_url = "http://foo.bar"

      assert {:ok,
              %Cart{
                status: :checkout_started,
                checkout_session: %{
                  url: checkout_url,
                  success_url: ^return_url,
                  cancel_url: ^return_url
                }
              }} = Carts.checkout(return_url, cart)

      assert checkout_url
    end
  end

  describe "load_cart" do
    test "fetches checkout session from stripe" do
      cart =
        insert(:cart,
          status: :checkout_started,
          checkout_session: %{id: "sess_complete", url: "http://foo.bar"}
        )

      assert {:ok, %Cart{status: :checkout_complete}} = Carts.load_cart(cart.id)
    end

    test "with expired status from stripe" do
      cart =
        insert(:cart,
          status: :checkout_started,
          checkout_session: %{id: "sess_expired", url: "http://foo.bar"}
        )

      assert {:ok, %Cart{status: :checkout_expired}} = Carts.load_cart(cart.id)
    end

    test "with nil status from stripe" do
      cart =
        insert(:cart,
          status: :checkout_started,
          checkout_session: %{id: "sess_nil_status", url: "http://foo.bar"}
        )

      assert {:ok, %Cart{status: :checkout_started}} = Carts.load_cart(cart.id)
    end

    test "with an invalid id" do
      assert {:error, :cart_not_found} = Carts.load_cart("garbage")
    end

    test "with an unknown id" do
      assert {:error, :cart_not_found} = Carts.load_cart(Ecto.UUID.generate())
    end
  end

  test "remove_item" do
    %Cart{id: cart_id, items: [item]} = cart = insert(:cart)
    assert {:ok, %Cart{id: ^cart_id, items: []}} = Carts.remove_item(cart, item.id)
  end
end
