class Product < ActiveRecord::Base
  validates :staples_pid, presence: true, length: {maximum: 13, minimum: 6},
            format: {with: /\A[A-Z0-9]{6,13}\z/}, uniqueness: true
  before_validation :load_product
  validate :product_exists
  enum availability: [:instock, :oos]

  has_many :alerts

  def unavailable?(title)
    !title or title.match("Unavailable")
  end

  def load_image
    return @image if @image
    load_product
    puts "http:#{self.image_url}"
    @image=open("http:#{self.image_url}","rb").read
  end

  def load_page(reload=false)
    return @page if @page and reload==false
    agent = Mechanize.new
    agent.user_agent_alias = 'Mac Safari'
    agent.history_added = Proc.new { sleep 0.5 }
    page=agent.get("http://www.staples.com/product_#{self.staples_pid}")
    return page if unavailable?(page.title)
    @page=page
  end

  def get_price(page)
    page.search('span[itemprop="price"]').text.sub("$", "").to_f
  end

  def current_price
    get_price load_page
  end

  def load_product
    return if self.id!=nil # product exist
    page=load_page
    self.name=page.title
    return if unavailable?(self.name)
    self.name=page.search('[itemprop="name"]').text
    self.price=page.search('span[itemprop="price"]').text.sub("$", "").to_f
    self.description=page.search('div[itemprop="description"]').text
    self.image_url=page.search('img[itemprop="image"]').attr('src').text.sub(/\Ahttp:/, "")
    self.url=page.search('a[itemprop="url"]').attr('href').text.sub(/\Ahttp:/, "")
    # ignore item condition, user should know more
    # itemCondition=page.search('link[itemprop="itemCondition"]').attr('href').text
    if "http://schema.org/InStock"==page.search('link[itemprop="availability"]').attr('href').text
      self.availability="instock"
    else
      self.availability="oos"
    end
  end

  def product_exists
    # p_id=1684954  # kindle paperwhite
    if self.name==nil
      return errors.add(:base, 'product not found, please double check!')
    end
    if self.name.match("Unavailable")
      return errors.add(:base, 'site unavailable, try later')
    end
  end

  private :unavailable?
end
