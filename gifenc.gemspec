Gem::Specification.new do |s|
  s.name        = 'gifenc'
  s.version     = '0.1.0'
  s.summary     = 'GIF encoder, decoder and editor in pure Ruby'
  s.description = <<-EOT
    This library provides GIF encoding, decoding and editing capabilities natively
    within Ruby. It aims to support the complete GIF specification for both
    encoding and decoding, as well as decent editing functionality, while
    maintaining a succint syntax.

    The current version is still preliminar, and only encoding is working,
    but the gem is actively developed and decoding will soon follow, so stay
    tuned if you're interested!
  EOT
  s.authors     = ['edelkas']
  s.files       = Dir['lib/**/*', 'README.md', 'docs/**/*', '.yardopts']
  s.homepage    = 'https://github.com/edelkas/gifenc'
  s.metadata = {
    "homepage_uri"      => 'https://github.com/edelkas/gifenc',
    "source_code_uri"   => 'https://github.com/edelkas/gifenc',
    "documentation_uri" => 'https://www.rubydoc.info/gems/gifenc/',
    "changelog_uri"     => 'https://www.rubydoc.info/gems/gifenc/file/CHANGELOG.md'
  }
  s.add_runtime_dependency('lzwrb')
  s.extra_rdoc_files = Dir['README.md', 'docs/**/*']
end
