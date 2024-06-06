class AddOcrAvailable < ActiveRecord::Migration[7.1]
  def change
      add_column :batch_contexts, :ocr_available, :boolean, default: false
  end
end
