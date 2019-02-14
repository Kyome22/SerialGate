
Pod::Spec.new do |spec|
  spec.name         = "SerialGate"
  spec.version      = "1.2"
  spec.summary      = "Serial Communication Library for macOS written by Swift."
  spec.description  = <<-DESC
    By using SerialGate, serial communication with Arduino and mbed can be implemented easily.
    Serial communication demo app can be downloaded from GitHub.
  DESC
  spec.homepage     = "https://github.com/Kyome22/SerialGate"
  spec.license      = { :type => "MIT", :file => "LICENSE" }
  spec.author             = { "Takuto Nakamura" => "kyomesuke@icloud.com" }
  spec.social_media_url   = "https://twitter.com/Kyomesuke3"
  # spec.platform     = :osx, "10.10"
  spec.osx.deployment_target = '10.10'
  spec.source       = { :git => "https://github.com/Kyome22/SerialGate.git", :tag => "#{spec.version}" }
  spec.frameworks = 'Appkit', 'IOKit'
  spec.source_files  = "SerialGate/**/*.swift"
  spec.swift_version = "4.2"
  spec.requires_arc = true
end
