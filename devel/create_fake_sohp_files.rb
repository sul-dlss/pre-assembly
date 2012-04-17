#! /usr/bin/env ruby

druids  = %w(aa111aa1111 bb222bb2222)
subdirs = %w(Images PM SH SL Transcript)
nn      = '000'

druids.each do |dru|
  nn.next!
  subdirs.each { |sd| FileUtils.mkdir_p "#{dru}/#{sd}" }
  files = [
    "Images/#{dru}_#{nn}_img_1.jpg",
    "Images/#{dru}_#{nn}_img_1.jpg.md5",
    "Images/#{dru}_#{nn}_img_2.jpg",
    "Images/#{dru}_#{nn}_img_2.jpg.md5",
    "PM/#{dru}_#{nn}_a_pm.wav",
    "PM/#{dru}_#{nn}_a_pm.wav.md5",
    "PM/#{dru}_#{nn}_b_pm.wav",
    "PM/#{dru}_#{nn}_b_pm.wav.md5",
    "SH/#{dru}_#{nn}_a_sh.wav",
    "SH/#{dru}_#{nn}_a_sh.wav.md5",
    "SH/#{dru}_#{nn}_b_sh.wav",
    "SH/#{dru}_#{nn}_b_sh.wav.md5",
    "SL/#{dru}_#{nn}_a_sl.mp3",
    "SL/#{dru}_#{nn}_a_sl.mp3.md5",
    "SL/#{dru}_#{nn}_b_sl.mp3",
    "SL/#{dru}_#{nn}_b_sl.mp3.md5",
    "SL/#{dru}_#{nn}_a_sl_techmd.xml",
    "SL/#{dru}_#{nn}_b_sl_techmd.xml",
    "Transcript/#{dru}.pdf",
    "Transcript/#{dru}.pdf.md5",
  ]
  files.each do |f|
    `echo 'Fake file: #{f}' > #{dru}/#{f}`
  end
end


__END__
