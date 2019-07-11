Pod::Spec.new do |s|
  s.name         = "RxPaginationFeedback"
  s.version      = "1.1.0"
  s.summary      = "Generic RxSwift operator to easily interact with paginated APIs."
  s.description  = <<-DESC
    * Simple state machine to represent pagination use cases.
    * Reusable pagination logic. No need to duplicate state across different screens with paginated apis.
    * Observe `PaginationState` to react to:
      * Loading page events
      * Latest api error
      * Changes on the list of elements
  DESC
  s.homepage     = "https://github.com/fabfelici/RxPaginationFeedback"
  s.license      = { :type => "MIT", :file => "LICENSE" }
  s.author       = { "Fabio Felici" => "fab.felici@gmail.com" }
  s.source       = { :git => "https://github.com/fabfelici/RxPaginationFeedback.git", :tag => s.version.to_s }
  s.source_files  = "Sources/**/*.swift"
  s.frameworks  = "Foundation"
  s.swift_version = '5.0'
  s.ios.deployment_target = "8.0"
  s.dependency 'RxFeedback', '~> 3.0'
end
