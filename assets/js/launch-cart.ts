import { html, LitElement, css } from 'lit'
import { customElement, property, query, state } from 'lit/decorators.js'
import { liveState, liveStateConfig } from 'phx-live-state';
import cartStyles from '../css/cart.lit.scss';

export type CartItem = {
  id: string;
  product: Product;
  quantity: number;
  price: number
}
export type Product = {
  description: string;
  id: string;
  images: string[];
  name: string;
}

export type Cart = {
  items: Array<CartItem>;
  total: number;
}

const formatPrice = (price) => {
  return price > 0 ? new Intl.NumberFormat('en-us', { style: 'currency', currency: 'USD' }).format(price / 100) : '';
}

@customElement('launch-cart')
@liveState({
  properties: ['cart'],
  provide: {
    scope: window,
    name: 'cartState'
  },
  events: {
    send: ['checkout', 'remove_cart_item', 'increase_quantity', 'decrease_quantity'],
    receive: ['checkout_redirect', 'cart_created', 'checkout_complete']
  }
})
export class LaunchCartElement extends LitElement {

  static styles = cartStyles;

  @property()
  @liveStateConfig('url')
  url: string | undefined;

  @property({ attribute: "store-id" })
  storeId: string;

  @state()
  cart: Cart | undefined;

  @state()
  checkingOut: boolean = false;

  @query('#cart-details')
  cartDetails: HTMLDialogElement | undefined;

  @query('#thank-you')
  thanks: HTMLDialogElement | undefined;

  @query('#close-cart-button')
  closeCartButton?: HTMLButtonElement;

  @query('#checkout-button')
  checkoutButton?: HTMLButtonElement | null;

  @liveStateConfig('topic')
  get topic() {
    return `launch_cart:${this.storeId}`;
  }

  @liveStateConfig('params.cart_id')
  get channelName() {
    const cartId = window.localStorage.getItem('cart_id');
    return cartId ? cartId : ''
  }

  constructor() {
    super();
    this.addEventListener('checkout_redirect', (e: CustomEvent<{ checkout_url: string }>) => {
      window.location.href = e.detail.checkout_url;
    });
    this.addEventListener('checkout_complete', (e: CustomEvent) => {
      this.showThanks();
      window.localStorage.removeItem('cart_id');
    });
    this.addEventListener('cart_created', (e: CustomEvent<{ cart_id: string }>) => {
      console.log('cart created')
      window.localStorage.setItem('cart_id', e.detail.cart_id);
    });
  }

  itemCount() {
    return this.cart && this.cart.items && this.cart.items.length > 0 ? html`
      <span class="cart-count" part="cart-count">${this.cart.items.reduce((total, { quantity }) => quantity + total,
      0)}</span>
    ` : ``;
  }

  expandCart() {
    this.cartDetails?.showModal();
  }

  closeCart(e: MouseEvent) {
    if (e.target === this.cartDetails || e.target === this.closeCartButton) {
      this.cartDetails?.close();
    }
  }

  showThanks() {
    this.thanks?.show();
  }

  closeThanks() {
    this.thanks?.close();
  }

  removeItem(e: MouseEvent) {
    const itemId = (e.target as HTMLElement).dataset.itemId;
    this.dispatchEvent(new CustomEvent('remove_cart_item', { detail: { item_id: itemId } }))
  }

  increaseQuantity(e: MouseEvent) {
    const itemId = (e.target as HTMLElement).dataset.itemId;
    this.dispatchEvent(new CustomEvent('increase_quantity', { detail: { item_id: itemId } }))
  }

  decreaseQuantity(e: MouseEvent) {
    const itemId = (e.target as HTMLElement).dataset.itemId;
    this.dispatchEvent(new CustomEvent('decrease_quantity', { detail: { item_id: itemId } }))
  }

  render() {
    return html`
    <dialog part="modal" id="thank-you">
      <div part="modal-header">
        <button @click=${this.closeThanks} part="close-modal" aria-label="Close Modal">✕</button>
      </div>
      <div style="color:white!important"part="modal-body">
        <p part="cart-thank-you">Thanks for purchasing!</p>
      </div>
    </dialog>
    <dialog @click=${this.closeCart} part="modal" id="cart-details">
      <div part="modal-header">
        <button id="close-cart-button" @click=${this.closeCart} part="close-modal" aria-label="Close Modal">✕</button>
      </div>
      <div part="modal-body">
        ${this.cart?.items.length > 0 ? html`
        <table part="cart-summary-table" aria-label="Your Cart Summary">
          <thead part="cart-summary-table-header">
            <tr>
              <th part="cart-summary-item" scope="col">Item</th>
              <th part="cart-summary-price" scope="col">Price</th>
              <th part="cart-summary-qty" scope="col">Qty.</th>
              <th aria-hidden="true"></th>
            </tr>
          </thead>
          <tbody>
            ${this.cart?.items.map(item => html`
            <tr aria-label="${item.product.name}">
              <td part="cart-summary-item">${item.product.name}</td>
              <td part="cart-summary-price">${formatPrice(item.price)}</td>
              <td part="cart-summary-qty">
              <button part="cart-decrease-qty-button" title="Decrease quantity" data-item-id=${item.id}
              @click=${this.decreaseQuantity}>–</button>
              ${item.quantity}
              <button part="cart-increase-qty-button" title="Increase quantity" data-item-id=${item.id}
                @click=${this.increaseQuantity}>+</button>
              </td>
              <td part="cart-summary-remove">
                <button part="cart-remove-item-button" aria-label="Remove item" data-item-id=${item.id} id="remove-item"
                  @click=${this.removeItem}>✕</button>
              </td>
            </tr>
            `)}
          </tbody>
        </table>
        <button id="checkout-button" part="checkout-button" @click=${this.checkout}>
          ${this.checkingOut ? html`
            <svg id="checkout-spinner" part="spinner" viewBox="0 0 50 50">
              <circle part="spinner-path" cx="25" cy="25" r="20" fill="none" stroke-width="5"></circle>
            </svg>
            ` : ''} Check out
        </button>
        ` : html`<p part="cart-empty-message">You currently don't have any items in your cart.</p>`}
      </div>
    </dialog>
    <button part="cart-button" @click=${this.expandCart} aria-label="View Cart">
      <slot name="icon">
        <svg part="cart-icon" xmlns="http://www.w3.org/2000/svg" height="24px" viewBox="0 0 24 24" width="24px"
          fill="#000000">
          <path d="M0 0h24v24H0V0z" fill="none" />
          <path
            d="M15.55 13c.75 0 1.41-.41 1.75-1.03l3.58-6.49c.37-.66-.11-1.48-.87-1.48H5.21l-.94-2H1v2h2l3.6 7.59-1.35 2.44C4.52 15.37 5.48 17 7 17h12v-2H7l1.1-2h7.45zM6.16 6h12.15l-2.76 5H8.53L6.16 6zM7 18c-1.1 0-1.99.9-1.99 2S5.9 22 7 22s2-.9 2-2-.9-2-2-2zm10 0c-1.1 0-1.99.9-1.99 2s.89 2 1.99 2 2-.9 2-2-.9-2-2-2z" />
        </svg>
      </slot>
      ${this.itemCount()}
    </button>
    `;
  }

  checkout(_e: Event) {
    if (!this.checkingOut) {
      this.checkingOut = true;
      this.checkoutButton.setAttribute('disabled', '');
      this.dispatchEvent(new CustomEvent('checkout', { detail: { return_url: window.location.href } }))
    }
  }

}

declare global {
  interface HTMLElementEventMap {
    'checkout_redirect': CustomEvent<{ checkout_url: string }>;
  }
}
