Pod::Spec.new do |s|
  s.name = 'SunbeamBLECentralService'
  s.version = '0.1.8'
  s.summary = 'SunbeamBLECentralService is a simple framework for iOS bluetooth central develop, it based on CoreBluetooth.'
  s.license = {"type"=>"MIT", "file"=>"LICENSE"}
  s.authors = {"sunbeamChen"=>"chenxun1990@126.com"}
  s.homepage = 'https://github.com/sunbeamChen/SunbeamBLECentralService'
  s.frameworks = 'CoreBluetooth'
  s.source = { :path => '.' }

  s.ios.deployment_target    = '7.0'
  s.ios.preserve_paths       = 'ios/SunbeamBLECentralService.framework'
  s.ios.public_header_files  = 'ios/SunbeamBLECentralService.framework/Versions/A/Headers/*.h'
  s.ios.resource             = 'ios/SunbeamBLECentralService.framework/Versions/A/Resources/**/*'
  s.ios.vendored_frameworks  = 'ios/SunbeamBLECentralService.framework'
end
