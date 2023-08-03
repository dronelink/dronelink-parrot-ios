Pod::Spec.new do |s|
  s.name = "DronelinkParrot"
  s.version = "1.0.0"
  s.summary = "Dronelink vendor implementation for Parrot"
  s.homepage = "https://dronelink.com/"
  s.license = { :type => "MIT", :file => "LICENSE" }
  s.author = { "Dronelink" => "dev@dronelink.com" }
  s.swift_version = "5.0"
  s.platform = :ios
  s.ios.deployment_target  = "12.0"
  s.source = { :git => "https://github.com/dronelink/dronelink-parrot-ios.git", :tag => "#{s.version}" }
  s.source_files  = "DronelinkParrot/*.{swift}"
  s.resources = "DronelinkParrot/**/*.{strings}"
  s.dependency "DronelinkCore", "~> 4.7.0"
  s.dependency "GroundSdk", "~> 7.7.0"
  s.dependency "ArsdkEngine", "~> 7.7.0"
  s.dependency "SdkCore", "~> 7.7.0"
end
