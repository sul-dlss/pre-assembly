class AddStateToAccession < ActiveRecord::Migration[7.0]
  def change
    add_column :accessions, :state, :string, null: false, default: 'in_progress'
    remove_column :accessions, :completed_at
    add_index :accessions, [:druid, :version, :state]
  end
end
