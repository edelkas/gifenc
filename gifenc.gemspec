Gem::Specification.new do |s|
  s.name        = 'gifenc'
  s.version     = '0.2.1'
  s.summary     = 'GIF encoder, decoder and editor in pure Ruby'
  s.description = <<-EOT
    This library provides GIF encoding, decoding and editing capabilities natively
    within Ruby. It aims to support the complete GIF specification for both
    encoding and decoding, as well as having decent editing functionality, while
    maintaining a succint syntax.

    The current version only supports encoding, together with a decent drawing suite
    The gem is actively developed and decoding will soon follow, so stay tuned
    if you're interested!
  EOT
  s.authors     = ['edelkas']
  s.files       = Dir['lib/**/*', 'README.md', 'CHANGELOG.md', 'docs/**/*', '.yardopts']
  s.homepage    = 'https://github.com/edelkas/gifenc'
  s.metadata = {
    "homepage_uri"      => 'https://github.com/edelkas/gifenc',
    "source_code_uri"   => 'https://github.com/edelkas/gifenc',
    "documentation_uri" => 'https://www.rubydoc.info/gems/gifenc',
    "changelog_uri"     => 'https://github.com/edelkas/gifenc/blob/master/CHANGELOG.md'
  }
  s.extra_rdoc_files = Dir['README.md', 'CHANGELOG.md', 'docs/**/*']
  s.extensions = ["ext/extconf.rb"]
  s.require_paths = ["lib", "ext"]
end
