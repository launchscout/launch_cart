import LaunchCart.Factory

user = insert(:user, email: "user123@example.com", password: "passwordpassword", hashed_password: Bcrypt.hash_pwd_salt("passwordpassword"))
stripe_account = insert(:stripe_account, name: "My account", stripe_id: "acct_foo", user: user)
store = insert(:store, user: user, stripe_account: stripe_account)

insert(:user, email: "chris@launchscout.com")
