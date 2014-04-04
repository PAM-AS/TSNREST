Pod::Spec.new do |s|
  s.name = 'TSNREST'
  s.version = '0.1.22'
  s.authors = {'Thomas Sunde Nielsen' => 'thomas@pam.as'}
  s.homepage = 'https://github.com/PAM-AS/TSNREST'
  s.summary = 'iOS REST library built on MagicalRecord.'
  s.source = { :git => 'https://github.com/PAM-AS/TSNREST.git', :tag => "v#{s.version}" }

  s.platform = :ios, '7.0'
  s.requires_arc = true
  s.frameworks = 'UIKit', 'CoreGraphics'
  s.source_files = 'TSNREST/*.{h,m}'
  s.dependency 'MagicalRecord/Shorthand', '~> 2.2'
  s.dependency 'SAMCategories', '~> 0.4.0'
end
