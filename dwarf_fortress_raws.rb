require 'nokogiri'
require 'open-uri'
require 'zip'
require 'fileutils'

module DwarfFortressRaws
  class << self
    def fetch_releases
      doc = Nokogiri::HTML(open('http://www.bay12games.com/dwarves/older_versions.html'))
      releases = doc.xpath('html/body/table')
                    .children
                    .xpath('//p[@class="menu"]')
                    .select { |element| /DF \d+\.\d+\.\d+/ =~ element.text }
                    .reduce({}) { |result, release| result.merge(/DF (\d+\.\d+\.\d+)/.match(release.text)[1] => release.xpath('a[@href]/@href')[0].value) }

      releases.sort
    end

    def download_zip(name, file)
      raise 'Cannot get raws for null release' if name.nil? || file.nil?

      puts "Downloading #{name}"
      File.open(file, 'wb') do |f|
        f.write open('http://www.bay12games.com/dwarves/' + file, 'rb').read
      end
    end

    def extract_zip(file)
      FileUtils.rm_r 'raw', force: true if Dir.exist? 'raw'

      Zip::File.open(file) do |archive|
        archive.each do |f|
          next unless /raw/ =~ f.name
          parent = File.expand_path('..', f.name)
          FileUtils.mkdir_p parent unless Dir.exist? parent
          f.extract(f.name)
        end
      end
    end

    def all_raws
      fetch_releases.each do |name, file|
        next unless `git tag -l #{name}` == ''
        download_zip(name, file)
        extract_zip file
        File.delete file

        `git add .`
        `git commit -m "Change raws to version #{name}"`
        `git tag -a #{name} -m "Dwarf Fortress version #{name}"`
      end
    end
  end
end
