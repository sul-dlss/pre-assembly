# frozen_string_literal: true

module ApplicationHelper
  def content_structure
    [
      ['Image', 'simple_image'],
      ['Book (ltr)', 'simple_book'],
      ['Book (rtl)', 'simple_book_rtl'],
      ['Document', 'document'],
      ['File', 'file'],
      ['Geo', 'geo'],
      ['Media', 'media'],
      ['3D', '3d'],
      ['Map', 'maps'],
      ['Webarchive seed', 'webarchive_seed']
    ]
  end

  def avaliable_ocr_languages
    ABBYY_LANGUAGES.map { |lang| [lang, lang.gsub(/[ ()]/, '')] }
  end
end
