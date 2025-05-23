# frozen_string_literal: true

module ApplicationHelper
  def content_structure
    [
      ['Image', 'simple_image'],
      ['Book', 'simple_book'],
      ['Document/PDF', 'document'],
      ['File', 'file'],
      ['Geo', 'geo'],
      ['Media', 'media'],
      ['3D', '3d'],
      ['Map', 'maps'],
      ['Webarchive seed', 'webarchive_seed']
    ]
  end

  def processing_configuration
    [
      ['Default', 'default'],
      ['Group by filename', 'filename'],
      ['Group by filename (with pre-existing OCR)', 'filename_with_ocr']
    ]
  end

  def available_ocr_languages
    ABBYY_LANGUAGES.map { |lang| [lang, lang.gsub(/[ ()]/, '')] }
  end
end
