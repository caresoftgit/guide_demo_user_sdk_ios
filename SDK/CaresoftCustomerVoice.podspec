Pod::Spec.new do |s|
 s.name = 'CaresoftCustomerVoice'
 s.version = '0.5.0'
 s.summary = 'Caresoft customer Voice SDK and native call UI'
 s.homepage = 'https://caresoft.vn'
 s.author = 'Caresoft'
 s.license = { :type => 'Proprietary' }
 s.source = { :path => '.' }
 s.platform = :ios, '15.1'
 s.vendored_frameworks = 'Vendor/*.xcframework'
 s.resources = 'Vendor/Resources/*.bundle'
 s.preserve_paths = 'Vendor/Licenses/**/*'
 s.frameworks = 'CallKit', 'PushKit', 'AVFoundation', 'UserNotifications', 'SwiftUI'
end
