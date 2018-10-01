class ChangeColumnName < ActiveRecord::Migration[5.2]
  def change
    rename_column :users, :sunet_id, :email
  end
end
