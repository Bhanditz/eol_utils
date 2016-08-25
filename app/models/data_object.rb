class DataObject < ActiveRecord::Base
  has_one :image_size
  include Magick

  class << self
    def object_cache_re
      @object_cache_re ||= /^(\d\d\d\d)(\d\d)(\d\d)(\d\d)(\d+)$/
    end

    def sizes
      @sizes ||= ["88_88", "98_68", "580_360", "130_130", "260_190"]
    end

    def bad_inat_images
      where("identifier LIKE 'http://www.inaturalist%' AND "\
        "object_cache_url >= 201607300000000 AND "\
        "object_cache_url <= 201608010000000")
    end

    def restore_inat
      count = 0
      last_id = 33977211 # The script has run this far already.
      images = bad_inat_images.where(["id > ?", last_id]).order(:id).limit(50)
      logger.warn "Started #restore_inat"
      while images.exists?
        images.each do |image|
          image.restore
          count += 1
          last_id = image.id
        end
        logger.warn "Restored: #{images.map(&:id).join(",")}"
        GC.start
        sleep(1)
        images = bad_inat_images.where(["id > ?", last_id]).limit(50)
      end
      logger.warn "FINISHED. Total: #{count} data objects restored."
    end
  end

  def dir
    @dir ||= object_cache_url.to_s.sub(DataObject.object_cache_re,
      "/content/content/\\1/\\2/\\3/\\4/")
  end

  def file_basename
    object_cache_url.to_s.sub(DataObject.object_cache_re, "\\5")
  end

  def url
    "http://eol.org/data_objects/#{id}"
  end

  def restore
    unless Dir.exist?(dir)
      FileUtils.mkdir_p(dir)
      FileUtils.chmod(0755, dir)
    end
    orig_filename = dir + file_basename + "_orig.jpg"
    begin
      get_url = object_url.sub(/^https/, "http")
      image = Image.read(get_url).first # No animations supported!
    rescue Magick::ImageMagickError => e
      logger.error("Couldn't get image #{get_url} for #{url}")
      return nil
    end
    image.format = 'JPEG'
    if File.exist?(orig_filename)
      logger.warn "Hmmmn. There was already a #{orig_filename} for #{id}. Skipping."
    else
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
        this_image.destroy! # Reclaim memory.
        # Note: we *should* honor crops. But none of these will have been
        # cropped, so I am skipping it for now.
        FileUtils.chmod(0644, filename)
      end
    end
    image.destroy! # Clear memory
  end
end
