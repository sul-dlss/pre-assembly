class AddLanguages < ActiveRecord::Migration[7.1]
  def change
    add_column :batch_contexts, :ocr_languages, :jsonb, default: []
  end
end
