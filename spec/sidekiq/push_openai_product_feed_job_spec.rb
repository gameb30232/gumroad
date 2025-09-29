# frozen_string_literal: true

require "spec_helper"

describe PushOpenaiProductFeedJob do
  describe "#perform" do
    let(:sftp_double) { double("Net::SFTP") }
    let(:sftp_session_double) { double("SFTP Session") }

    before do
      allow(Rails.application.credentials).to receive(:openai_sftp).and_return(
        host: "sftp.example.com",
        port: 22,
        username: "test_user",
        password: "test_password",
        target_directory: "/feeds",
        filename_pattern: "gumroad_products_%Y%m%d.tsv"
      )

      allow(Net::SFTP).to receive(:start).and_yield(sftp_session_double)
      allow(sftp_session_double).to receive(:upload!)

      allow(SlackMessageWorker).to receive(:perform_async)
    end

    context "when generating and uploading feed" do
      let!(:published_product) do
        create(:product,
               name: "Test Product",
               price_cents: 1000,
               native_type: "digital",
               draft: false)
      end

      let!(:draft_product) do
        create(:product,
               name: "Draft Product",
               price_cents: 2000,
               native_type: "digital",
               draft: true)
      end

      it "generates TSV feed and uploads to SFTP" do
        expect(Net::SFTP).to receive(:start).with(
          "sftp.example.com",
          "test_user",
          hash_including(password: "test_password", port: 22)
        ).and_yield(sftp_session_double)

        expect(sftp_session_double).to receive(:upload!) do |local_path, remote_path|
          expect(remote_path).to match(%r{/feeds/gumroad_products_\d{8}\.tsv})
          expect(File.exist?(local_path)).to be true

          content = File.read(local_path)
          lines = content.split("\n")

          expect(content).to include("id\ttitle\tdescription")
          expect(lines.any? { |line| line.include?(published_product.unique_permalink) }).to be true
          expect(lines.any? { |line| line.include?(draft_product.unique_permalink) }).to be false
        end

        described_class.new.perform

        expect(SlackMessageWorker).to have_received(:perform_async).with(
          "integrations",
          "OpenAI Product Feed",
          /Successfully pushed OpenAI product feed/,
          "green"
        )
      end

      it "includes all required OpenAI feed fields" do
        allow(sftp_session_double).to receive(:upload!) do |local_path, _remote_path|
          content = File.read(local_path)
          lines = content.split("\n")
          headers = lines[0].split("\t")

          expect(headers).to include("id", "title", "description", "link", "image_link",
                                     "product_category", "brand", "material", "weight",
                                     "price", "availability", "inventory_quantity",
                                     "seller_name", "seller_url", "seller_privacy_policy",
                                     "seller_tos", "return_policy", "return_window",
                                     "enable_search", "enable_checkout")
        end

        described_class.new.perform
      end

      it "only includes published products" do
        allow(sftp_session_double).to receive(:upload!) do |local_path, _remote_path|
          content = File.read(local_path)
          lines = content.split("\n")

          expect(lines.any? { |line| line.include?(published_product.unique_permalink) }).to be true
          expect(lines.any? { |line| line.include?(draft_product.unique_permalink) }).to be false
        end

        described_class.new.perform
      end

      it "cleans up temporary files after upload" do
        temp_file_path = nil

        allow(sftp_session_double).to receive(:upload!) do |local_path, _remote_path|
          temp_file_path = local_path
          expect(File.exist?(local_path)).to be true
        end

        described_class.new.perform

        expect(File.exist?(temp_file_path)).to be false
      end

      it "formats price correctly" do
        allow(sftp_session_double).to receive(:upload!) do |local_path, _remote_path|
          content = File.read(local_path)
          expect(content).to include("10.0 USD")
        end

        described_class.new.perform
      end

      it "sets product category based on native_type" do
        create(:product,
               name: "Physical Product",
               price_cents: 1500,
               native_type: "physical",
               draft: false)

        allow(sftp_session_double).to receive(:upload!) do |local_path, _remote_path|
          content = File.read(local_path)
          expect(content).to include("Products > Physical Goods")
          expect(content).to include("Media > Digital Products")
        end

        described_class.new.perform
      end
    end

    context "when SFTP credentials are missing" do
      before do
        allow(Rails.application.credentials).to receive(:openai_sftp).and_return(nil)
      end

      it "raises an error and sends failure notification" do
        expect { described_class.new.perform }.to raise_error(/SFTP credentials not configured/)

        expect(SlackMessageWorker).to have_received(:perform_async).with(
          "integrations",
          "OpenAI Product Feed Error",
          /Failed to push OpenAI product feed/,
          "red"
        )
      end
    end

    context "when SFTP upload fails" do
      before do
        allow(Net::SFTP).to receive(:start).and_raise(StandardError.new("Connection failed"))
      end

      it "sends failure notification and re-raises error" do
        expect { described_class.new.perform }.to raise_error(/Connection failed/)

        expect(SlackMessageWorker).to have_received(:perform_async).with(
          "integrations",
          "OpenAI Product Feed Error",
          /Failed to push OpenAI product feed: Connection failed/,
          "red"
        )
      end

      it "cleans up temporary files even on failure" do
        temp_file_paths = []

        allow(Tempfile).to receive(:new).and_wrap_original do |method, *args|
          temp_file = method.call(*args)
          temp_file_paths << temp_file.path
          temp_file
        end

        expect { described_class.new.perform }.to raise_error(/Connection failed/)

        temp_file_paths.each do |path|
          expect(File.exist?(path)).to be false
        end
      end
    end

    context "format generation" do
      let!(:test_product) do
        create(:product,
               name: "Format Test Product",
               price_cents: 2500,
               native_type: "digital",
               draft: false)
      end

      it "generates valid TSV format" do
        allow(sftp_session_double).to receive(:upload!) do |local_path, _remote_path|
          content = File.read(local_path)
          lines = content.split("\n")

          expect(lines[0]).to match(/\t/)
          expect(lines[0].split("\t").length).to be > 15
        end

        described_class.new.perform
      end

      it "handles products with missing optional fields" do
        product_without_description = create(:product,
                                             name: "No Description Product",
                                             description: nil,
                                             price_cents: 1000,
                                             native_type: "digital",
                                             draft: false)

        allow(sftp_session_double).to receive(:upload!) do |local_path, _remote_path|
          content = File.read(local_path)
          expect(content).to include(product_without_description.unique_permalink)
          expect(content).to include("No Description Product")
        end

        described_class.new.perform
      end

      it "handles products with special characters in name and description" do
        special_product = create(:product,
                                 name: 'Product with "quotes" & special chars',
                                 price_cents: 1000,
                                 native_type: "digital",
                                 draft: false)

        allow(sftp_session_double).to receive(:upload!) do |local_path, _remote_path|
          content = File.read(local_path)
          expect(content).to include(special_product.unique_permalink)
        end

        described_class.new.perform
      end
    end

    context "product data transformation" do
      it "sets enable_search and enable_checkout to true" do
        create(:product, name: "Search Test", price_cents: 1000, native_type: "digital", draft: false)

        allow(sftp_session_double).to receive(:upload!) do |local_path, _remote_path|
          content = File.read(local_path)
          lines = content.split("\n")
          data_line = lines[1]

          values = data_line.split("\t")
          headers = lines[0].split("\t")

          enable_search_idx = headers.index("enable_search")
          enable_checkout_idx = headers.index("enable_checkout")

          expect(values[enable_search_idx]).to eq("true")
          expect(values[enable_checkout_idx]).to eq("true")
        end

        described_class.new.perform
      end

      it "sets availability to 'in_stock' for normal products" do
        create(:product, name: "Stock Test", price_cents: 1000, native_type: "digital", draft: false)

        allow(sftp_session_double).to receive(:upload!) do |local_path, _remote_path|
          content = File.read(local_path)
          expect(content).to include("in_stock")
        end

        described_class.new.perform
      end

      it "sets availability to 'preorder' for preorder products" do
        preorder_product = create(:product,
                                  name: "Preorder Test",
                                  price_cents: 1000,
                                  native_type: "digital",
                                  draft: false)
        allow(preorder_product).to receive(:is_in_preorder_state).and_return(true)
        allow(preorder_product).to receive(:published?).and_return(true)

        alive_scope = double("alive_scope")
        allow(Link).to receive(:alive).and_return(alive_scope)
        allow(alive_scope).to receive(:where).and_return(alive_scope)
        allow(alive_scope).to receive(:not).and_return(alive_scope)
        allow(alive_scope).to receive(:includes).and_return([preorder_product])

        allow(sftp_session_double).to receive(:upload!) do |local_path, _remote_path|
          content = File.read(local_path)
          expect(content).to include("preorder")
        end

        described_class.new.perform
      end
    end
  end
end
