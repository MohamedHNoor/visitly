class AddAuthenticationTokenVersions < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :verification_nonce, :string
    add_column :users, :reset_nonce, :string
  end
end
