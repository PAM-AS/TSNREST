Pod::Spec.new do |s|
  s.name = 'TSNREST'
  s.version = '0.4.1'
  s.authors = {'Thomas Sunde Nielsen' => 'thomas@pam.as'}
  s.homepage = 'https://github.com/PAM-AS/TSNREST'
  s.summary = 'iOS REST library built on MagicalRecord.'
  s.source = { :git => 'https://github.com/PAM-AS/TSNREST.git', :tag => "v#{s.version}" }

  s.requires_arc = true
  s.ios.deployment_target = "7.0"
  s.frameworks = 'CoreGraphics'
  s.ios.frameworks = 'UIKIT'
  s.source_files = 'TSNREST/*.{h,m}'
  s.dependency 'MagicalRecord'
  s.dependency 'SAMCategories', '~> 0.4.0'
  s.dependency 'Reachability', '~> 3.1.0'
  s.dependency 'RSSwizzle', '~> 0.1.0'
  s.dependency 'NSTimer-Blocks', '~> 0.0.1'
  s.dependency 'InflectorKit', '~> 0.0.1'
end
