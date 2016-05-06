require 'net/http'

namespace :update_price do
  desc "Update staples products price"
  task :start => :environment do
    logger           = Logger.new(STDOUT)
    logger.level     = Logger::INFO
    Rails.logger     = logger
    logger.info "Making the attempt to update the price"
    # find the oldest 10 products with alerts
    Product.joins(:alerts).where('products.updated_at < :date', date: 1.minutes.ago).each do |product|
      ActiveRecord::Base.transaction do
        begin
          current_price = product.current_price
          if current_price<product.price
            product.price=current_price
            Alert.eager_load(:user, :product).where('alerts.desired >= :current_price and alerts.product_id=:product_id',
                        current_price: product.price, product_id:product.id).each do |alert|
              logger.info "Alerting #{alert.user.email} with #{alert.product.name}"
              AlertMailer.price_drop_alert(alert).deliver_now
            end
          else
            product.touch
          end
          product.save!
          logger.error "product.updated_at: #{product.updated_at}"
        rescue Exception => e
          ActiveRecord::Rollback
          logger.error  e
        end
      end
    end
  end
end