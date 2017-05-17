Pod::Spec.new do |s|
  s.name             = 'SunbeamBLECentralService'
  s.version          = '0.2.3'
  s.summary          = 'SunbeamBLECentralService is a simple framework for iOS bluetooth central develop, it based on CoreBluetooth.'
  s.homepage         = 'https://github.com/sunbeamChen/SunbeamBLECentralService'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'sunbeamChen' => 'chenxun1990@126.com' }
  s.source           = { :git => 'https://github.com/sunbeamChen/SunbeamBLECentralService.git', :tag => s.version.to_s }
  # s.social_media_url = 'https://twitter.com/<TWITTER_USERNAME>'
  s.ios.deployment_target = '7.0'
  s.source_files = 'SunbeamBLECentralService/Classes/**/*'
  s.public_header_files = 'SunbeamBLECentralService/Classes/**/*.h'
  s.frameworks = 'CoreBluetooth'
  s.dependency 'SunbeamLogService'
end
