describe Assembly::Image do

  it "can be initialized" do
    @ai = Assembly::Image.new(
      :file_name     => 'foo.tif',
      :full_path     => 'tmp/foo.tif',
      :provider_attr => {},
      :exp_md5       => '11111111111111111111111111111111'
    )
  end

end
