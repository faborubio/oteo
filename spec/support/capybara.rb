require "capybara/rspec"
require "capybara/cuprite"

Capybara.register_driver(:cuprite) do |app|
  Capybara::Cuprite::Driver.new(
    app,
    window_size: [ 1400, 900 ],
    browser_options: { "no-sandbox" => nil },
    inspector: ENV["INSPECTOR"].present?,
    headless: !ENV["HEADLESS"].in?(%w[n no false])
  )
end

Capybara.default_driver = :rack_test
Capybara.javascript_driver = :cuprite

RSpec.configure do |config|
  config.before(:each, type: :system) do
    driven_by :rack_test
  end

  config.before(:each, type: :system, js: true) do
    driven_by :cuprite
  end
end
