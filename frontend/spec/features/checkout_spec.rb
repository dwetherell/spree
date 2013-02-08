require 'spec_helper'

describe "Checkout" do
  let!(:country) { create(:country, :name => "Kangaland",:states_required => true) }
  let!(:state) { create(:state, :name => "Victoria", :country => country) }
  let!(:shipping_method) do
    shipping_method = create(:shipping_method)
    calculator = Spree::Calculator::PerItem.create!({:calculable => shipping_method}, :without_protection => true)
    shipping_method.calculator = calculator
    shipping_method.save

    shipping_method
  end

  let!(:payment_method) { create(:payment_method) }

  context "visitor makes checkout as guest without registration" do
    before(:each) do
      Spree::Product.delete_all
      @product = create(:product, :name => "RoR Mug")
      @product.on_hand = 1
      @product.save
      create(:zone)
    end

    context "when backordering is disabled" do
      before(:each) do
        configure_spree_preferences do |config|
          config.allow_backorders = false
        end
      end

      it "should warn the user about out of stock items" do
        visit spree.root_path
        click_link "RoR Mug"
        click_button "add-to-cart-button"

        @product.on_hand = 0
        @product.save

        click_button "Checkout"

        within(:css, "span.out-of-stock") { page.should have_content("Out of Stock") }
      end
    end

    context "defaults to use billing address" do
      before do
        @order = OrderWalkthrough.up_to(:address)
        @order.stub(:available_payment_methods => [ create(:bogus_payment_method, :environment => 'test') ])

        visit spree.root_path
        click_link "RoR Mug"
        click_button "add-to-cart-button"
        Spree::Order.last.update_column(:email, "ryan@spreecommerce.com")
        click_button "Checkout"
      end

      it "should default checkbox to checked" do
        find('input#order_use_billing').should be_checked
      end

      it "should remain checked when used and visitor steps back to address step", :js => true do
        address = "order_bill_address_attributes"
        fill_in "#{address}_firstname", :with => "Ryan"
        fill_in "#{address}_lastname", :with => "Bigg"
        fill_in "#{address}_address1", :with => "143 Swan Street"
        fill_in "#{address}_city", :with => "Richmond"
        select "Kangaland", :from => "#{address}_country_id"
        select "Victoria", :from => "#{address}_state_id"
        fill_in "#{address}_zipcode", :with => "12345"
        fill_in "#{address}_phone", :with => "(555) 5555-555"
        click_button "Save and Continue"
        click_link "Address"

        find('input#order_use_billing').should be_checked
      end
    end

    context "and likes to double click buttons" do
      before(:each) do
        user = create(:user)

        order = OrderWalkthrough.up_to(:delivery)
        order.stub :confirmation_required? => true

        order.reload
        order.user = user
        order.update!

        Spree::CheckoutController.any_instance.stub(:current_order => order)
        Spree::CheckoutController.any_instance.stub(:try_spree_current_user => user)
        Spree::CheckoutController.any_instance.stub(:skip_state_validation? => true)
      end

      it "prevents double clicking the payment button on checkout", :js => true do
        visit spree.checkout_state_path(:payment)

        # prevent form submit to verify button is disabled
        page.execute_script("$('#checkout_form_payment').submit(function(){return false;})")

        page.should_not have_selector('input.button[disabled]')
        click_button "Save and Continue"
        page.should have_selector('input.button[disabled]')
      end

      it "prevents double clicking the confirm button on checkout", :js => true do
        visit spree.checkout_state_path(:confirm)

        # prevent form submit to verify button is disabled
        page.execute_script("$('#checkout_form_confirm').submit(function(){return false;})")

        page.should_not have_selector('input.button[disabled]')
        click_button "Place Order"
        page.should have_selector('input.button[disabled]')
      end

      # Regression test for #1596
      context "full checkout" do
        before do
          @product.shipping_category = shipping_method.shipping_category
          @product.save!
        end

        it "does not break the per-item shipping method calculator", :js => true do
          visit spree.root_path
          click_link "RoR Mug"
          click_button "add-to-cart-button"
          click_button "Checkout"
          Spree::Order.last.update_column(:email, "ryan@spreecommerce.com")

          address = "order_bill_address_attributes"
          fill_in "#{address}_firstname", :with => "Ryan"
          fill_in "#{address}_lastname", :with => "Bigg"
          fill_in "#{address}_address1", :with => "143 Swan Street"
          fill_in "#{address}_city", :with => "Richmond"
          select "Kangaland", :from => "#{address}_country_id"
          select "Victoria", :from => "#{address}_state_id"
          fill_in "#{address}_zipcode", :with => "12345"
          fill_in "#{address}_phone", :with => "(555) 5555-555"

          click_button "Save and Continue"
          page.should_not have_content("undefined method `promotion'")
        end
      end
    end
  end
end
