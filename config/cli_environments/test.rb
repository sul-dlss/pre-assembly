Dor::Config.configure do
  dor do
    service_root 'https://example.com/dor/v1'
    sleep_time 0
    num_attempts 1
  end
end
