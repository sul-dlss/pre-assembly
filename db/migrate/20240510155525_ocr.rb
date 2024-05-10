class Ocr < ActiveRecord::Migration[7.1]
  def change
    add_column :batch_contexts, :run_ocr, :boolean, default: false
    add_column :batch_contexts, :manually_corrected_ocr, :boolean, default: false
  end
end
