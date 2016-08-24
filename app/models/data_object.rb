class DataObject < ActiveRecord::Base
  has_one :image_size

  class << self
    def object_cache_re
      @object_cache_re ||= /^(\d\d\d\d)(\d\d)(\d\d)(\d\d)(\d+)$/
    end

    def sizes
      @sizes ||= ["88_88", "98_68", "580_360", "130_130", "260_190"]
    end

    def bad_inat_images
      where("id >= 21621253 AND identifier LIKE 'http://www.inaturalist%' AND "\
        "object_cache_url >= 201607300000000 AND object_cache_url <= 201608010000000")
    end
  end

  def dir
    @dir ||= object_cache_url.to_s.sub(DataObject.object_cache_re,
      "/content/content/\\1/\\2/\\3/\\4/")
  end

  def file_basename
    object_cache_url.to_s.sub(DataObject.object_cache_re, "\\5")
  end

  def restore
    include Magick
    unless Dir.exist?(dir)
      FileUtils.mkdir_p(dir)
      FileUtils.chmod(0755, dir)
    end
    orig_filename = dir + file_basename + "_orig.jpg"
    image = Image.read(object_url).first # No animations supported!
    image.format = 'JPEG'
    unless File.exist?(orig_filename)
      image.write(orig_filename)
      FileUtils.chmod(0644, orig_filename)
    end
    DataObject.sizes.each do |size|
      filename = dir + file_basename + "_#{size}.jpg"
      unless File.exist?(filename)
        (w, h) = size.split("_").map { |e| e.to_i }
        this_image = if w == h
          image.resize_to_fill(w, h).crop(NorthWestGravity, w, h)
        else
          image.resize_to_fit(w, h)
        end
        this_image.strip! # Cleans up properties
        this_image.write(filename) { self.quality = 80 }
        FileUtils.chmod(0644, filename)
      end
    end
  end
end
