class Stt < ActiveRecord::Migration[7.1]
  def change
    add_column :batch_contexts, :run_stt, :boolean, default: false
    add_column :batch_contexts, :stt_available, :boolean, default: false
  end
end
